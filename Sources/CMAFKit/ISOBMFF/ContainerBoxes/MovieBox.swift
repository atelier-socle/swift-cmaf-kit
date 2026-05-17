// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MovieBox (moov)
//
// Reference: ISO/IEC 14496-12 §8.2.1 (movie box).
//
// Top-level container for the file-level metadata: track definitions
// (`trak`), the movie header (`mvhd`), the movie-extends declarations
// for fragmented presentations (`mvex`), and user data (`udta`).

import Foundation

/// Top-level movie container.
///
/// Holds the movie header and one or more track containers. In fragmented
/// presentations, also contains a movie-extends box (`mvex`, typed in a
/// later session) declaring the track-fragment defaults.
public struct MovieBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "moov"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    /// Convenience accessor for the movie header (always present in a
    /// well-formed `moov`).
    public var movieHeader: MovieHeaderBox? {
        findChild(MovieHeaderBox.self)
    }

    /// All track containers, in the order they appear.
    public var tracks: [TrackBox] {
        findChildren(TrackBox.self)
    }

    /// The user-data container, if present.
    public var userData: UserDataBox? {
        findChild(UserDataBox.self)
    }

    /// Movie-extends sibling, if present. Returned untyped because the
    /// typed `MovieExtendsBox` lands in a later session.
    public var movieExtends: (any ISOBox)? {
        children.first { wireType(of: $0) == "mvex" }
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MovieBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return MovieBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}

/// Internal helper: the on-wire FourCC of any `ISOBox`, accounting for
/// the `UnknownBox` sentinel.
internal func wireType(of box: any ISOBox) -> FourCC {
    if let unknown = box as? UnknownBox {
        return unknown.actualType
    }
    return Swift.type(of: box).boxType
}
