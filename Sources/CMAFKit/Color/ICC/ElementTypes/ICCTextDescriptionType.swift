// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCTextDescriptionType
//
// Reference: ICC.1:2001-04 §6.5.17 (textDescriptionType, signature 'desc').
//
// Legacy v2-only type retained for backward compatibility with profiles
// authored before ICC v4. The on-wire layout is:
//   UInt32 asciiLength + ASCII string (null-terminated)
//   UInt32 unicodeLanguageCode + UInt32 unicodeLength + unicode (UTF-16BE)
//   UInt16 scriptCodeID + UInt8 macLength + 67 bytes macDescription

import Foundation

/// Legacy v2 text-description type per ICC.1:2001-04 §6.5.17.
public struct ICCTextDescriptionType: Sendable, Hashable, Equatable, Codable {
    public let asciiDescription: String
    public let unicodeLanguageCode: UInt32
    public let unicodeDescription: String
    public let scriptCodeID: UInt16
    /// Mac description, fixed 67 bytes (pascal string), preserved verbatim.
    public let macDescription: Data

    public init(
        asciiDescription: String,
        unicodeLanguageCode: UInt32 = 0,
        unicodeDescription: String = "",
        scriptCodeID: UInt16 = 0,
        macDescription: Data = Data(count: 67)
    ) {
        precondition(
            macDescription.count == 67,
            "ICC textDescription macDescription must be 67 bytes"
        )
        self.asciiDescription = asciiDescription
        self.unicodeLanguageCode = unicodeLanguageCode
        self.unicodeDescription = unicodeDescription
        self.scriptCodeID = scriptCodeID
        self.macDescription = macDescription
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCTextDescriptionType {
        let asciiLength = try reader.readUInt32()
        let asciiBytes = try reader.readData(count: Int(asciiLength))
        let asciiTrimmed = asciiBytes.prefix { $0 != 0 }
        let asciiDescription = String(data: Data(asciiTrimmed), encoding: .ascii) ?? ""

        let unicodeLangCode = try reader.readUInt32()
        let unicodeLength = try reader.readUInt32()
        let unicodeBytes = try reader.readData(count: Int(unicodeLength) * 2)
        let unicodeDescription = String(data: unicodeBytes, encoding: .utf16BigEndian) ?? ""

        let scriptCodeID = try reader.readUInt16()
        _ = try reader.readUInt8()  // macLength (preserved as pascal-prefix byte of macDescription)
        let macDescriptionData = try reader.readData(count: 67)

        return ICCTextDescriptionType(
            asciiDescription: asciiDescription,
            unicodeLanguageCode: unicodeLangCode,
            unicodeDescription: unicodeDescription,
            scriptCodeID: scriptCodeID,
            macDescription: macDescriptionData
        )
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        var asciiData = asciiDescription.data(using: .ascii) ?? Data()
        asciiData.append(0)
        writer.writeUInt32(UInt32(asciiData.count))
        writer.writeData(asciiData)

        let unicodeData = unicodeDescription.data(using: .utf16BigEndian) ?? Data()
        let unicodeCount = unicodeData.count / 2
        writer.writeUInt32(unicodeLanguageCode)
        writer.writeUInt32(UInt32(unicodeCount))
        writer.writeData(unicodeData)

        writer.writeUInt16(scriptCodeID)
        writer.writeUInt8(macDescription.first ?? 0)
        writer.writeData(macDescription)
    }
}
