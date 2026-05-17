// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MovieExtendsHeaderBox (mehd)
//
// Reference: ISO/IEC 14496-12 §8.8.2 (movie extends header box).
//
// Optional declaration of the presentation's total duration in the movie
// timescale. When absent, consumers must traverse all fragments to
// determine the total duration.

import Foundation

/// Movie extends header.
///
/// Records the total presentation duration for the fragmented file in the
/// movie's timescale. Version 0 stores duration as `UInt32`; version 1
/// stores it as `UInt64`. Newly-constructed boxes default to version 1 to
/// avoid the 32-bit overflow at high timescales.
public struct MovieExtendsHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "mehd"

    public let version: UInt8
    public let flags: UInt32
    /// Total fragment duration in the movie timescale.
    public let fragmentDuration: UInt64

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        fragmentDuration: UInt64
    ) {
        self.version = version
        self.flags = flags
        self.fragmentDuration = fragmentDuration
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MovieExtendsHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let fragmentDuration: UInt64
        if version == 1 {
            fragmentDuration = try reader.readUInt64()
        } else if version == 0 {
            fragmentDuration = UInt64(try reader.readUInt32())
        } else {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }
        return MovieExtendsHeaderBox(
            version: version,
            flags: flags,
            fragmentDuration: fragmentDuration
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            if version == 1 {
                body.writeUInt64(fragmentDuration)
            } else {
                body.writeUInt32(UInt32(min(fragmentDuration, UInt64(UInt32.max))))
            }
        }
    }
}
