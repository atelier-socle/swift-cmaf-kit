// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ISOBox protocol hierarchy
//
// Reference: ISO/IEC 14496-12 §4.2 (object structured representation).
//
// Every box type in CMAFKit conforms to `ISOBox`. Full boxes (those with a
// 1-byte version + 24-bit flags after the standard header) additionally
// conform to `ISOFullBox`. Boxes that contain other boxes additionally
// conform to `ISOContainerBox` and expose `children` plus typed accessors.

import Foundation

/// A typed ISOBMFF box.
///
/// Every concrete box implements ``boxType`` (the FourCC under which it is
/// registered with the box registry) and ``encode(to:)`` (which writes the
/// box's byte layout, including the standard or extended header, to a
/// `BinaryWriter`).
///
/// Conformers are value types (struct or enum) and `Sendable`.
public protocol ISOBox: Sendable {
    /// The FourCC under which this box is registered with ``BoxRegistry``.
    /// For boxes whose on-wire type is dynamic (for example the sentinel
    /// ``UnknownBox``), this returns the canonical sentinel value and the
    /// instance carries its actual type elsewhere.
    static var boxType: FourCC { get }

    /// Encode the box, including its 8-byte (or 16-byte largesize, or
    /// 24-byte uuid) standard header followed by the body, into the writer.
    func encode(to writer: inout BinaryWriter)
}

/// A "full box" per ISO/IEC 14496-12 §4.2 — a box whose first four bytes
/// after the standard header are a 1-byte ``version`` and a 24-bit ``flags``.
public protocol ISOFullBox: ISOBox {
    /// Version field (1 byte).
    var version: UInt8 { get }
    /// Flags field (24 bits — lower three bytes of a 4-byte word).
    var flags: UInt32 { get }
}

/// A box that contains other boxes.
///
/// Conformers expose ``children`` (raw, ordered) for byte-perfect round-trip
/// and the lookup helpers ``findChild(_:)`` / ``findChildren(_:)`` for
/// ergonomic typed access.
public protocol ISOContainerBox: ISOBox {
    /// Children in the order they appeared on the wire.
    ///
    /// Children whose FourCC is not registered with ``BoxRegistry`` are
    /// surfaced as ``UnknownBox`` and preserve their raw payload so the
    /// container round-trips byte-for-byte regardless of CMAFKit's knowledge
    /// of the child's semantics.
    var children: [any ISOBox] { get }
}

extension ISOContainerBox {
    /// The first child whose runtime type matches `type`, or `nil` if none
    /// is present.
    ///
    /// The lookup is a linear scan of ``children`` — acceptable for the
    /// depth of typical ISOBMFF trees (≤ 8 children per container in
    /// practice).
    public func findChild<B: ISOBox>(_ type: B.Type) -> B? {
        for child in children {
            if let typed = child as? B {
                return typed
            }
        }
        return nil
    }

    /// All children whose runtime type matches `type`, in the order they
    /// appeared on the wire.
    public func findChildren<B: ISOBox>(_ type: B.Type) -> [B] {
        children.compactMap { $0 as? B }
    }
}
