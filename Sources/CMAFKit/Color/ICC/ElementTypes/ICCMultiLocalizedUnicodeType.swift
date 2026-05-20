// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCMultiLocalizedUnicodeType
//
// Reference: ICC.1:2010 §10.13 + ICC.1:2022 §10.13
// (multiLocalizedUnicodeType, signature 'mluc').
//
// On-wire layout (the tag element starts at the 'mluc' signature
// byte; offsets noted in the table are element-relative):
//
//   tagOffset  field                              size
//        +0    UInt32  signature ('mluc')         4
//        +4    UInt32  reserved (must be 0)       4
//        +8    UInt32  numberOfNames        N     4
//       +12    UInt32  nameRecordSize             4
//       +16    Records:                         12*N
//                 UInt16  languageCode
//                 UInt16  countryCode
//                 UInt32  stringLength            in bytes (UTF-16BE)
//                 UInt32  stringOffset            element-relative
//   +16+12*N   String pool (UTF-16BE)             variable
//
// **Encoder**: CMAFKit emits `stringOffset` as an **element-
// relative** value, the spec-strict interpretation. Earlier CMAFKit
// builds used payload-relative offsets; that legacy form is still
// accepted on the decode path for backward compatibility, but the
// encoder no longer produces it.
//
// **Decoder**: attempts the element-relative interpretation first.
// If a record's offset/length falls outside the element's
// boundaries, the decoder falls back to the legacy payload-
// relative interpretation. Both round-trip cleanly within CMAFKit.

import Foundation

/// Multi-localized Unicode string type per ICC.1:2022 §10.13.
public struct ICCMultiLocalizedUnicodeType: Sendable, Hashable, Equatable, Codable {
    /// One language-tagged string.
    public struct LocalizedString: Sendable, Hashable, Equatable, Codable {
        /// ISO 639-1 language code.
        public let languageCode: UInt16
        /// ISO 3166-1 alpha-2 country code.
        public let countryCode: UInt16
        public let text: String

        public init(languageCode: UInt16, countryCode: UInt16, text: String) {
            self.languageCode = languageCode
            self.countryCode = countryCode
            self.text = text
        }
    }

    public let strings: [LocalizedString]

    public init(strings: [LocalizedString]) {
        self.strings = strings
    }

    /// Number of bytes contributed by the element preamble that
    /// precedes the payload (4-byte signature + 4-byte reserved).
    internal static let elementPreambleSize = 8
    /// Number of bytes per record entry inside the records table.
    internal static let recordEntrySize = 12

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCMultiLocalizedUnicodeType {
        let numberOfNames = try reader.readUInt32()
        let nameRecordSize = try reader.readUInt32()
        guard nameRecordSize == 12 else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC mluc nameRecordSize must be 12, got \(nameRecordSize)"
            )
        }

        struct Record {
            let language: UInt16
            let country: UInt16
            let length: UInt32
            let offset: UInt32
        }
        var records: [Record] = []
        records.reserveCapacity(Int(numberOfNames))
        for _ in 0..<numberOfNames {
            let lang = try reader.readUInt16()
            let country = try reader.readUInt16()
            let length = try reader.readUInt32()
            let offset = try reader.readUInt32()
            records.append(
                Record(
                    language: lang,
                    country: country,
                    length: length,
                    offset: offset
                ))
        }

        // `parsePayload` is invoked after the caller consumed the
        // 8-byte element preamble. The on-wire payload reaches from
        // the `numberOfNames` field to the end of the element.
        let payloadHeaderSize = 8  // numberOfNames + nameRecordSize
        let recordTableSize = 12 * Int(numberOfNames)
        let preStringBytes = payloadHeaderSize + recordTableSize
        let remainingBytes = byteCount - preStringBytes
        guard remainingBytes >= 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC mluc payload too short for declared name count"
            )
        }
        let stringPoolData = try reader.readData(count: remainingBytes)

        // Element-relative pool base: the string pool starts at
        // `8 (preamble) + 8 (header) + 12*N` from the tag's first
        // byte.
        let elementRelativePoolBase = elementPreambleSize + preStringBytes
        // Legacy payload-relative pool base: the string pool starts
        // at `8 + 12*N` from the start of the payload (which is
        // where prior CMAFKit builds anchored their offsets).
        let legacyRelativePoolBase = preStringBytes

        var strings: [LocalizedString] = []
        strings.reserveCapacity(records.count)
        for rec in records {
            let length = Int(rec.length)
            let elementStart = Int(rec.offset) - elementRelativePoolBase
            let legacyStart = Int(rec.offset) - legacyRelativePoolBase
            let chosenStart: Int
            if elementStart >= 0, elementStart + length <= stringPoolData.count {
                chosenStart = elementStart
            } else if legacyStart >= 0, legacyStart + length <= stringPoolData.count {
                chosenStart = legacyStart
            } else {
                throw ISOBoxError.malformedFullBox(
                    type: "colr",
                    reason: "ICC mluc string offset/length out of bounds"
                )
            }
            let absStart = stringPoolData.startIndex.advanced(by: chosenStart)
            let absEnd = absStart.advanced(by: length)
            let slice = stringPoolData.subdata(in: absStart..<absEnd)
            let str = String(data: slice, encoding: .utf16BigEndian) ?? ""
            strings.append(
                LocalizedString(
                    languageCode: rec.language,
                    countryCode: rec.country,
                    text: str
                )
            )
        }
        return ICCMultiLocalizedUnicodeType(strings: strings)
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt32(UInt32(strings.count))
        writer.writeUInt32(12)  // nameRecordSize

        // Spec-strict element-relative offset: the string pool
        // starts at `8 (preamble) + 8 (header) + 12*N`.
        let elementBasedPoolOffset = Self.elementPreambleSize + 8 + 12 * strings.count
        var cumulativeOffset = UInt32(elementBasedPoolOffset)
        var stringPool = Data()
        for s in strings {
            let utf16Bytes = s.text.data(using: .utf16BigEndian) ?? Data()
            let length = UInt32(utf16Bytes.count)
            writer.writeUInt16(s.languageCode)
            writer.writeUInt16(s.countryCode)
            writer.writeUInt32(length)
            writer.writeUInt32(cumulativeOffset)
            cumulativeOffset += length
            stringPool.append(utf16Bytes)
        }
        writer.writeData(stringPool)
    }
}
