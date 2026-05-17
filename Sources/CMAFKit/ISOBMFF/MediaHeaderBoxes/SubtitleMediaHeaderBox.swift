// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SubtitleMediaHeaderBox (sthd)
//
// Reference: ISO/IEC 14496-12 §12.6 (subtitle media header).
//
// Empty media header for subtitle / closed-caption tracks. Body is empty.

import Foundation

/// Subtitle media header.
///
/// Per ISO/IEC 14496-12 §12.6, this box carries only the full-box version
/// and flags; the body is empty. Subtitle and closed-caption tracks
/// reference it from their `minf`.
public struct SubtitleMediaHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "sthd"

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
    ) async throws -> SubtitleMediaHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        return SubtitleMediaHeaderBox(version: version, flags: flags)
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
