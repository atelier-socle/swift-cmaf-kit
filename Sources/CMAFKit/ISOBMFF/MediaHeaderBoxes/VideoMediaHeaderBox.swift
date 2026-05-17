// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - VideoMediaHeaderBox (vmhd)
//
// Reference: ISO/IEC 14496-12 §8.4.5.2 (video media header).
//
// Required full box for video tracks. The standard fixes flags at
// `0x000001` (per its requirement that the box be marked "no compositor").

import Foundation

/// Video media header.
///
/// Per ISO/IEC 14496-12 §8.4.5.2, every video track contains this box as a
/// child of its `minf`. The standard fixes ``flags`` at `0x000001`.
public struct VideoMediaHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "vmhd"

    public let version: UInt8
    public let flags: UInt32
    /// Composition mode. Almost always 0 (copy).
    public let graphicsMode: UInt16
    /// RGB opcolor (3 × UInt16). Almost always `(0, 0, 0)`.
    public let opcolor: (UInt16, UInt16, UInt16)

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0x0000_0001,
        graphicsMode: UInt16 = 0,
        opcolor: (UInt16, UInt16, UInt16) = (0, 0, 0)
    ) {
        self.version = version
        self.flags = flags
        self.graphicsMode = graphicsMode
        self.opcolor = opcolor
    }

    /// Custom `Equatable` because tuples do not synthesise `Equatable`
    /// automatically.
    public static func == (lhs: VideoMediaHeaderBox, rhs: VideoMediaHeaderBox) -> Bool {
        return lhs.version == rhs.version
            && lhs.flags == rhs.flags
            && lhs.graphicsMode == rhs.graphicsMode
            && lhs.opcolor.0 == rhs.opcolor.0
            && lhs.opcolor.1 == rhs.opcolor.1
            && lhs.opcolor.2 == rhs.opcolor.2
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> VideoMediaHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let graphicsMode = try reader.readUInt16()
        let red = try reader.readUInt16()
        let green = try reader.readUInt16()
        let blue = try reader.readUInt16()
        return VideoMediaHeaderBox(
            version: version,
            flags: flags,
            graphicsMode: graphicsMode,
            opcolor: (red, green, blue)
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt16(graphicsMode)
            body.writeUInt16(opcolor.0)
            body.writeUInt16(opcolor.1)
            body.writeUInt16(opcolor.2)
        }
    }
}
