// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MediaBox (mdia)
//
// Reference: ISO/IEC 14496-12 §8.4.1 (media box).
//
// Container for the per-track media metadata: the media header (`mdhd`),
// the handler reference (`hdlr`) describing the track's media type, and
// the media information (`minf`) with the sample tables and codec
// configurations.

import Foundation

/// Per-track media container.
public struct MediaBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "mdia"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    public var mediaHeader: MediaHeaderBox? {
        findChild(MediaHeaderBox.self)
    }

    public var handlerReference: HandlerReferenceBox? {
        findChild(HandlerReferenceBox.self)
    }

    public var mediaInformation: MediaInformationBox? {
        findChild(MediaInformationBox.self)
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MediaBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return MediaBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
