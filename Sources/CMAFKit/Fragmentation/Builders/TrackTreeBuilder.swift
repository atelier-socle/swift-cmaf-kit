// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackTreeBuilder
//
// Reference: ISO/IEC 14496-12 §8.3 (TrackBox), §8.4 (MediaBox /
// MediaHeaderBox / HandlerReferenceBox / MediaInformationBox),
// §8.6 (EditBox / EditListBox), §8.7 (DataInformationBox /
// DataReferenceBox), §8.5 (SampleTableBox).
//
// Composes the entire `trak` subtree from a ``CMAFTrackConfiguration``
// in its CMAF-fragmented form: `tkhd`, optional `edts/elst`, then
// `mdia` carrying the kind-specific media-header box, the handler,
// and a `minf` whose sample table is empty (CMAF init segments do
// not carry sample tables — those move to per-fragment `moof`/`traf`).

import Foundation

/// Internal helper composing one `trak` subtree.
internal enum TrackTreeBuilder {

    /// Compose the `trak` for one configuration.
    ///
    /// - Parameters:
    ///   - configuration: the track configuration.
    ///   - referenceTimestamp: the writer's reference timestamp used
    ///     for `creation_time` and `modification_time` (seconds since
    ///     1904-01-01 00:00:00 UTC per ISO/IEC 14496-12 §8.2.2).
    ///   - movieTimescale: the parent movie's timescale, needed by
    ///     `tkhd.duration` (which is in movie timescale units).
    static func makeTrackBox(
        configuration: CMAFTrackConfiguration,
        referenceTimestamp: UInt64,
        movieTimescale: UInt32
    ) throws -> TrackBox {
        let tkhd = makeTrackHeader(
            configuration: configuration,
            referenceTimestamp: referenceTimestamp
        )
        let mdia = try makeMediaBox(
            configuration: configuration,
            referenceTimestamp: referenceTimestamp
        )

        var children: [any ISOBox] = [tkhd]
        if let editList = resolveEditList(for: configuration, movieTimescale: movieTimescale) {
            let edtsHeader = ISOBoxHeader(type: "edts", size: 0, headerSize: 8)
            let edts = EditBox(header: edtsHeader, children: [editList])
            children.append(edts)
        }
        children.append(mdia)

        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        return TrackBox(header: trakHeader, children: children)
    }

    // MARK: - Sub-builders

    private static func makeTrackHeader(
        configuration: CMAFTrackConfiguration,
        referenceTimestamp: UInt64
    ) -> TrackHeaderBox {
        let width: Double
        let height: Double
        if let video = configuration.videoFields {
            width = Double(video.width)
            height = Double(video.height)
        } else {
            width = 0.0
            height = 0.0
        }
        let volume: Double = (configuration.kind == .audio) ? 1.0 : 0.0
        return TrackHeaderBox(
            version: 1,
            creationTime: referenceTimestamp,
            modificationTime: referenceTimestamp,
            trackID: configuration.trackID,
            duration: 0,
            volume: volume,
            width: width,
            height: height
        )
    }

    private static func makeMediaBox(
        configuration: CMAFTrackConfiguration,
        referenceTimestamp: UInt64
    ) throws -> MediaBox {
        let mdhd = MediaHeaderBox(
            version: 1,
            creationTime: referenceTimestamp,
            modificationTime: referenceTimestamp,
            timescale: configuration.timescale,
            duration: 0,
            language: configuration.language
        )
        let hdlr = makeHandler(for: configuration)
        let minf = try makeMediaInformationBox(configuration: configuration)
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        return MediaBox(header: mdiaHeader, children: [mdhd, hdlr, minf])
    }

    private static func makeHandler(
        for configuration: CMAFTrackConfiguration
    ) -> HandlerReferenceBox {
        let name: String
        switch configuration.kind {
        case .video: name = "VideoHandler"
        case .audio: name = "SoundHandler"
        case .subtitle: name = "SubtitleHandler"
        case .metadata: name = "MetadataHandler"
        }
        let handlerType: FourCC
        if configuration.kind == .metadata, let meta = configuration.metadataFields {
            handlerType = meta.handlerType
        } else {
            handlerType = configuration.kind.handlerType
        }
        return HandlerReferenceBox(handlerType: handlerType, name: name)
    }

    private static func makeMediaInformationBox(
        configuration: CMAFTrackConfiguration
    ) throws -> MediaInformationBox {
        let kindHeader: any ISOBox
        switch configuration.kind {
        case .video: kindHeader = VideoMediaHeaderBox()
        case .audio: kindHeader = SoundMediaHeaderBox()
        case .subtitle: kindHeader = SubtitleMediaHeaderBox()
        case .metadata: kindHeader = NullMediaHeaderBox()
        }

        let dinf = makeDataInformationBox()
        let stbl = try SampleTableBuilder.makeInitSegmentSampleTable(
            configuration: configuration
        )

        let minfHeader = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        return MediaInformationBox(
            header: minfHeader,
            children: [kindHeader, dinf, stbl]
        )
    }

    private static func makeDataInformationBox() -> DataInformationBox {
        let dataEntry = DataEntryURLBox(selfContained: true, location: "")
        let dref = DataReferenceBox(entries: [dataEntry])
        let dinfHeader = ISOBoxHeader(type: "dinf", size: 0, headerSize: 8)
        return DataInformationBox(header: dinfHeader, children: [dref])
    }

    // MARK: - Edit list resolution

    private static func resolveEditList(
        for configuration: CMAFTrackConfiguration,
        movieTimescale: UInt32
    ) -> EditListBox? {
        if let explicit = configuration.editList {
            return explicit
        }
        if configuration.kind == .audio,
            let priming = configuration.audioFields?.priming,
            priming.preSkip > 0
        {
            // Auto-emit an edit list whose mediaTime equals preSkip so
            // playback starts after the codec's pre-skip samples.
            let entry = EditListEntry(
                segmentDuration: 0,
                mediaTime: Int64(priming.preSkip),
                mediaRateInteger: 1,
                mediaRateFraction: 0
            )
            let table = EditListTable(entries: [entry], version: 1)
            return EditListBox(version: 1, table: table)
        }
        return nil
    }
}
