// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - NullMediaHeaderBox (nmhd)
//
// Reference: ISO/IEC 14496-12 §8.4.5.2 (null media header).
//
// Empty media header used for tracks without a specialised header
// (metadata, hint, generic). Body is empty.

import Foundation

/// Null media header.
///
/// Per ISO/IEC 14496-12 §8.4.5.2, this box carries only the full-box
/// version and flags; the body is empty.
public struct NullMediaHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "nmhd"

    public let version: UInt8
    public let flags: UInt32

    public init(version: UInt8 = 0, flags: UInt32 = 0) {
        self.version = version
        self.flags = flags
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> NullMediaHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        return NullMediaHeaderBox(version: version, flags: flags)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { _ in
            // Empty body.
        }
    }
}
