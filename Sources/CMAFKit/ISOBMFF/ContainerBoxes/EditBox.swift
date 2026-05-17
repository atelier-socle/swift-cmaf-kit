// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EditBox (edts)
//
// Reference: ISO/IEC 14496-12 §8.6.5 (edit box).
//
// Container for the edit list (`elst`), describing track edits (gaps,
// segments). The `elst` child is typed in a later session.

import Foundation

/// Per-track edit-list container.
///
/// Carries a single `elst` child in well-formed files. The typed `elst`
/// arrives in a later session; until then, the child round-trips via
/// ``UnknownBox``.
public struct EditBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "edts"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> EditBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return EditBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
