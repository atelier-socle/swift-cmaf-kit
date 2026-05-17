// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackFragmentBox (traf)
//
// Reference: ISO/IEC 14496-12 §8.8.6 (track fragment box).
//
// Per-track container inside a `moof`. Contains the track-fragment header
// (`tfhd`), the decode-time base (`tfdt`), one or more sample-run boxes
// (`trun`), and optional sample-auxiliary and sample-group children.

import Foundation

/// Per-track fragment container.
///
/// The typed accessors below cover the structural children produced by
/// fragmented presentations. Sample-auxiliary and sample-group accessors
/// are exposed in a separate extension file alongside their box types.
public struct TrackFragmentBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "traf"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    /// Track-fragment header (`tfhd`).
    public var trackFragmentHeader: TrackFragmentHeaderBox? {
        findChild(TrackFragmentHeaderBox.self)
    }

    /// Track-fragment decode time (`tfdt`), if present.
    public var trackFragmentDecodeTime: TrackFragmentDecodeTimeBox? {
        findChild(TrackFragmentDecodeTimeBox.self)
    }

    /// All sample-run boxes (`trun`), in the order they appear.
    public var trackRuns: [TrackRunBox] {
        findChildren(TrackRunBox.self)
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TrackFragmentBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return TrackFragmentBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
