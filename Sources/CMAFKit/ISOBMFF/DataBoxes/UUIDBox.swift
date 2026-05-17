// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - UUIDBox (uuid)
//
// Reference: ISO/IEC 14496-12 §4.2 (extended user type).
//
// A box whose FourCC is "uuid" and which carries a 16-byte extended
// user type (UUID) immediately after the standard header, then a
// vendor-defined payload. Common uses include legacy DRM (Microsoft
// PlayReady, older Apple FairPlay).

import Foundation

/// User-defined extended-type box.
///
/// The on-wire FourCC is always `"uuid"`. A 16-byte ``extendedType``
/// (UUID) immediately follows the standard header, then the
/// vendor-defined ``payload``. CMAFKit preserves these round-trip
/// without interpreting the payload.
public struct UUIDBox: ISOBox, Sendable, Equatable {
    public static let boxType: FourCC = "uuid"

    /// The 16-byte extended user type.
    public let extendedType: UUID
    /// Vendor-defined payload. Treated as opaque.
    public let payload: Data

    public init(extendedType: UUID, payload: Data) {
        self.extendedType = extendedType
        self.payload = payload
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> UUIDBox {
        // The reader is positioned past the standard 8-byte header and the
        // 16-byte uuid; the extended type is already on `header.userType`.
        guard let extendedType = header.userType else {
            // Defensive: ISOBoxReader.parseBoxHeader should always set
            // header.userType for "uuid" boxes.
            throw ISOBoxError.unexpectedType(expected: "uuid", found: header.type)
        }
        let payload = reader.readToEnd()
        return UUIDBox(extendedType: extendedType, payload: payload)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeUUIDBox(extendedType: extendedType, body: payload)
    }
}
