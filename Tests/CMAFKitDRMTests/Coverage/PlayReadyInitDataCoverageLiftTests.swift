// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for `PlayReadyInitData`. Targets the throw paths
// the S12b suite did not reach: record-header truncation,
// WRMHEADER record shorter than the UTF-16 LE BOM, malformed
// PRO with partial record header. The genuinely-unreachable
// throws (UInt32/UInt16 overflow on encode; UTF-8 / UTF-16 LE
// conversion failure for valid Strings) are justified in
// codecov.yml.

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("PlayReadyInitData — coverage lift")
struct PlayReadyInitDataCoverageLiftTests {

    @Test
    func recordHeaderTruncatedThrows() {
        // PRO declares 2 records but only 4 bytes remain after the
        // 6-byte outer header (one record header consumes 4 bytes).
        // The second record-header read should throw.
        let bytes = Data([
            0x0E, 0x00, 0x00, 0x00,  // length = 14
            0x02, 0x00,  // record count = 2
            0xFE, 0x00,  // record 1 type
            0x00, 0x00,  // record 1 length = 0
            0xFE, 0x00,  // record 2 type only 2 bytes — record header truncated
            0x00, 0x00
        ])
        // Length is 14 but cursor lands at offset 10 for record 2;
        // record header needs 4 bytes (offsets 10..14), present.
        // Adjust: declare 3 records so the third is truncated.
        let bytes3 = Data([
            0x0E, 0x00, 0x00, 0x00,
            0x03, 0x00,
            0xFE, 0x00, 0x00, 0x00,
            0xFE, 0x00, 0x00, 0x00
        ])
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes3)
        }
        _ = bytes
    }

    @Test
    func wrmHeaderRecordBelowBOMSizeThrows() {
        // Record type = 0x0001 (WRMHEADER) but value is only 1 byte.
        let bytes = Data([
            0x0B, 0x00, 0x00, 0x00,  // length = 11
            0x01, 0x00,  // record count = 1
            0x01, 0x00,  // record type 0x0001
            0x01, 0x00,  // record length = 1
            0xFF  // single byte (no BOM possible)
        ])
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes)
        }
    }

    @Test
    func wrmHeaderWithOnlyBOMThrows() {
        // BOM-only record value — XML parser cannot consume an
        // empty document.
        let bytes = Data([
            0x0C, 0x00, 0x00, 0x00,
            0x01, 0x00,
            0x01, 0x00,
            0x02, 0x00,
            0xFF, 0xFE
        ])
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes)
        }
    }

    @Test
    func zeroLengthHeaderRecordParsesEmptyList() throws {
        // length = 6, recordCount = 0 — zero records.
        let bytes = Data([0x06, 0x00, 0x00, 0x00, 0x00, 0x00])
        let parsed = try PlayReadyInitData.parse(bytes)
        #expect(parsed.records.isEmpty)
    }

    @Test
    func threeRecordsAllReservedTypesPreservedVerbatim() throws {
        // Three "other" records with arbitrary type values. The
        // parser must preserve each verbatim.
        let recordTypes: [UInt16] = [0x0002, 0x00AB, 0x00FF]
        let recordValues: [Data] = [
            Data([0x10]), Data([0x20, 0x21]), Data([0x30, 0x31, 0x32])
        ]
        var bytes: [UInt8] = []
        let totalLength = 6 + recordValues.reduce(0) { $0 + 4 + $1.count }
        let length = UInt32(totalLength)
        bytes.append(UInt8(length & 0xFF))
        bytes.append(UInt8((length >> 8) & 0xFF))
        bytes.append(UInt8((length >> 16) & 0xFF))
        bytes.append(UInt8((length >> 24) & 0xFF))
        bytes.append(0x03)
        bytes.append(0x00)
        for index in 0..<recordValues.count {
            bytes.append(UInt8(recordTypes[index] & 0xFF))
            bytes.append(UInt8((recordTypes[index] >> 8) & 0xFF))
            bytes.append(UInt8(recordValues[index].count & 0xFF))
            bytes.append(UInt8((recordValues[index].count >> 8) & 0xFF))
            bytes.append(contentsOf: recordValues[index])
        }
        let parsed = try PlayReadyInitData.parse(Data(bytes))
        #expect(parsed.records.count == 3)
        for (index, record) in parsed.records.enumerated() {
            if case let .other(type, value) = record {
                #expect(type == recordTypes[index])
                #expect(value == recordValues[index])
            } else {
                Issue.record("expected .other for record \(index)")
            }
        }
        let reencoded = try PlayReadyInitData.encode(parsed)
        #expect(reencoded == Data(bytes))
    }

    @Test
    func wrmHeaderWithKidsArrayMultipleKIDsRoundTripCanonical() throws {
        let kid1 = Data(repeating: 0xAA, count: 16)
        let kid2 = Data(repeating: 0xBB, count: 16)
        let kid3 = Data(repeating: 0xCC, count: 16)
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [
                PlayReadyInitData.WRMHeader.KID(value: kid1, algorithmID: "AESCTR"),
                PlayReadyInitData.WRMHeader.KID(value: kid2, algorithmID: "AESCTR"),
                PlayReadyInitData.WRMHeader.KID(value: kid3)
            ]
        )
        let init1 = PlayReadyInitData(records: [.wrmHeader(header)])
        let encoded1 = try PlayReadyInitData.encode(init1)
        let parsed = try PlayReadyInitData.parse(encoded1)
        let encoded2 = try PlayReadyInitData.encode(parsed)
        #expect(encoded1 == encoded2)
    }

    @Test
    func wrmHeaderV40WithEmbeddedLicenseStoreAndWRMSiblingsRoundTrip() throws {
        let kid = Data(repeating: 0x55, count: 16)
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_0,
            kids: [PlayReadyInitData.WRMHeader.KID(value: kid)]
        )
        let original = PlayReadyInitData(records: [
            .wrmHeader(header),
            .embeddedLicenseStore(Data([0xFF, 0xEE, 0xDD])),
            .other(recordType: 0x00AB, value: Data([0xCA, 0xFE]))
        ])
        let encoded = try PlayReadyInitData.encode(original)
        let parsed = try PlayReadyInitData.parse(encoded)
        #expect(parsed.records.count == 3)
    }

    @Test
    func wrmHeaderV43WithAllOptionalFieldsRoundTrip() throws {
        let kid = Data(repeating: 0xEE, count: 16)
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_3,
            kids: [PlayReadyInitData.WRMHeader.KID(value: kid)],
            checksum: Data([0x01, 0x02, 0x03, 0x04]),
            licenseAcquisitionURL: URL(string: "https://license.example.com/la"),
            licenseUIURL: URL(string: "https://ui.example.com/lui"),
            domainServiceID: "test-domain",
            customAttributesXML: "<TAG>x</TAG>",
            decryptorSetup: "ONDEMAND"
        )
        let init1 = PlayReadyInitData(records: [.wrmHeader(header)])
        let encoded = try PlayReadyInitData.encode(init1)
        let parsed = try PlayReadyInitData.parse(encoded)
        if case let .wrmHeader(out) = parsed.records[0] {
            #expect(out.version == .v4_3)
            #expect(out.checksum == Data([0x01, 0x02, 0x03, 0x04]))
            #expect(out.domainServiceID == "test-domain")
            #expect(out.decryptorSetup == "ONDEMAND")
            #expect(out.customAttributesXML?.contains("TAG") == true)
        } else {
            Issue.record("expected wrmHeader")
        }
    }

    @Test
    func wrmHeaderV42DecryptorSetupOnlyPath() throws {
        let kid = Data(repeating: 0x99, count: 16)
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_2,
            kids: [PlayReadyInitData.WRMHeader.KID(value: kid)],
            decryptorSetup: "OFFLINE"
        )
        let init1 = PlayReadyInitData(records: [.wrmHeader(header)])
        let encoded = try PlayReadyInitData.encode(init1)
        let parsed = try PlayReadyInitData.parse(encoded)
        if case let .wrmHeader(out) = parsed.records[0] {
            #expect(out.decryptorSetup == "OFFLINE")
        } else {
            Issue.record("expected wrmHeader")
        }
    }
}
