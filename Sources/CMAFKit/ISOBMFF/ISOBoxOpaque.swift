// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ISOBoxOpaque
//
// Reference: ISO/IEC 14496-12 §4.2 (box).
//
// Byte-preserving wrapper for boxes whose typed parser is intentionally
// deferred to a later checkpoint. Round-trip is byte-perfect: the entire
// box (header + body) is captured verbatim.

import Foundation

/// Opaque box wrapper used as a transitional shim while the typed parser
/// for a particular box subtree lives behind a future scope boundary.
///
/// `ISOBoxOpaque` preserves the entire on-wire box (8-byte or 16-byte
/// largesize header + body) so that an encode round-trip is byte-perfect
/// even when no typed parser is yet wired up for the FourCC.
public struct ISOBoxOpaque: Sendable, Equatable, Hashable {
    /// The FourCC parsed from the box header.
    public let boxType: FourCC
    /// The complete on-wire bytes of the box, including its 8-byte (or
    /// 16-byte largesize) header.
    public let rawBytes: Data

    public init(boxType: FourCC, rawBytes: Data) {
        self.boxType = boxType
        self.rawBytes = rawBytes
    }

    /// Append the verbatim bytes to a writer.
    public func writeRaw(to writer: inout BinaryWriter) {
        writer.writeData(rawBytes)
    }

    /// Parse from a reader positioned at the start of a box. Peeks the
    /// header to learn the size and type, then reads `size` bytes
    /// (header + body) into ``rawBytes``.
    public static func parse(reader: inout BinaryReader) throws -> ISOBoxOpaque {
        var peek = reader
        let size32 = try peek.readUInt32()
        let typeRaw = try peek.readUInt32()
        let type = FourCC(typeRaw)

        let totalSize: Int
        if size32 == 1 {
            let largeSize = try peek.readUInt64()
            totalSize = Int(largeSize)
        } else if size32 == 0 {
            // "Box extends to end of file" — capture all remaining bytes.
            totalSize = 8 + peek.remaining
        } else {
            totalSize = Int(size32)
        }

        guard totalSize >= 8 else {
            throw ISOBoxError.sizeSmallerThanHeader(
                declared: UInt64(totalSize),
                headerSize: 8,
                type: type
            )
        }

        let raw = try reader.readData(count: totalSize)
        return ISOBoxOpaque(boxType: type, rawBytes: raw)
    }
}
