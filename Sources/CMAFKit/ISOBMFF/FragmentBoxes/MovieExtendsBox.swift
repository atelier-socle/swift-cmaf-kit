// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MovieExtendsBox (mvex)
//
// Reference: ISO/IEC 14496-12 §8.8.1 (movie extends box).
//
// Container declaring that the presentation is fragmented. Contains an
// optional `mehd` (presentation duration) and one `trex` per track.

import Foundation

/// Movie extends container.
///
/// The presence of this box inside a `moov` signals a fragmented
/// presentation. The companion `mfra` box (if present) lives at the end
/// of the file and is not a child of `mvex`.
public struct MovieExtendsBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "mvex"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    /// Movie-extends header (`mehd`), if present.
    public var movieExtendsHeader: MovieExtendsHeaderBox? {
        findChild(MovieExtendsHeaderBox.self)
    }

    /// Per-track extends declarations (`trex`), one per track.
    public var trackExtends: [TrackExtendsBox] {
        findChildren(TrackExtendsBox.self)
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MovieExtendsBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return MovieExtendsBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
