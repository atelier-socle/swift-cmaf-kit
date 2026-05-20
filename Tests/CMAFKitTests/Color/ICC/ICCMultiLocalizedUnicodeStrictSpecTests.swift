// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Cross-encoder fixture tests for the ICC.1:2022 §10.13 mluc
// element. Each fixture encodes the spec-strict element-relative
// `stringOffset` convention as emitted by external encoders
// (Adobe ICC Profile Library, Apple ColorSync, Argyll CMS). The
// byte arrays are short hand-crafted slices that match the wire
// format the real encoders produce — copyrighted profile content
// is not embedded; only the structural mluc bytes that are facts
// about the standard's encoding.
//
// Synthesis approach: every fixture below was assembled by hand
// from the ICC.1:2022 §10.13 specification, modelled after the
// `desc` tag mluc element that ships in the named encoder's
// reference profile. The offsets are element-relative
// (`elementPreambleSize + payloadHeaderSize + recordTableSize`)
// per ICC.1:2022 §10.13; the legacy payload-relative variant
// is exercised separately to verify the dual-path decoder.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICC mluc — cross-encoder fixtures (Adobe / ColorSync / Argyll)")
struct ICCMultiLocalizedUnicodeStrictSpecTests {

    // MARK: - Adobe RGB (1998) — single record, en-US

    /// Adobe RGB (1998) ICC profile, `desc` tag mluc element.
    /// One record: language 'en' (0x656E), country 'US' (0x5553),
    /// text "Adobe RGB (1998)" (16 chars × 2 bytes UTF-16BE = 32 bytes).
    /// Element-relative string offset = 8 (preamble) + 8 (header)
    /// + 12 (records) = 28 (0x1C).
    @Test
    func adobeRGB1998DescriptionTagParses() throws {
        let bytes: [UInt8] = [
            // 'mluc' signature + reserved
            0x6D, 0x6C, 0x75, 0x63,
            0x00, 0x00, 0x00, 0x00,
            // numberOfRecords = 1
            0x00, 0x00, 0x00, 0x01,
            // nameRecordSize = 12
            0x00, 0x00, 0x00, 0x0C,
            // record: lang='en', country='US', length=32, offset=28
            0x65, 0x6E, 0x55, 0x53,
            0x00, 0x00, 0x00, 0x20,
            0x00, 0x00, 0x00, 0x1C,
            // "Adobe RGB (1998)" in UTF-16BE
            0x00, 0x41, 0x00, 0x64, 0x00, 0x6F, 0x00, 0x62,
            0x00, 0x65, 0x00, 0x20, 0x00, 0x52, 0x00, 0x47,
            0x00, 0x42, 0x00, 0x20, 0x00, 0x28, 0x00, 0x31,
            0x00, 0x39, 0x00, 0x39, 0x00, 0x38, 0x00, 0x29
        ]
        let parsed = try Self.parseMluc(Data(bytes))
        try #require(parsed.strings.count == 1)
        let record = parsed.strings[0]
        #expect(record.languageCode == 0x656E)  // 'en'
        #expect(record.countryCode == 0x5553)  // 'US'
        #expect(record.text == "Adobe RGB (1998)")
    }

    // MARK: - ColorSync Display P3 — multi-language record set

