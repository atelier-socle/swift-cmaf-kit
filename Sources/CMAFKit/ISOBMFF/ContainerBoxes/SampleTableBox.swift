// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleTableBox (stbl)
//
// Reference: ISO/IEC 14496-12 §8.5.1 (sample table box).
//
// Container for the per-sample metadata tables (decoding times,
// composition offsets, sample sizes, chunk offsets, sync samples,
// dependency information, …).

import Foundation

/// Per-track sample-table container.
///
/// Children include `stsd`, `stts`, `ctts`, `stsc`, `stsz`/`stz2`,
/// `stco`/`co64`, `stss`, `sdtp`, `padb`, and others. Typed accessors are
/// provided for every child shipped with CMAFKit; unrecognised children
/// round-trip via ``UnknownBox`` so the container preserves byte-perfect
/// fidelity.
public struct SampleTableBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "stbl"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    /// Sample description (`stsd`), if present.
    public var sampleDescription: SampleDescriptionBox? {
        findChild(SampleDescriptionBox.self)
    }

    /// Time-to-sample (`stts`), if present.
    public var timeToSample: TimeToSampleBox? {
        findChild(TimeToSampleBox.self)
    }

    /// Composition-time-to-sample (`ctts`), if present.
    public var compositionOffset: CompositionOffsetBox? {
        findChild(CompositionOffsetBox.self)
    }

    /// Sample-to-chunk (`stsc`), if present.
    public var sampleToChunk: SampleToChunkBox? {
        findChild(SampleToChunkBox.self)
    }

    /// Sample size (`stsz`), if present.
    public var sampleSize: SampleSizeBox? {
        findChild(SampleSizeBox.self)
    }

    /// Compact sample size (`stz2`), if present.
    public var compactSampleSize: CompactSampleSizeBox? {
        findChild(CompactSampleSizeBox.self)
    }

    /// Chunk offset (`stco`, 32-bit), if present.
    public var chunkOffset: ChunkOffsetBox? {
        findChild(ChunkOffsetBox.self)
    }

    /// Chunk large offset (`co64`, 64-bit), if present.
    public var chunkLargeOffset: ChunkLargeOffsetBox? {
        findChild(ChunkLargeOffsetBox.self)
    }

    /// Sync sample (`stss`), if present.
    public var syncSample: SyncSampleBox? {
        findChild(SyncSampleBox.self)
    }

    /// Sample dependency type (`sdtp`), if present.
    public var sampleDependencyType: SampleDependencyTypeBox? {
        findChild(SampleDependencyTypeBox.self)
    }

    /// Padding bits (`padb`), if present.
    public var paddingBits: PaddingBitsBox? {
        findChild(PaddingBitsBox.self)
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
