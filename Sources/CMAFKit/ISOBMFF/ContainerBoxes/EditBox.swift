// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EditBox (edts)
//
// Reference: ISO/IEC 14496-12 §8.6.5 (edit box).
//
// Container for the edit list (`elst`), describing track edits
// (presentation gaps and timeline segments).

import Foundation

/// Per-track edit-list container.
///
/// Carries a single `elst` child in well-formed files.
public struct EditBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "edts"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    /// The edit list child, if present.
    public var editList: EditListBox? {
        findChild(EditListBox.self)
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
