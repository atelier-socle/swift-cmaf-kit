// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - VisualSampleEntryFields
//
// Reference: ISO/IEC 14496-12 §8.5.2 (VisualSampleEntry).
//
// The 78-byte common prefix shared by every video codec sample entry
// (avc1, hvc1, vp09, av01, mp4v, dvh1, encv, ...). After the 16-byte
// SampleEntry preamble (6 reserved + UInt16 dataReferenceIndex), the
// VisualSampleEntry adds 62 bytes carrying width/height, default
// resolution, frame count, and the 32-byte compressor name field.

import Foundation

/// The 78-byte common prefix shared by every video sample entry.
///
/// Reference: ISO/IEC 14496-12 §8.5.2.
public struct VisualSampleEntryFields: Sendable, Equatable, Hashable {
    /// 1-based index into the track's data reference table.
    public let dataReferenceIndex: UInt16
    public let width: UInt16
    public let height: UInt16
    /// Horizontal resolution in 16.16 fixed-point pixels per inch.
    /// Default: 0x00480000 (72 dpi).
    public let horizResolution: UInt32
    /// Vertical resolution in 16.16 fixed-point pixels per inch.
    /// Default: 0x00480000 (72 dpi).
    public let vertResolution: UInt32
    /// Frame count; must be 1 per spec.
    public let frameCount: UInt16
    /// Compressor name (up to 31 ASCII characters). Stored as 32 bytes
    /// on the wire (1-byte length prefix + 31 bytes padded with zeros).
    public let compressorName: String
    /// Depth; default 0x0018 (24).
    public let depth: UInt16

    public init(
        dataReferenceIndex: UInt16 = 1,
        width: UInt16,
        height: UInt16,
        horizResolution: UInt32 = 0x0048_0000,
        vertResolution: UInt32 = 0x0048_0000,
        frameCount: UInt16 = 1,
        compressorName: String = "",
        depth: UInt16 = 0x0018
    ) {
        precondition(
            frameCount == 1,
            "VisualSampleEntryFields: frameCount must be 1 per ISO/IEC 14496-12 §8.5.2"
        )
        precondition(
            compressorName.utf8.count <= 31,
            "VisualSampleEntryFields: compressorName must be at most 31 bytes"
        )
        self.dataReferenceIndex = dataReferenceIndex
        self.width = width
        self.height = height
        self.horizResolution = horizResolution
        self.vertResolution = vertResolution
        self.frameCount = frameCount
        self.compressorName = compressorName
        self.depth = depth
    }

    public static func parse(reader: inout BinaryReader) throws -> VisualSampleEntryFields {
        // SampleEntry preamble: 6 reserved bytes (must be zero) + UInt16 dataReferenceIndex.
        for _ in 0..<6 {
            let byte = try reader.readUInt8()
            guard byte == 0 else {
                throw ISOBoxError.malformedFullBox(
                    type: "vsmp",
                    reason: "VisualSampleEntry SampleEntry reserved field must be zero"
                )
            }
        }
        let dataReferenceIndex = try reader.readUInt16()

        // VisualSampleEntry extension (62 bytes).
        let preDefined1 = try reader.readUInt16()
        guard preDefined1 == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "vsmp",
                reason: "VisualSampleEntry preDefined1 must be zero"
            )
        }
        let reserved2 = try reader.readUInt16()
        guard reserved2 == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "vsmp",
                reason: "VisualSampleEntry reserved2 must be zero"
            )
        }
        for _ in 0..<3 {
            let predefinedWord = try reader.readUInt32()
            guard predefinedWord == 0 else {
                throw ISOBoxError.malformedFullBox(
                    type: "vsmp",
                    reason: "VisualSampleEntry preDefined3 must be zero"
                )
            }
        }
        let width = try reader.readUInt16()
        let height = try reader.readUInt16()
        let horizResolution = try reader.readUInt32()
        let vertResolution = try reader.readUInt32()
        let reserved3 = try reader.readUInt32()
        guard reserved3 == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "vsmp",
                reason: "VisualSampleEntry reserved3 must be zero"
            )
        }
        let frameCount = try reader.readUInt16()
        guard frameCount == 1 else {
            throw ISOBoxError.malformedFullBox(
                type: "vsmp",
                reason: "VisualSampleEntry frameCount must be 1, got \(frameCount)"
            )
        }
        // 32-byte compressorName: 1 length byte + 31 bytes.
        let nameLength = try reader.readUInt8()
        guard nameLength <= 31 else {
            throw ISOBoxError.malformedFullBox(
                type: "vsmp",
                reason: "VisualSampleEntry compressorName length \(nameLength) exceeds 31"
            )
        }
        let nameBytes = try reader.readData(count: 31)
        let nameSlice = nameBytes.prefix(Int(nameLength))
        let compressorName = String(data: Data(nameSlice), encoding: .ascii) ?? ""

        let depth = try reader.readUInt16()
        let preDefined4Raw = try reader.readUInt16()
        let preDefined4 = Int16(bitPattern: preDefined4Raw)
        guard preDefined4 == -1 else {
            throw ISOBoxError.malformedFullBox(
                type: "vsmp",
                reason: "VisualSampleEntry preDefined4 must be -1, got \(preDefined4)"
            )
        }

        return VisualSampleEntryFields(
            dataReferenceIndex: dataReferenceIndex,
            width: width,
            height: height,
            horizResolution: horizResolution,
            vertResolution: vertResolution,
            frameCount: frameCount,
            compressorName: compressorName,
            depth: depth
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeZeros(6)  // SampleEntry reserved
        writer.writeUInt16(dataReferenceIndex)
        writer.writeUInt16(0)  // preDefined1
        writer.writeUInt16(0)  // reserved2
        writer.writeZeros(12)  // 3 × UInt32 preDefined3
        writer.writeUInt16(width)
        writer.writeUInt16(height)
        writer.writeUInt32(horizResolution)
        writer.writeUInt32(vertResolution)
        writer.writeUInt32(0)  // reserved3
        writer.writeUInt16(frameCount)
        // compressorName: 1 length byte + 31 bytes (zero-padded).
        let nameData = compressorName.data(using: .ascii) ?? Data()
        let length = UInt8(min(nameData.count, 31))
        writer.writeUInt8(length)
        var padded = nameData.prefix(31)
        if padded.count < 31 {
            padded.append(Data(count: 31 - padded.count))
        }
        writer.writeData(Data(padded))
        writer.writeUInt16(depth)
        writer.writeInt16(-1)  // preDefined4
    }
}
