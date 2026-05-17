// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FreeSpaceBox (free, skip)
//
// Reference: ISO/IEC 14496-12 §8.1.2 (free space box).
//
// Padding box. The content is unspecified and ignored by readers. The
// box exists to reserve space for future edits without rewriting the
// file. `free` and `skip` are equivalent; CMAFKit preserves whichever
// FourCC was on the wire.

import Foundation

/// Free-space (padding) box. Used for layout padding; content is unspecified.
///
/// Per ISO/IEC 14496-12 §8.1.2, two FourCCs are equivalent: `free` and
/// `skip`. CMAFKit preserves the on-wire FourCC via ``onWireType``.
public struct FreeSpaceBox: ISOBox, Sendable, Equatable {
    public static let boxType: FourCC = "free"

    /// Either `"free"` or `"skip"`. Preserved across round-trip.
    public let onWireType: FourCC
    /// Padding payload. Content is unspecified by the standard.
    public let payload: Data

    public init(onWireType: FourCC, payload: Data) {
        precondition(
            onWireType == "free" || onWireType == "skip",
            "FreeSpaceBox accepts only 'free' or 'skip' FourCC, got '\(onWireType)'"
        )
        self.onWireType = onWireType
        self.payload = payload
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> FreeSpaceBox {
        let payload = reader.readToEnd()
        return FreeSpaceBox(onWireType: header.type, payload: payload)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: onWireType, body: payload)
    }
}
