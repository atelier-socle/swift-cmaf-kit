// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackBox (trak)
//
// Reference: ISO/IEC 14496-12 §8.3.1 (track box).
//
// Container for everything related to a single track: its header (`tkhd`),
// its media (`mdia`), and optionally its edit list (`edts`) and references
// to other tracks (`tref`).

import Foundation

/// Per-track container.
public struct TrackBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "trak"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    /// Track header — always present in a well-formed `trak`.
    public var trackHeader: TrackHeaderBox? {
        findChild(TrackHeaderBox.self)
    }

    /// Media container.
    public var media: MediaBox? {
        findChild(MediaBox.self)
    }

    /// Edit list container, if present.
    public var edits: EditBox? {
        findChild(EditBox.self)
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TrackBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return TrackBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
