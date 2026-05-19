// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BoxRegistry built-ins
//
// Registers every box type CMAFKit ships, grouped by their structural role
// (simple leaf, container, protection-scheme, full-box header). New box
// types are added to the corresponding group method as they land in the
// library.

import Foundation

extension BoxRegistry {

    /// Registers every built-in box parser shipped with CMAFKit.
    ///
    /// Called from ``registerBuiltins()``. Each registration maps a FourCC
    /// to the corresponding box type's static
    /// `parse(reader:header:registry:)` factory. The registrations are
    /// split across category methods so the file stays scannable.
    internal func registerBuiltinBoxes() async {
        registerFoundationalBuiltinBoxes()
        registerSampleTableBuiltinBoxes()
        registerFragmentationBuiltinBoxes()
        registerColorBuiltinBoxes()
        registerVideoSampleEntryBuiltinBoxes()
        registerAudioSampleEntryBuiltinBoxes()
        registerEncryptionBuiltinBoxes()
    }

    // MARK: Foundational built-ins
    //
    // File-type and segment-type identifiers, free-space placeholders,
    // raw media data, opaque uuid extensions, the top-level container
    // chain, the protection-scheme info group, and the header full
    // boxes (`mvhd`, `tkhd`, `mdhd`, `hdlr`).

    /// Registers the foundational box parsers: leaf simple boxes,
    /// container boxes, protection-scheme info family, and header full
    /// boxes.
    private func registerFoundationalBuiltinBoxes() {
        registerLeafSimpleBoxes()
        registerContainerBoxes()
        registerHeaderFullBoxes()
    }

    // MARK: Leaf simple boxes

