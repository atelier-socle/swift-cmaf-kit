// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCProfileSequenceIdentifierType
//
// Reference: ICC.1:2022 §10.22 (profileSequenceIdentifierType, signature 'psid').
//
// On-wire layout (after the 8-byte type preamble):
//   UInt32 count
//   count × (UInt32 elementOffset + UInt32 elementSize)
//     where offsets are relative to the start of the element data
//     (i.e., relative to the start of the 8-byte preamble).
//   For each entry i, at the recorded offset:
//     16 bytes  profileID  (MD5 from a referenced profile)
//     ICCElement profileDescription  (multiLocalizedUnicodeType)

import Foundation

/// Profile-sequence identifier per ICC.1:2022 §10.22.
public struct ICCProfileSequenceIdentifierType: Sendable, Hashable, Equatable {

    /// One entry in the profile-sequence identifier list.
    public struct Entry: Sendable, Hashable, Equatable {
        /// 16-byte profile identifier, typically an MD5 from a
        /// referenced profile's header `profileID` field.
        public let profileID: Data
        /// Localised profile description (`mluc` element type).
        public let profileDescription: ICCElement

        public init(profileID: Data, profileDescription: ICCElement) {
            precondition(
                profileID.count == 16,
                "ICCProfileSequenceIdentifierType.Entry profileID must be 16 bytes"
            )
            precondition(
                {
                    if case .multiLocalizedUnicode = profileDescription { return true }
                    return false
                }(),
                "ICCProfileSequenceIdentifierType.Entry profileDescription must be mluc"
            )
            self.profileID = profileID
            self.profileDescription = profileDescription
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) { self.entries = entries }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCProfileSequenceIdentifierType {
        let payload = try reader.readData(count: byteCount)
        var head = BinaryReader(payload)

        let count = try head.readUInt32()
        var offsetSizePairs: [(offset: UInt32, size: UInt32)] = []
        offsetSizePairs.reserveCapacity(Int(count))
        for _ in 0..<count {
            let offset = try head.readUInt32()
            let size = try head.readUInt32()
            offsetSizePairs.append((offset: offset, size: size))
        }

        let preambleOffset = 8

        var entries: [Entry] = []
        entries.reserveCapacity(Int(count))
        for pair in offsetSizePairs {
            let offsetInPayload = Int(pair.offset) - preambleOffset
            let size = Int(pair.size)
            guard offsetInPayload >= 0,
                offsetInPayload + size <= payload.count
            else {
                throw ISOBoxError.malformedFullBox(
                    type: "colr",
                    reason: "ICC psid entry offset/size out of bounds"
                )
            }
            let absStart = payload.startIndex.advanced(by: offsetInPayload)
            let absEnd = absStart.advanced(by: size)
            let slice = payload.subdata(in: absStart..<absEnd)
            var entryReader = BinaryReader(slice)

            let profileID = try entryReader.readData(count: 16)
            // Remaining bytes are the embedded mluc element (preamble + payload).
            let remainingBytes = size - 16
            let element = try ICCElement.parse(
                reader: &entryReader,
                payloadByteCount: remainingBytes
            )
            entries.append(Entry(profileID: profileID, profileDescription: element))
        }

        return ICCProfileSequenceIdentifierType(entries: entries)
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        let preambleSize = 8
        let headerSize = 4 + 8 * entries.count

        // First pass: encode each entry to compute size and offset.
        var entryBuffers: [Data] = []
        entryBuffers.reserveCapacity(entries.count)
        var offsetsWire: [UInt32] = []
        var sizes: [UInt32] = []
        offsetsWire.reserveCapacity(entries.count)
        sizes.reserveCapacity(entries.count)

        var cursor = preambleSize + headerSize
        for entry in entries {
            var entryWriter = BinaryWriter()
            entryWriter.writeData(entry.profileID)
            entry.profileDescription.encode(to: &entryWriter)
            let entryBytes = entryWriter.data
            offsetsWire.append(UInt32(cursor))
            sizes.append(UInt32(entryBytes.count))
            entryBuffers.append(entryBytes)
            cursor += entryBytes.count
        }

        writer.writeUInt32(UInt32(entries.count))
        for i in 0..<entries.count {
            writer.writeUInt32(offsetsWire[i])
            writer.writeUInt32(sizes[i])
        }
        for buffer in entryBuffers {
            writer.writeData(buffer)
        }
    }
}
