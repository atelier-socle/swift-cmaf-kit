// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCProfileSequenceDescType")
struct ICCProfileSequenceDescTypeTests {

    private func makeMlucElement(text: String) -> ICCElement {
        let mluc = ICCMultiLocalizedUnicodeType(strings: [
            .init(languageCode: 0x656E, countryCode: 0x5553, text: text)
        ])
        return .multiLocalizedUnicode(mluc)
    }

    private func makeTextDescriptionElement(ascii: String) -> ICCElement {
        let td = ICCTextDescriptionType(
            asciiDescription: ascii,
            unicodeLanguageCode: 0,
            unicodeDescription: "",
            scriptCodeID: 0,
            macDescription: Data(count: 67)
        )
        return .textDescription(td)
    }

    @Test
    func emptyEntriesRoundTrip() throws {
        let original = ICCProfileSequenceDescType(entries: [])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceDescType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func singleEntryMlucDescriptionsRoundTrip() throws {
        let entry = ICCProfileSequenceDescType.Entry(
            deviceManufacturer: 0x4150_504C,  // 'APPL'
            deviceModel: 0x6970_686E,  // 'iphn'
            deviceAttributes: 0,
            technology: 0x6373_636E,  // 'cscn' (Color Scanner)
            deviceMfgDescription: makeMlucElement(text: "Apple Inc."),
            deviceModelDescription: makeMlucElement(text: "iPhone")
        )
        let original = ICCProfileSequenceDescType(entries: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceDescType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.entries.count == 1)
        #expect(decoded.entries[0].deviceManufacturer == 0x4150_504C)
    }

    @Test
    func singleEntryTextDescriptionRoundTrip() throws {
        let entry = ICCProfileSequenceDescType.Entry(
            deviceManufacturer: 0,
            deviceModel: 0,
            deviceAttributes: 0,
            technology: 0,
            deviceMfgDescription: makeTextDescriptionElement(ascii: "Mfg"),
            deviceModelDescription: makeTextDescriptionElement(ascii: "Model")
        )
        let original = ICCProfileSequenceDescType(entries: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceDescType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func mixedMlucAndTextDescriptionEntriesRoundTrip() throws {
        let entry1 = ICCProfileSequenceDescType.Entry(
            deviceManufacturer: 0x4150_504C,
            deviceModel: 0,
            deviceAttributes: 0,
            technology: 0,
            deviceMfgDescription: makeMlucElement(text: "Vendor A"),
            deviceModelDescription: makeMlucElement(text: "Model A")
        )
        let entry2 = ICCProfileSequenceDescType.Entry(
            deviceManufacturer: 0x4D53_4654,
            deviceModel: 0,
            deviceAttributes: 0,
            technology: 0,
            deviceMfgDescription: makeTextDescriptionElement(ascii: "Vendor B"),
            deviceModelDescription: makeTextDescriptionElement(ascii: "Model B")
        )
        let original = ICCProfileSequenceDescType(entries: [entry1, entry2])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceDescType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.entries.count == 2)
        if case .multiLocalizedUnicode = decoded.entries[0].deviceMfgDescription {
            // OK
        } else {
            Issue.record("Expected mluc")
        }
        if case .textDescription = decoded.entries[1].deviceMfgDescription {
            // OK
        } else {
            Issue.record("Expected textDescription")
        }
    }

    @Test
    func threeEntriesPreserveOrder() throws {
        var entries: [ICCProfileSequenceDescType.Entry] = []
        for i in 0..<3 {
            let manufacturer = UInt32(i + 1)
            let model = UInt32(i * 10)
            let attributes = UInt64(i * 100)
            let technology = UInt32(i)
            let mfgDesc = makeMlucElement(text: "Mfg-\(i)")
            let modelDesc = makeMlucElement(text: "Model-\(i)")
            let entry = ICCProfileSequenceDescType.Entry(
                deviceManufacturer: manufacturer,
                deviceModel: model,
                deviceAttributes: attributes,
                technology: technology,
                deviceMfgDescription: mfgDesc,
                deviceModelDescription: modelDesc
            )
            entries.append(entry)
        }
        let original = ICCProfileSequenceDescType(entries: entries)
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceDescType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.entries.count == 3)
        for i in 0..<3 {
            #expect(decoded.entries[i].deviceManufacturer == UInt32(i + 1))
        }
    }

    @Test
    func deviceAttributesAreUInt64() throws {
        let huge: UInt64 = 0x0102_0304_0506_0708
        let entry = ICCProfileSequenceDescType.Entry(
            deviceManufacturer: 0,
            deviceModel: 0,
            deviceAttributes: huge,
            technology: 0,
            deviceMfgDescription: makeMlucElement(text: "x"),
            deviceModelDescription: makeMlucElement(text: "y")
        )
        let original = ICCProfileSequenceDescType(entries: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceDescType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.entries[0].deviceAttributes == huge)
    }

    @Test
    func mlucWithMultipleLanguagesRoundTrip() throws {
        let mluc = ICCMultiLocalizedUnicodeType(strings: [
            .init(languageCode: 0x656E, countryCode: 0x5553, text: "English"),
            .init(languageCode: 0x6672, countryCode: 0x4652, text: "Français"),
            .init(languageCode: 0x6A61, countryCode: 0x4A50, text: "日本語")
        ])
        let entry = ICCProfileSequenceDescType.Entry(
            deviceManufacturer: 0,
            deviceModel: 0,
            deviceAttributes: 0,
            technology: 0,
            deviceMfgDescription: .multiLocalizedUnicode(mluc),
            deviceModelDescription: makeMlucElement(text: "Model")
        )
        let original = ICCProfileSequenceDescType(entries: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceDescType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        if case .multiLocalizedUnicode(let decodedMluc) = decoded.entries[0].deviceMfgDescription {
            #expect(decodedMluc.strings.count == 3)
        } else {
            Issue.record("Expected mluc")
        }
    }

    @Test
    func iccElementWraps() throws {
        let entry = ICCProfileSequenceDescType.Entry(
            deviceManufacturer: 0,
            deviceModel: 0,
            deviceAttributes: 0,
            technology: 0,
            deviceMfgDescription: makeMlucElement(text: "Mfg"),
            deviceModelDescription: makeMlucElement(text: "Model")
        )
        let pseq = ICCProfileSequenceDescType(entries: [entry])
        let element: ICCElement = .profileSequenceDesc(pseq)
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        if case .profileSequenceDesc(let decodedPseq) = decoded {
            #expect(decodedPseq == pseq)
        } else {
            Issue.record("Expected profileSequenceDesc")
        }
    }

    @Test
    func unknownEmbeddedElementTypeThrows() async throws {
        // count=1, then header (manufacturer/model/attrs/tech), then an
        // unknown embedded element signature.
        var w = BinaryWriter()
        w.writeUInt32(1)  // count
        w.writeUInt32(0)  // mfg
        w.writeUInt32(0)  // model
        w.writeUInt64(0)  // attrs
        w.writeUInt32(0)  // technology
        // Embedded element preamble with sig=`xyz ` (XYZType, not allowed here).
        w.writeUInt32(0x5859_5A20)  // 'XYZ '
        w.writeUInt32(0)  // reserved
        var reader = BinaryReader(w.data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCProfileSequenceDescType.parsePayload(
                reader: &reader,
                byteCount: w.data.count
            )
        }
    }

    @Test
    func equatableConformance() {
        let entry = ICCProfileSequenceDescType.Entry(
            deviceManufacturer: 0,
            deviceModel: 0,
            deviceAttributes: 0,
            technology: 0,
            deviceMfgDescription: makeMlucElement(text: "x"),
            deviceModelDescription: makeMlucElement(text: "y")
        )
        let a = ICCProfileSequenceDescType(entries: [entry])
        let b = ICCProfileSequenceDescType(entries: [entry])
        #expect(a == b)
    }

    @Test
    func techologySignaturePreserved() throws {
        let entry = ICCProfileSequenceDescType.Entry(
            deviceManufacturer: 0,
            deviceModel: 0,
            deviceAttributes: 0,
            technology: 0x6463_6D72,  // 'dcmr'
            deviceMfgDescription: makeMlucElement(text: "x"),
            deviceModelDescription: makeMlucElement(text: "y")
        )
        let original = ICCProfileSequenceDescType(entries: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileSequenceDescType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.entries[0].technology == 0x6463_6D72)
    }
}