    /// Registers `ftyp`, `styp`, `free`, `skip`, `mdat`, `uuid`.
    private func registerLeafSimpleBoxes() {
        register(FileTypeBox.self) { reader, header, registry in
            try await FileTypeBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SegmentTypeBox.self) { reader, header, registry in
            try await SegmentTypeBox.parse(reader: &reader, header: header, registry: registry)
        }
        // `free` and `skip` map to the same parser; the on-wire FourCC is
        // preserved on the resulting instance.
        let freeSkipParser: Parser = { reader, header, registry in
            try await FreeSpaceBox.parse(reader: &reader, header: header, registry: registry)
        }
        register("free", parser: freeSkipParser)
        register("skip", parser: freeSkipParser)
        register(MediaDataBox.self) { reader, header, registry in
            try await MediaDataBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(UUIDBox.self) { reader, header, registry in
            try await UUIDBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    // MARK: Container boxes

    /// Registers `moov`, `trak`, `mdia`, `minf`, `dinf`, `stbl`, `edts`, `udta`.
    private func registerContainerBoxes() {
        register(MovieBox.self) { reader, header, registry in
            try await MovieBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackBox.self) { reader, header, registry in
            try await TrackBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MediaBox.self) { reader, header, registry in
            try await MediaBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MediaInformationBox.self) { reader, header, registry in
            try await MediaInformationBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(DataInformationBox.self) { reader, header, registry in
            try await DataInformationBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SampleTableBox.self) { reader, header, registry in
            try await SampleTableBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(EditBox.self) { reader, header, registry in
            try await EditBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(UserDataBox.self) { reader, header, registry in
            try await UserDataBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    // MARK: Header full boxes

    /// Registers `mvhd`, `tkhd`, `mdhd`, `hdlr`.
    private func registerHeaderFullBoxes() {
        register(MovieHeaderBox.self) { reader, header, registry in
            try await MovieHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackHeaderBox.self) { reader, header, registry in
            try await TrackHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MediaHeaderBox.self) { reader, header, registry in
            try await MediaHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(HandlerReferenceBox.self) { reader, header, registry in
            try await HandlerReferenceBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    // MARK: Sample-table built-ins
    //
    // The contents of `stbl` (`stsd` plus the lazy-table boxes), the
    // data reference family (`dref` / `url` / `urn`), and the four
    // codec-specific media headers (`vmhd` / `smhd` / `nmhd` / `sthd`).

    /// Registers the sample-table family, data reference family, and
    /// codec-specific media headers.
    private func registerSampleTableBuiltinBoxes() {
        registerSampleTableLeafBoxes()
        registerDataReferenceBoxes()
        registerMediaHeaderBoxes()
    }

    /// Registers the children of `stbl`: `stsd`, `stts`, `ctts`, `stsc`,
    /// `stsz`, `stz2`, `stco`, `co64`, `stss`, `sdtp`, `padb`.
    private func registerSampleTableLeafBoxes() {
        register(SampleDescriptionBox.self) { reader, header, registry in
            try await SampleDescriptionBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TimeToSampleBox.self) { reader, header, registry in
            try await TimeToSampleBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(CompositionOffsetBox.self) { reader, header, registry in
            try await CompositionOffsetBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SampleToChunkBox.self) { reader, header, registry in
            try await SampleToChunkBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SampleSizeBox.self) { reader, header, registry in
            try await SampleSizeBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(CompactSampleSizeBox.self) { reader, header, registry in
            try await CompactSampleSizeBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(ChunkOffsetBox.self) { reader, header, registry in
            try await ChunkOffsetBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(ChunkLargeOffsetBox.self) { reader, header, registry in
            try await ChunkLargeOffsetBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SyncSampleBox.self) { reader, header, registry in
            try await SyncSampleBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SampleDependencyTypeBox.self) { reader, header, registry in
            try await SampleDependencyTypeBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(PaddingBitsBox.self) { reader, header, registry in
            try await PaddingBitsBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    /// Registers `dref`, `url `, `urn ` (trailing space in the FourCCs).
    private func registerDataReferenceBoxes() {
        register(DataReferenceBox.self) { reader, header, registry in
            try await DataReferenceBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(DataEntryURLBox.self) { reader, header, registry in
            try await DataEntryURLBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(DataEntryURNBox.self) { reader, header, registry in
            try await DataEntryURNBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    /// Registers `vmhd`, `smhd`, `nmhd`, `sthd`.
    private func registerMediaHeaderBoxes() {
        register(VideoMediaHeaderBox.self) { reader, header, registry in
            try await VideoMediaHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SoundMediaHeaderBox.self) { reader, header, registry in
            try await SoundMediaHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(NullMediaHeaderBox.self) { reader, header, registry in
            try await NullMediaHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SubtitleMediaHeaderBox.self) { reader, header, registry in
            try await SubtitleMediaHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    // MARK: Fragmentation built-ins
    //
    // The `mvex` family (movie-extends declarations), the `moof` family
    // (per-fragment headers and runs), the segment-index family
    // (`sidx`, `ssix`, `pdin`), the `mfra` family (random-access index),
    // sample-auxiliary and sample-group boxes, and the edit list.

    /// Registers the fragmentation, indexing, random-access, sample-group,
    /// sample-auxiliary, and edit-list parsers.
    private func registerFragmentationBuiltinBoxes() {
        registerMovieExtendsBoxes()
        registerMovieFragmentBoxes()
        registerSegmentIndexBoxes()
        registerMovieFragmentRandomAccessBoxes()
        registerSampleGroupBoxes()
        registerEditListBoxes()
    }

    /// Registers `mvex`, `mehd`, `trex`.
    private func registerMovieExtendsBoxes() {
        register(MovieExtendsBox.self) { reader, header, registry in
            try await MovieExtendsBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MovieExtendsHeaderBox.self) { reader, header, registry in
            try await MovieExtendsHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackExtendsBox.self) { reader, header, registry in
            try await TrackExtendsBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    /// Registers `moof`, `mfhd`, `traf`, `tfhd`, `tfdt`, `trun`.
    private func registerMovieFragmentBoxes() {
        register(MovieFragmentBox.self) { reader, header, registry in
            try await MovieFragmentBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MovieFragmentHeaderBox.self) { reader, header, registry in
            try await MovieFragmentHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackFragmentBox.self) { reader, header, registry in
            try await TrackFragmentBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackFragmentHeaderBox.self) { reader, header, registry in
            try await TrackFragmentHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackFragmentDecodeTimeBox.self) { reader, header, registry in
            try await TrackFragmentDecodeTimeBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackRunBox.self) { reader, header, registry in
            try await TrackRunBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    /// Registers `sidx`, `ssix`, `pdin`.
    private func registerSegmentIndexBoxes() {
        register(SegmentIndexBox.self) { reader, header, registry in
            try await SegmentIndexBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SubsegmentIndexBox.self) { reader, header, registry in
            try await SubsegmentIndexBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(ProgressiveDownloadInformationBox.self) { reader, header, registry in
            try await ProgressiveDownloadInformationBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    /// Registers `mfra`, `tfra`, `mfro`.
    private func registerMovieFragmentRandomAccessBoxes() {
        register(MovieFragmentRandomAccessBox.self) { reader, header, registry in
            try await MovieFragmentRandomAccessBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackFragmentRandomAccessBox.self) { reader, header, registry in
            try await TrackFragmentRandomAccessBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MovieFragmentRandomAccessOffsetBox.self) { reader, header, registry in
            try await MovieFragmentRandomAccessOffsetBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    /// Registers `sbgp`, `sgpd`, `saiz`, `saio`.
    private func registerSampleGroupBoxes() {
        register(SampleToGroupBox.self) { reader, header, registry in
            try await SampleToGroupBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SampleGroupDescriptionBox.self) { reader, header, registry in
            try await SampleGroupDescriptionBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SampleAuxiliaryInformationSizesBox.self) { reader, header, registry in
            try await SampleAuxiliaryInformationSizesBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SampleAuxiliaryInformationOffsetsBox.self) { reader, header, registry in
            try await SampleAuxiliaryInformationOffsetsBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    /// Registers `elst`.
    private func registerEditListBoxes() {
        register(EditListBox.self) { reader, header, registry in
            try await EditListBox.parse(reader: &reader, header: header, registry: registry)
        }
    }
}
