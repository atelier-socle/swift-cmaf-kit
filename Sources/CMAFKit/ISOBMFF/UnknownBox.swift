// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - UnknownBox
//
// Reference: ISO/IEC 14496-12 §4.2 (object structured representation).
//
// Fallback box type for FourCC values not registered with `BoxRegistry`.
// Preserves the raw payload bytes so that a parse-then-encode round-trip is
// byte-perfect even when CMAFKit does not have a typed representation for
// the box. This is also what makes container types tolerate unknown
// children without losing data.

import Foundation

/// Fallback representation for any box whose FourCC is not registered with
/// the box registry.
///
/// `UnknownBox` preserves the raw payload (everything after the resolved
/// header) so the round-trip `parse(encode(box)) == box` holds for any box
/// the registry does not recognise. Validators may flag the presence of
/// unknown boxes in strict mode.
public struct UnknownBox: ISOBox, Sendable, Equatable {
    /// Sentinel value. The instance's actual on-wire type is carried in
    /// ``actualType``.
    public static let boxType: FourCC = FourCC(0)

    /// The on-wire FourCC of this box.
    public let actualType: FourCC

    /// The full header as resolved by ``ISOBoxReader`` (size, header size,
    /// optional UUID extended type).
    public let header: ISOBoxHeader

    /// Raw payload — everything after the resolved header.
    public let payload: Data

    public init(actualType: FourCC, header: ISOBoxHeader, payload: Data) {
        self.actualType = actualType
        self.header = header
        self.payload = payload
    }

    public func encode(to writer: inout BinaryWriter) {
        // Re-emit the box exactly as it was read: same type, same payload.
        // Large-size and uuid headers are handled by the dedicated writer
        // helpers.
        if let userType = header.userType {
            writer.writeUUIDBox(extendedType: userType, body: payload)
        } else {
            writer.writeBox(type: actualType, body: payload)
        }
    }
}
