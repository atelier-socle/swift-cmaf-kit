// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FLACSpecificBox (dfLa)
//
// Reference: Xiph "Encapsulation of FLAC in ISO Base Media File Format"
// §3.3.2.
//
// `dfLa` is a full box. Its body carries one or more FLAC metadata
// blocks, each prefixed by a 4-byte header (1-bit last-block flag +
// 7-bit block type + 24-bit big-endian length). The STREAMINFO block
// (block_type 0) is mandatory and must appear first.

import Foundation

/// FLAC specific box (`dfLa`) — full box.
public struct FLACSpecificBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "dfLa"

    /// One FLAC metadata block.
    public struct FLACMetadataBlock: Sendable, Equatable, Hashable {
        /// `true` if this block is the last in the metadata block list.
        public let isLast: Bool
        public let blockType: FLACMetadataBlockType
        /// Block payload. For STREAMINFO the typed view is exposed via
        /// the parent box's ``FLACSpecificBox/streamInfo`` accessor.
        public let blockData: Data

        public init(isLast: Bool, blockType: FLACMetadataBlockType, blockData: Data) {
            precondition(
                blockData.count <= 0x00FF_FFFF,
                "FLAC metadata block length must fit in 24 bits"
            )
            self.isLast = isLast
            self.blockType = blockType
            self.blockData = blockData
        }
    }

    public let version: UInt8
    public let flags: UInt32
    public let metadataBlocks: [FLACMetadataBlock]

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        metadataBlocks: [FLACMetadataBlock]
    ) {
        precondition(
            metadataBlocks.first?.blockType == .streamInfo,
            "FLACSpecificBox: first metadata block must be STREAMINFO"
        )
        self.version = version
        self.flags = flags
        self.metadataBlocks = metadataBlocks
    }

    /// Typed view of the mandatory STREAMINFO block.
    public var streamInfo: FLACStreamInfo? {
        guard let first = metadataBlocks.first,
            first.blockType == .streamInfo
        else { return nil }
        return try? FLACStreamInfo.parse(blockData: first.blockData)
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> FLACSpecificBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()

        let bodyByteCount = Int(header.size) - header.headerSize - 4
        let bodyBytes = try reader.readData(count: bodyByteCount)
        var body = BinaryReader(bodyBytes)

        var blocks: [FLACMetadataBlock] = []
        while body.remaining > 0 {
            guard body.remaining >= 4 else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "FLAC metadata header truncated"
                )
            }
            let headerByte = try body.readUInt8()
            let isLast = (headerByte & 0x80) != 0
            let blockTypeRaw = headerByte & 0x7F
            guard let blockType = FLACMetadataBlockType(rawValue: blockTypeRaw) else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "Unknown FLAC metadata block type \(blockTypeRaw)"
                )
            }
            let length = Int(try body.readUInt24())
            guard body.remaining >= length else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "FLAC metadata block declares length \(length) exceeding remaining bytes"
                )
            }
            let blockData = try body.readData(count: length)
            blocks.append(
                FLACMetadataBlock(
                    isLast: isLast,
                    blockType: blockType,
                    blockData: blockData
                )
            )
            if isLast { break }
        }

        guard let first = blocks.first, first.blockType == .streamInfo else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "FLACSpecificBox: first metadata block must be STREAMINFO"
            )
        }

        return FLACSpecificBox(
            version: version,
            flags: flags,
            metadataBlocks: blocks
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            for block in metadataBlocks {
                var headerByte: UInt8 = block.blockType.rawValue & 0x7F
                if block.isLast { headerByte |= 0x80 }
                body.writeUInt8(headerByte)
                body.writeUInt24(UInt32(block.blockData.count) & 0x00FF_FFFF)
                body.writeData(block.blockData)
            }
        }
    }
}
