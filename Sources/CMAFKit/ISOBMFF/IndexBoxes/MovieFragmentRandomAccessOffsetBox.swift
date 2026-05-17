// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MovieFragmentRandomAccessOffsetBox (mfro)
//
// Reference: ISO/IEC 14496-12 §8.8.11 (movie fragment random access offset box).
//
// Final box of `mfra`. Carries the size in bytes of the enclosing `mfra`,
// allowing readers to locate `mfra` from a fixed offset at the end of the
// file.

import Foundation

/// Movie-fragment random-access offset.
public struct MovieFragmentRandomAccessOffsetBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "mfro"

    public let version: UInt8
    public let flags: UInt32
    /// Total size in bytes of the enclosing `mfra` box, including its
    /// header.
    public let mfraSize: UInt32

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        mfraSize: UInt32
    ) {
        self.version = version
        self.flags = flags
        self.mfraSize = mfraSize
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MovieFragmentRandomAccessOffsetBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let mfraSize = try reader.readUInt32()
        return MovieFragmentRandomAccessOffsetBox(
            version: version,
            flags: flags,
            mfraSize: mfraSize
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(mfraSize)
        }
    }
}
