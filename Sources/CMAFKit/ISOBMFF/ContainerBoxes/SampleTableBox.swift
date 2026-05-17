// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleTableBox (stbl)
//
// Reference: ISO/IEC 14496-12 §8.5.1 (sample table box).
//
// Container for the per-sample metadata tables (decoding times,
// composition offsets, sample sizes, chunk offsets, sync samples,
// dependency information, …). Typed children are implemented in a
// later session.

import Foundation

/// Per-track sample-table container.
///
/// Children include `stsd`, `stts`, `ctts`, `stsc`, `stsz`/`stz2`,
/// `stco`/`co64`, `stss`, `sdtp`, and others. Typed accessors for each
/// arrive in a later session; until then, every child round-trips via
/// ``UnknownBox``.
public struct SampleTableBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "stbl"

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
    ) async throws -> SampleTableBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return SampleTableBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
