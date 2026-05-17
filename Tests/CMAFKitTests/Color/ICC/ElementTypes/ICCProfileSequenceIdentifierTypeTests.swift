// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCProfileSequenceIdentifierType")
struct ICCProfileSequenceIdentifierTypeTests {

    private func makeMlucElement(text: String) -> ICCElement {
        let mluc = ICCMultiLocalizedUnicodeType(strings: [
            .init(languageCode: 0x656E, countryCode: 0x5553, text: text)
        ])
        return .multiLocalizedUnicode(mluc)
    }

    @Test
    func emptyEntriesRoundTrip() throws {
        let original = ICCProfileSequenceIdentifierType(entries: [])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceIdentifierType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func singleEntryRoundTrip() throws {
        let profileID = Data((0..<16).map { UInt8($0) })
        let entry = ICCProfileSequenceIdentifierType.Entry(
            profileID: profileID,
            profileDescription: makeMlucElement(text: "Display profile")
        )
        let original = ICCProfileSequenceIdentifierType(entries: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceIdentifierType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.entries.count == 1)
        #expect(decoded.entries[0].profileID == profileID)
    }

    @Test
    func multipleEntriesRoundTrip() throws {
        let entries = (0..<3).map { i in
            ICCProfileSequenceIdentifierType.Entry(
                profileID: Data(repeating: UInt8(i), count: 16),
                profileDescription: makeMlucElement(text: "Entry \(i)")
            )
        }
        let original = ICCProfileSequenceIdentifierType(entries: entries)
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceIdentifierType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func profileIDPreservedBitwise() throws {
        let profileID = Data([
            0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
            0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0
        ])
        let entry = ICCProfileSequenceIdentifierType.Entry(
            profileID: profileID,
            profileDescription: makeMlucElement(text: "MD5-checksum profile")
        )
        let original = ICCProfileSequenceIdentifierType(entries: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceIdentifierType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.entries[0].profileID == profileID)
    }

    @Test
    func multilingualDescriptionPreserved() throws {
        let mluc = ICCMultiLocalizedUnicodeType(strings: [
            .init(languageCode: 0x656E, countryCode: 0x5553, text: "Display P3"),
            .init(languageCode: 0x6672, countryCode: 0x4652, text: "Affichage P3")
        ])
        let entry = ICCProfileSequenceIdentifierType.Entry(
            profileID: Data(count: 16),
            profileDescription: .multiLocalizedUnicode(mluc)
        )
        let original = ICCProfileSequenceIdentifierType(entries: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceIdentifierType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        if case .multiLocalizedUnicode(let decodedMluc) = decoded.entries[0].profileDescription {
            #expect(decodedMluc.strings.count == 2)
            #expect(decodedMluc.strings[0].text == "Display P3")
            #expect(decodedMluc.strings[1].text == "Affichage P3")
        } else {
            Issue.record("Expected mluc")
        }
    }

    @Test
    func offsetOutOfBoundsThrows() async throws {
        var w = BinaryWriter()
        w.writeUInt32(1)
        w.writeUInt32(9999)  // bad offset
        w.writeUInt32(20)
        var reader = BinaryReader(w.data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCProfileSequenceIdentifierType.parsePayload(
                reader: &reader,
                byteCount: w.data.count
            )
        }
    }

    @Test
    func entrySizeOverflowThrows() async throws {
        var w = BinaryWriter()
        w.writeUInt32(1)
        w.writeUInt32(20)  // offset (wire-relative: preamble 8 + header 12 = 20)
        w.writeUInt32(99999)  // size way too big
        var reader = BinaryReader(w.data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCProfileSequenceIdentifierType.parsePayload(
                reader: &reader,
                byteCount: w.data.count
            )
        }
    }

    @Test
    func profileIDSizeIsExactly16() throws {
        let goodID = Data(count: 16)
        let entry = ICCProfileSequenceIdentifierType.Entry(
            profileID: goodID,
            profileDescription: makeMlucElement(text: "x")
        )
        #expect(entry.profileID.count == 16)
    }

    @Test
    func iccElementWraps() throws {
        let entry = ICCProfileSequenceIdentifierType.Entry(
            profileID: Data(count: 16),
            profileDescription: makeMlucElement(text: "Display")
        )
        let psid = ICCProfileSequenceIdentifierType(entries: [entry])
        let element: ICCElement = .profileSequenceIdentifier(psid)
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        if case .profileSequenceIdentifier(let decodedPsid) = decoded {
            #expect(decodedPsid == psid)
        } else {
            Issue.record("Expected profileSequenceIdentifier")
        }
    }

    @Test
    func equatableConformance() {
        let entry = ICCProfileSequenceIdentifierType.Entry(
            profileID: Data(count: 16),
            profileDescription: makeMlucElement(text: "x")
        )
        let a = ICCProfileSequenceIdentifierType(entries: [entry])
        let b = ICCProfileSequenceIdentifierType(entries: [entry])
        #expect(a == b)
    }

    @Test
    func emptyMlucDescriptionRoundTrip() throws {
        let entry = ICCProfileSequenceIdentifierType.Entry(
            profileID: Data(count: 16),
            profileDescription: .multiLocalizedUnicode(
                ICCMultiLocalizedUnicodeType(strings: [])
            )
        )
        let original = ICCProfileSequenceIdentifierType(entries: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceIdentifierType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func fiveEntriesOrderPreserved() throws {
        let entries = (0..<5).map { i in
            ICCProfileSequenceIdentifierType.Entry(
                profileID: Data(repeating: UInt8(i + 10), count: 16),
                profileDescription: makeMlucElement(text: "Profile \(i)")
            )
        }
        let original = ICCProfileSequenceIdentifierType(entries: entries)
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceIdentifierType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.entries.count == 5)
        for i in 0..<5 {
            #expect(decoded.entries[i].profileID.first == UInt8(i + 10))
        }
    }
}
