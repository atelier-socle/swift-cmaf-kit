// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DataInformationBox (dinf)
//
// Reference: ISO/IEC 14496-12 §8.7.1 (data information box).
//
// Container for the data reference box (`dref`), which lists the sources
// of the media data referenced by the track. Typed children are
// implemented in a later session.

import Foundation

/// Per-track data-information container.
///
/// Carries a single `dref` child in well-formed files. The typed `dref`
/// arrives in a later session; until then, the child round-trips via
/// ``UnknownBox``.
public struct DataInformationBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "dinf"

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
    ) async throws -> DataInformationBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return DataInformationBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
