// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCProfile
//
// Reference: ICC.1:2022 §7 (profile structure).
//
// An ICC profile consists of a 128-byte header followed by a tag table
// (4-byte count + tagCount × 12-byte entries: signature + offset + size)
// followed by the tag element data. Tag data may be padded for 4-byte
// alignment; CMAFKit preserves padding for byte-perfect round-trip.

import Foundation

/// Complete ICC profile per ICC.1:2022 §7.
///
/// `Codable` is intentionally not adopted because the contained
/// ``ICCElement`` instances carry associated tuple values that cannot
/// be auto-synthesised. Round-trip uses the binary `parse` / `encode`
/// surface instead.
public struct ICCProfile: Sendable, Hashable, Equatable {
    public let header: ICCProfileHeader
    public let tags: [ICCTag]

    public init(header: ICCProfileHeader, tags: [ICCTag]) {
        self.header = header
        self.tags = tags
    }

    /// Parse an ICC profile from a reader positioned at the start of
    /// the 128-byte header.
    public static func parse(reader: inout BinaryReader) throws -> ICCProfile {
        let startRemaining = reader.remaining

        let header = try ICCProfileHeader.parse(reader: &reader)
        let tagCount = try reader.readUInt32()

        struct TagTableEntry {
            let signature: ICCTagSignature
            let offset: UInt32
            let size: UInt32
        }
        var entries: [TagTableEntry] = []
        entries.reserveCapacity(Int(tagCount))
        for _ in 0..<tagCount {
            let sigRaw = try reader.readUInt32()
            guard let signature = ICCTagSignature(rawValue: sigRaw) else {
                throw ISOBoxError.malformedFullBox(
                    type: "colr",
                    reason: "Unknown ICC tag signature 0x\(String(sigRaw, radix: 16))"
                )
            }
            let offset = try reader.readUInt32()
            let size = try reader.readUInt32()
            entries.append(TagTableEntry(signature: signature, offset: offset, size: size))
        }

        // After parsing header + tag table, we still hold the entire
        // remaining profile bytes in a `Data` slice for tag data lookup.
        let bytesConsumed = startRemaining - reader.remaining
        let remainingProfileBytes = Int(header.profileSize) - bytesConsumed
        guard remainingProfileBytes >= 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC profile header declares size smaller than already consumed"
            )
        }
        let tagDataPool = try reader.readData(count: remainingProfileBytes)

        // Offsets are relative to the start of the profile (i.e., start
        // of the header). Tag data begins at `128 + 4 + 12 × tagCount`.
        let tagDataPoolBase = 128 + 4 + 12 * Int(tagCount)

        var tags: [ICCTag] = []
        tags.reserveCapacity(Int(tagCount))
        for entry in entries {
            let offsetWithinPool = Int(entry.offset) - tagDataPoolBase
            let size = Int(entry.size)
            guard offsetWithinPool >= 0,
                offsetWithinPool + size <= tagDataPool.count
            else {
                throw ISOBoxError.malformedFullBox(
                    type: "colr",
                    reason: "ICC tag \(entry.signature) offset/size out of pool bounds"
                )
            }
            let absStart = tagDataPool.startIndex.advanced(by: offsetWithinPool)
            let absEnd = absStart.advanced(by: size)
            let tagBytes = tagDataPool.subdata(in: absStart..<absEnd)
            var tagReader = BinaryReader(tagBytes)
            let element = try ICCElement.parse(reader: &tagReader, payloadByteCount: size)
            tags.append(ICCTag(signature: entry.signature, element: element))
        }

        return ICCProfile(header: header, tags: tags)
    }

    public func encode(to writer: inout BinaryWriter) {
        // First pass: compute each tag's encoded size and the total
        // profile size.
        var tagEncodedBytes: [Data] = []
        tagEncodedBytes.reserveCapacity(tags.count)
        for tag in tags {
            var tagWriter = BinaryWriter()
            tag.element.encode(to: &tagWriter)
            // Pad to 4-byte alignment per ICC.1:2022 §7.3.2.
            let unpadded = tagWriter.data
            let padding = (4 - (unpadded.count % 4)) % 4
            var padded = unpadded
            padded.append(Data(count: padding))
            tagEncodedBytes.append(padded)
        }

        let tagDataPoolBase = 128 + 4 + 12 * tags.count
        var cumulativeOffset = UInt32(tagDataPoolBase)
        var tagOffsets: [UInt32] = []
        var tagSizes: [UInt32] = []
        for bytes in tagEncodedBytes {
            tagOffsets.append(cumulativeOffset)
            tagSizes.append(UInt32(bytes.count))
            cumulativeOffset += UInt32(bytes.count)
        }
        let totalProfileSize = Int(cumulativeOffset)

        // Encode header with the recomputed profile size.
        let headerWithSize = ICCProfileHeader(
            profileSize: UInt32(totalProfileSize),
            preferredCMMType: header.preferredCMMType,
            versionMajor: header.versionMajor,
            versionMinor: header.versionMinor,
            versionPatch: header.versionPatch,
            profileClass: header.profileClass,
            colorSpace: header.colorSpace,
            pcsColorSpace: header.pcsColorSpace,
            dateCreated: header.dateCreated,
            fileSignature: header.fileSignature,
            primaryPlatform: header.primaryPlatform,
            flags: header.flags,
            deviceManufacturer: header.deviceManufacturer,
            deviceModel: header.deviceModel,
            deviceAttributes: header.deviceAttributes,
            renderingIntent: header.renderingIntent,
            illuminantXYZ: header.illuminantXYZ,
            creator: header.creator,
            profileID: header.profileID
        )
        headerWithSize.encode(to: &writer)

        // Tag table.
        writer.writeUInt32(UInt32(tags.count))
        for (index, tag) in tags.enumerated() {
            writer.writeUInt32(tag.signature.rawValue)
            writer.writeUInt32(tagOffsets[index])
            writer.writeUInt32(tagSizes[index])
        }

        // Tag data.
        for bytes in tagEncodedBytes {
            writer.writeData(bytes)
        }
    }
}
