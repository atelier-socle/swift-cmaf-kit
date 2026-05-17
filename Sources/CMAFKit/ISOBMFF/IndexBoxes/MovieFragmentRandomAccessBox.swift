// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MovieFragmentRandomAccessBox (mfra)
//
// Reference: ISO/IEC 14496-12 §8.8.9 (movie fragment random access box).
//
// End-of-file container indexing the random-access points of every
// fragmented track in the file. Contains one `tfra` per track plus an
// `mfro` reporting the size of the `mfra` itself.

import Foundation

/// Movie-fragment random access top-level container.
///
/// Located near the end of a fragmented file (immediately before `mfro`).
/// Optional; streaming presentations (DASH / CMAF) typically rely on
/// `sidx` instead and may omit this box.
public struct MovieFragmentRandomAccessBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "mfra"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    /// All per-track random access tables, one per track.
    public var trackFragmentRandomAccess: [TrackFragmentRandomAccessBox] {
        findChildren(TrackFragmentRandomAccessBox.self)
    }

    /// Random-access offset box (`mfro`), if present.
    public var movieFragmentRandomAccessOffset: MovieFragmentRandomAccessOffsetBox? {
        findChild(MovieFragmentRandomAccessOffsetBox.self)
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MovieFragmentRandomAccessBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return MovieFragmentRandomAccessBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
