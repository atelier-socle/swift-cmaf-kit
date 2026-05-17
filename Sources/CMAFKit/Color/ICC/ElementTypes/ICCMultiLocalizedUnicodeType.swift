// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCMultiLocalizedUnicodeType
//
// Reference: ICC.1:2022 §10.13 (multiLocalizedUnicodeType, signature 'mluc').
//
// On-wire layout: UInt32 numberOfNames + UInt32 nameRecordSize
//   + numberOfNames × (UInt16 languageCode + UInt16 countryCode
//                      + UInt32 stringLength + UInt32 stringOffset)
//   + string data (UTF-16BE).
//
// String offsets are relative to the start of the tag's 8-byte preamble.

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
            records.append(Record(language: lang, country: country, length: length, offset: offset))
        }

        let preambleByteCount = 8 + 12 * Int(numberOfNames)
        let remainingBytes = byteCount - preambleByteCount
        guard remainingBytes >= 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC mluc payload too short for declared name count"
            )
        }
        let stringPoolData = try reader.readData(count: remainingBytes)
        // String offsets are relative to the start of the tag (i.e., the
        // 8-byte preamble + record table is `8 + 12 × N` bytes long).
        let poolBaseOffset = 8 + 12 * Int(numberOfNames)

        var strings: [LocalizedString] = []
        strings.reserveCapacity(records.count)
        for rec in records {
            let start = Int(rec.offset) - poolBaseOffset
            let length = Int(rec.length)
            guard start >= 0, start + length <= stringPoolData.count else {
                throw ISOBoxError.malformedFullBox(
                    type: "colr",
                    reason: "ICC mluc string offset/length out of bounds"
                )
            }
            let absStart = stringPoolData.startIndex.advanced(by: start)
            let absEnd = absStart.advanced(by: length)
            let slice = stringPoolData.subdata(in: absStart..<absEnd)
            let str = String(data: slice, encoding: .utf16BigEndian) ?? ""
            strings.append(
                LocalizedString(
                    languageCode: rec.language,
                    countryCode: rec.country,
                    text: str
                ))
        }
        return ICCMultiLocalizedUnicodeType(strings: strings)
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt32(UInt32(strings.count))
        writer.writeUInt32(12)  // nameRecordSize

        let preambleSize = 8 + 12 * strings.count
        var cumulativeOffset = UInt32(preambleSize)
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
