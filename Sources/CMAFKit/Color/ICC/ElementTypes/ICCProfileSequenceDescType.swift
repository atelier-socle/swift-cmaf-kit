// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCProfileSequenceDescType
//
// Reference: ICC.1:2022 §10.21 (profileSequenceDescType, signature 'pseq').
//
// On-wire layout (after the 8-byte type preamble):
//   UInt32 count
//   For each entry i in 0..count:
//     UInt32  deviceManufacturer
//     UInt32  deviceModel
//     UInt64  deviceAttributes
//     UInt32  technology (signature, may be 0)
//     ICCElement deviceMfgDescription   (mluc or textDescription)
//     ICCElement deviceModelDescription (mluc or textDescription)

import Foundation

/// Profile-sequence description per ICC.1:2022 §10.21.
public struct ICCProfileSequenceDescType: Sendable, Hashable, Equatable {

    /// One profile-sequence entry.
    public struct Entry: Sendable, Hashable, Equatable {
        public let deviceManufacturer: UInt32
        public let deviceModel: UInt32
        public let deviceAttributes: UInt64
        /// Technology signature (per ICC.1:2022 Annex A.3). May be 0.
        public let technology: UInt32
        /// Device-manufacturer description. Must be a `mluc` or
        /// `textDescription` element.
        public let deviceMfgDescription: ICCElement
        /// Device-model description. Must be a `mluc` or
        /// `textDescription` element.
        public let deviceModelDescription: ICCElement

        public init(
            deviceManufacturer: UInt32,
            deviceModel: UInt32,
            deviceAttributes: UInt64,
            technology: UInt32,
            deviceMfgDescription: ICCElement,
            deviceModelDescription: ICCElement
        ) {
            precondition(
                Self.isDescriptionElement(deviceMfgDescription),
                "ICCProfileSequenceDescType: deviceMfgDescription must be mluc or textDescription"
            )
            precondition(
                Self.isDescriptionElement(deviceModelDescription),
                "ICCProfileSequenceDescType: deviceModelDescription must be mluc or textDescription"
            )
            self.deviceManufacturer = deviceManufacturer
            self.deviceModel = deviceModel
            self.deviceAttributes = deviceAttributes
            self.technology = technology
            self.deviceMfgDescription = deviceMfgDescription
            self.deviceModelDescription = deviceModelDescription
        }

        private static func isDescriptionElement(_ element: ICCElement) -> Bool {
            switch element {
            case .multiLocalizedUnicode, .textDescription: return true
            default: return false
            }
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCProfileSequenceDescType {
        let payload = try reader.readData(count: byteCount)
        var head = BinaryReader(payload)

        let count = try head.readUInt32()
        var entries: [Entry] = []
        entries.reserveCapacity(Int(count))

        for _ in 0..<count {
            let manufacturer = try head.readUInt32()
            let model = try head.readUInt32()
            let attributes = try head.readUInt64()
            let technology = try head.readUInt32()

            let mfgDesc = try parseEmbeddedDescription(reader: &head)
            let modelDesc = try parseEmbeddedDescription(reader: &head)

            entries.append(
                Entry(
                    deviceManufacturer: manufacturer,
                    deviceModel: model,
                    deviceAttributes: attributes,
                    technology: technology,
                    deviceMfgDescription: mfgDesc,
                    deviceModelDescription: modelDesc
                ))
        }

        return ICCProfileSequenceDescType(entries: entries)
    }

    /// Parse an embedded ICC element of description type. The embedded
    /// element does not carry its byte count explicitly, so this method
    /// peeks the element-type-specific layout to compute the byte count,
    /// then delegates to ``ICCElement/parse(reader:payloadByteCount:)``
    /// on the original reader.
    private static func parseEmbeddedDescription(
        reader: inout BinaryReader
    ) throws -> ICCElement {
        // Snapshot the live reader so we can peek without advancing it.
        var peek = reader

        let signatureRaw = try peek.readUInt32()
        let reserved = try peek.readUInt32()
        guard reserved == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC embedded element reserved field is non-zero"
            )
        }
        guard let signature = ICCElementTypeSignature(rawValue: signatureRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC embedded description: unknown type 0x\(String(signatureRaw, radix: 16))"
            )
        }

        let embeddedPayloadByteCount: Int
        switch signature {
        case .multiLocalizedUnicode:
            embeddedPayloadByteCount = try computeMLUCByteCount(reader: &peek)
        case .textDescription:
            embeddedPayloadByteCount = try computeTextDescriptionByteCount(reader: &peek)
        default:
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC pseq embedded description must be mluc or textDescription, got 0x\(String(signatureRaw, radix: 16))"
            )
        }

        return try ICCElement.parse(reader: &reader, payloadByteCount: embeddedPayloadByteCount)
    }

    /// Compute the byte count (preamble included) of an `mluc` element
    /// from a reader positioned just after its 8-byte preamble.
    ///
    /// ``ICCMultiLocalizedUnicodeType``'s encoder/parser pair use
    /// payload-relative offsets (counted from the first byte after the
    /// 8-byte element preamble). The total element byte count therefore
    /// equals `8 + maxPayloadEnd`.
    private static func computeMLUCByteCount(
        reader: inout BinaryReader
    ) throws -> Int {
        let numberOfNames = try reader.readUInt32()
        let nameRecordSize = try reader.readUInt32()
        guard nameRecordSize == 12 else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC embedded mluc nameRecordSize must be 12"
            )
        }
        var maxPayloadEnd: Int = 8 + 12 * Int(numberOfNames)
        for _ in 0..<numberOfNames {
            _ = try reader.readUInt16()  // languageCode
            _ = try reader.readUInt16()  // countryCode
            let length = try reader.readUInt32()
            let offset = try reader.readUInt32()
            maxPayloadEnd = max(maxPayloadEnd, Int(offset) + Int(length))
        }
        return 8 + maxPayloadEnd
    }

    /// Compute the byte count (preamble included) of a `textDescription`
    /// element from a reader positioned just after its 8-byte preamble.
    private static func computeTextDescriptionByteCount(
        reader: inout BinaryReader
    ) throws -> Int {
        let asciiLength = try reader.readUInt32()
        try reader.skip(Int(asciiLength))
        _ = try reader.readUInt32()  // unicodeLanguageCode
        let unicodeLength = try reader.readUInt32()
        try reader.skip(Int(unicodeLength) * 2)
        _ = try reader.readUInt16()  // scriptCodeID
        _ = try reader.readUInt8()  // macLength
        try reader.skip(67)  // macDescription
        return 8 + 4 + Int(asciiLength) + 4 + 4 + Int(unicodeLength) * 2 + 2 + 1 + 67
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt32(UInt32(entries.count))
        for entry in entries {
            writer.writeUInt32(entry.deviceManufacturer)
            writer.writeUInt32(entry.deviceModel)
            writer.writeUInt64(entry.deviceAttributes)
            writer.writeUInt32(entry.technology)
            entry.deviceMfgDescription.encode(to: &writer)
            entry.deviceModelDescription.encode(to: &writer)
        }
    }
}
