// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("PlayReadyInitData — PRO outer parser")
struct PlayReadyPROParsingTests {

    /// Hand-build a PRO envelope with arbitrary record data so we
    /// can exercise the outer parser independently of WRMHEADER
    /// XML parsing.
    private static func makePRO(records: [(type: UInt16, value: Data)]) -> Data {
        var bytes: [UInt8] = []
        let totalLength = 6 + records.reduce(0) { $0 + 4 + $1.value.count }
        let length = UInt32(totalLength)
        bytes.append(UInt8(length & 0xFF))
        bytes.append(UInt8((length >> 8) & 0xFF))
        bytes.append(UInt8((length >> 16) & 0xFF))
        bytes.append(UInt8((length >> 24) & 0xFF))
        let count = UInt16(records.count)
        bytes.append(UInt8(count & 0xFF))
        bytes.append(UInt8((count >> 8) & 0xFF))
        for record in records {
            bytes.append(UInt8(record.type & 0xFF))
            bytes.append(UInt8((record.type >> 8) & 0xFF))
            let valLength = UInt16(record.value.count)
            bytes.append(UInt8(valLength & 0xFF))
            bytes.append(UInt8((valLength >> 8) & 0xFF))
            bytes.append(contentsOf: record.value)
        }
        return Data(bytes)
    }

    @Test
    func proHeaderTooShortThrows() {
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(Data([0x00, 0x00, 0x00]))
        }
    }

    @Test
    func proLengthMismatchThrows() {
        // Length declares 100 but buffer is 6 bytes.
        let bytes = Data([0x64, 0x00, 0x00, 0x00, 0x00, 0x00])
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes)
        }
    }

    @Test
    func zeroRecordsParses() throws {
        let bytes = Self.makePRO(records: [])
        let parsed = try PlayReadyInitData.parse(bytes)
        #expect(parsed.records.isEmpty)
    }

    @Test
    func embeddedLicenseStoreRecordTypeRoundTrip() throws {
        let payload = Data([0xCA, 0xFE, 0xBA, 0xBE])
        let bytes = Self.makePRO(records: [(0x0003, payload)])
        let parsed = try PlayReadyInitData.parse(bytes)
        try #require(parsed.records.count == 1)
        if case let .embeddedLicenseStore(data) = parsed.records[0] {
            #expect(data == payload)
        } else {
            Issue.record("expected .embeddedLicenseStore")
        }
        let reencoded = try PlayReadyInitData.encode(parsed)
        #expect(reencoded == bytes)
    }

    @Test
    func unknownRecordTypePreservedVerbatim() throws {
        let payload = Data([0xDE, 0xAD])
        let bytes = Self.makePRO(records: [(0x00FE, payload)])
        let parsed = try PlayReadyInitData.parse(bytes)
        if case let .other(recordType, value) = parsed.records[0] {
            #expect(recordType == 0x00FE)
            #expect(value == payload)
        } else {
            Issue.record("expected .other")
        }
        let reencoded = try PlayReadyInitData.encode(parsed)
        #expect(reencoded == bytes)
    }

    @Test
    func multipleRecordsParsesInOrder() throws {
        let bytes = Self.makePRO(records: [
            (0x0003, Data([0x01, 0x02])),
            (0x00FE, Data([0x03, 0x04, 0x05]))
        ])
        let parsed = try PlayReadyInitData.parse(bytes)
        #expect(parsed.records.count == 2)
        if case .embeddedLicenseStore = parsed.records[0] {
        } else {
            Issue.record("first record should be embeddedLicenseStore")
        }
        if case .other = parsed.records[1] {
        } else {
            Issue.record("second record should be other")
        }
    }

    @Test
    func recordValueTruncatedThrows() {
        // Header says length 200 but only 1 record byte present.
        let bytes = Data([
            0x10, 0x00, 0x00, 0x00,  // length=16 — matches buffer
            0x01, 0x00,  // record count = 1
            0x03, 0x00,  // record type
            0xC8, 0x00,  // record length = 200 (truncated)
            0xAA, 0xBB, 0xCC, 0xDD,
            0x00, 0x00
        ])
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes)
        }
    }

    @Test
    func wrmHeaderRecordWithoutBOMThrows() {
        // record type 0x0001 but record value does not start with the
        // UTF-16 LE BOM.
        let bytes = Self.makePRO(records: [(0x0001, Data([0x3C, 0x00]))])
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes)
        }
    }
}