    /// Apple ColorSync `Display P3` profile, `desc` tag mluc
    /// element. Three records (en-US, de-DE, fr-FR), each
    /// carrying the localised string "Display P3" (10 chars ×
    /// 2 bytes = 20 bytes per pool slot).
    /// Element-relative offsets: 8 + 8 + 36 = 52 (pool start),
    /// then 72, 92.
    @Test
    func colorSyncDisplayP3DescriptionTagParses() throws {
        let bytes: [UInt8] = [
            // preamble
            0x6D, 0x6C, 0x75, 0x63,
            0x00, 0x00, 0x00, 0x00,
            // numberOfRecords = 3
            0x00, 0x00, 0x00, 0x03,
            // nameRecordSize = 12
            0x00, 0x00, 0x00, 0x0C,
            // record 1: en-US, length=20, offset=52
            0x65, 0x6E, 0x55, 0x53,
            0x00, 0x00, 0x00, 0x14,
            0x00, 0x00, 0x00, 0x34,
            // record 2: de-DE, length=20, offset=72
            0x64, 0x65, 0x44, 0x45,
            0x00, 0x00, 0x00, 0x14,
            0x00, 0x00, 0x00, 0x48,
            // record 3: fr-FR, length=20, offset=92
            0x66, 0x72, 0x46, 0x52,
            0x00, 0x00, 0x00, 0x14,
            0x00, 0x00, 0x00, 0x5C,
            // pool slot 1 — "Display P3" (en-US)
            0x00, 0x44, 0x00, 0x69, 0x00, 0x73, 0x00, 0x70,
            0x00, 0x6C, 0x00, 0x61, 0x00, 0x79, 0x00, 0x20,
            0x00, 0x50, 0x00, 0x33,
            // pool slot 2 — "Display P3" (de-DE)
            0x00, 0x44, 0x00, 0x69, 0x00, 0x73, 0x00, 0x70,
            0x00, 0x6C, 0x00, 0x61, 0x00, 0x79, 0x00, 0x20,
            0x00, 0x50, 0x00, 0x33,
            // pool slot 3 — "Display P3" (fr-FR)
            0x00, 0x44, 0x00, 0x69, 0x00, 0x73, 0x00, 0x70,
            0x00, 0x6C, 0x00, 0x61, 0x00, 0x79, 0x00, 0x20,
            0x00, 0x50, 0x00, 0x33
        ]
        let parsed = try Self.parseMluc(Data(bytes))
        #expect(parsed.strings.count == 3)
        #expect(parsed.strings[0].languageCode == 0x656E)
        #expect(parsed.strings[0].countryCode == 0x5553)
        #expect(parsed.strings[0].text == "Display P3")
        #expect(parsed.strings[1].languageCode == 0x6465)  // 'de'
        #expect(parsed.strings[1].countryCode == 0x4445)  // 'DE'
        #expect(parsed.strings[1].text == "Display P3")
        #expect(parsed.strings[2].languageCode == 0x6672)  // 'fr'
        #expect(parsed.strings[2].countryCode == 0x4652)  // 'FR'
        #expect(parsed.strings[2].text == "Display P3")
    }

    // MARK: - Argyll CMS linear sRGB — single record, en-US

    /// Argyll CMS `linear_sRGB.icm` profile, `desc` tag mluc
    /// element. One record: en-US, text "linear_sRGB" (11 chars).
    /// Element-relative offset = 28.
    @Test
    func argyllCMSLinearSRGBDescriptionTagParses() throws {
        let bytes: [UInt8] = [
            0x6D, 0x6C, 0x75, 0x63,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x0C,
            // record: en-US, length=22, offset=28
            0x65, 0x6E, 0x55, 0x53,
            0x00, 0x00, 0x00, 0x16,
            0x00, 0x00, 0x00, 0x1C,
            // "linear_sRGB" UTF-16BE
            0x00, 0x6C, 0x00, 0x69, 0x00, 0x6E, 0x00, 0x65,
            0x00, 0x61, 0x00, 0x72, 0x00, 0x5F, 0x00, 0x73,
            0x00, 0x52, 0x00, 0x47, 0x00, 0x42
        ]
        let parsed = try Self.parseMluc(Data(bytes))
        try #require(parsed.strings.count == 1)
        #expect(parsed.strings[0].text == "linear_sRGB")
        #expect(parsed.strings[0].languageCode == 0x656E)
    }

    // MARK: - Legacy payload-relative dual-path test

    /// Legacy mluc fixture: a hand-built tag whose `stringOffset`
    /// is measured from the start of the payload (not the
    /// element). CMAFKit's dual-path decoder must still parse it
    /// cleanly. For one record, offset = 8 + 12 = 20 (0x14).
    @Test
    func legacyPayloadRelativeMlucParses() throws {
        let bytes: [UInt8] = [
            0x6D, 0x6C, 0x75, 0x63,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x0C,
            // record: en-US, length=8, offset=20 (payload-relative)
            0x65, 0x6E, 0x55, 0x53,
            0x00, 0x00, 0x00, 0x08,
            0x00, 0x00, 0x00, 0x14,
            // "Test" UTF-16BE
            0x00, 0x54, 0x00, 0x65, 0x00, 0x73, 0x00, 0x74
        ]
        let parsed = try Self.parseMluc(Data(bytes))
        try #require(parsed.strings.count == 1)
        #expect(parsed.strings[0].text == "Test")
    }

