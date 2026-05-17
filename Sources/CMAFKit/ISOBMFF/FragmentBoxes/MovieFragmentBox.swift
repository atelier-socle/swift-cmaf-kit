// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MovieFragmentBox (moof)
//
// Reference: ISO/IEC 14496-12 §8.8.4 (movie fragment box).
//
// Top-level container for one fragment. Always paired with one or more
// `mdat` boxes carrying the sample data. Contains a movie-fragment header
// (`mfhd`) and one `traf` per track in the fragment.

import Foundation

/// Movie-fragment top-level container.
public struct MovieFragmentBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "moof"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    /// Movie-fragment header (`mfhd`).
    public var movieFragmentHeader: MovieFragmentHeaderBox? {
        findChild(MovieFragmentHeaderBox.self)
    }

    /// Per-track fragments (`traf`), one per track.
    public var trackFragments: [TrackFragmentBox] {
        findChildren(TrackFragmentBox.self)
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MovieFragmentBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return MovieFragmentBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
