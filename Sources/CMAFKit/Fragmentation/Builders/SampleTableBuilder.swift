// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleTableBuilder
//
// Reference: ISO/IEC 14496-12 §8.5 (SampleTableBox and children).
// Reference: ISO/IEC 23000-19 §7.2 (CMAF Header init segments carry
//            empty sample tables — timing lives in per-fragment
//            `tfdt`/`trun`).
//
// Composes the `stbl` subtree for an init segment. CMAF (ISO/IEC
// 23000-19 §7.2) requires the sample tables to be empty — the actual
// timing and size data lives in `moof`/`traf` per fragment. The init
// segment carries:
//   - `stsd` with one sample entry
//   - `stts` with zero entries
//   - `stsc` with zero entries
//   - `stsz` with sample_count = 0
//   - `stco` with zero entries

import Foundation

/// Internal helper composing the `stbl` for an init segment.
internal enum SampleTableBuilder {

    /// Compose the init-segment-only sample table for a track.
    static func makeInitSegmentSampleTable(
        configuration: CMAFTrackConfiguration
    ) throws -> SampleTableBox {
        let sampleEntry: any SampleEntry
        switch configuration.kind {
        case .video:
            sampleEntry = try requireSampleEntry(
                SampleEntryComposer.makeVideoSampleEntry(configuration: configuration)
            )
        case .audio:
            sampleEntry = try requireSampleEntry(
                SampleEntryComposer.makeAudioSampleEntry(configuration: configuration)
            )
        case .subtitle:
            sampleEntry = try requireSampleEntry(
                SubtitleMetadataSampleEntryComposer.makeSubtitleSampleEntry(
                    configuration: configuration
                )
            )
        case .metadata:
            sampleEntry = try requireSampleEntry(
                SubtitleMetadataSampleEntryComposer.makeMetadataSampleEntry(
                    configuration: configuration
                )
            )
        }

        let stsd = SampleDescriptionBox(entries: [sampleEntry])
        let stts = TimeToSampleBox(table: TimeToSampleTable(entries: []))
        let stsc = SampleToChunkBox(table: SampleToChunkTable(entries: []))
        let stsz = SampleSizeBox(table: SampleSizeTable(sizes: []))
        let stco = ChunkOffsetBox(table: ChunkOffsetTable(offsets: []))

        let stblHeader = ISOBoxHeader(type: "stbl", size: 0, headerSize: 8)
        return SampleTableBox(
            header: stblHeader,
            children: [stsd, stts, stsc, stsz, stco]
        )
    }

    /// Convert an `any ISOBox` returned by a composer into an
    /// `any SampleEntry`, surfacing a clean error if the cast fails.
    private static func requireSampleEntry(_ box: any ISOBox) throws -> any SampleEntry {
        guard let entry = box as? any SampleEntry else {
            throw CMAFWriterError.configurationInvalid(
                reason: "composed sample-entry does not conform to SampleEntry"
            )
        }
        return entry
    }
}