    // MARK: - Element-relative encoder verification

    /// Confirm that CMAFKit's encoder emits element-relative
    /// offsets per ICC.1:2022 §10.13. Encode a 2-record mluc and
    /// inspect the wire offset of record 0.
    @Test
    func cmafKitEmitsElementRelativeOffsets() throws {
        let element = ICCMultiLocalizedUnicodeType(
            strings: [
                ICCMultiLocalizedUnicodeType.LocalizedString(
                    languageCode: 0x656E, countryCode: 0x5553, text: "AA"
                ),
                ICCMultiLocalizedUnicodeType.LocalizedString(
                    languageCode: 0x6672, countryCode: 0x4652, text: "BB"
                )
            ]
        )
        var writer = BinaryWriter()
        element.encodePayload(to: &writer)
        let payload = writer.data
        // Layout after preamble (which the writer caller emits
        // separately): numberOfNames | nameRecordSize | record[0]
        // (12 bytes) | record[1] (12 bytes) | strings…
        // Offset of record[0].stringOffset is at byte 8 + 8 = 16,
        // i.e. inside the payload at index 16 (the 4-byte field
        // immediately after the length).
        // The payload itself starts at byte 0 above; the
        // `stringOffset` field of record 0 sits at index 16.
        let stringOffsetFieldStart = 8 + 8
        let offsetValue = Self.readUInt32BE(
            from: payload, at: stringOffsetFieldStart
        )
        // Element-relative pool base = elementPreambleSize (8) +
        // payloadHeaderSize (8) + recordTableSize (12 * 2) = 40.
        #expect(offsetValue == 40)
    }

    // MARK: - Edge cases

    @Test
    func emptyRecordListRoundTrip() throws {
        let bytes: [UInt8] = [
            0x6D, 0x6C, 0x75, 0x63,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,  // 0 records
            0x00, 0x00, 0x00, 0x0C
        ]
        let parsed = try Self.parseMluc(Data(bytes))
        #expect(parsed.strings.isEmpty)
    }

    @Test
    func singleRecordMissingENUSStillParses() throws {
        // One record, language 'ja' (0x6A61), country 'JP' (0x4A50).
        let bytes: [UInt8] = [
            0x6D, 0x6C, 0x75, 0x63,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x0C,
            0x6A, 0x61, 0x4A, 0x50,
            0x00, 0x00, 0x00, 0x04,
            0x00, 0x00, 0x00, 0x1C,
            // 2 UTF-16BE chars
            0x30, 0x42, 0x30, 0x44  // hiragana あい
        ]
        let parsed = try Self.parseMluc(Data(bytes))
        #expect(parsed.strings.count == 1)
        #expect(parsed.strings[0].languageCode == 0x6A61)
        #expect(parsed.strings[0].countryCode == 0x4A50)
    }

    @Test
    func malformedOffsetThrows() {
        // Offset deliberately pointing past the end of the payload.
        let bytes: [UInt8] = [
            0x6D, 0x6C, 0x75, 0x63,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x0C,
            0x65, 0x6E, 0x55, 0x53,
            0x00, 0x00, 0x00, 0x04,
            0x00, 0x00, 0x10, 0x00,  // bogus offset = 4096
            0x00, 0x41, 0x00, 0x42
        ]
        #expect(throws: ISOBoxError.self) {
            _ = try Self.parseMluc(Data(bytes))
        }
    }

    // MARK: - Helpers

    private static func parseMluc(
        _ data: Data
    ) throws -> ICCMultiLocalizedUnicodeType {
        var reader = BinaryReader(data)
        // Skip the 8-byte element preamble (signature + reserved).
        _ = try reader.readUInt32()
        _ = try reader.readUInt32()
        return try ICCMultiLocalizedUnicodeType.parsePayload(
            reader: &reader, byteCount: data.count - 8
        )
    }

    private static func readUInt32BE(from data: Data, at offset: Int) -> UInt32 {
        let bytes = [UInt8](data)
        return (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }
}
