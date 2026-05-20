// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFTrackResolver (internal)
//
// Reference: ISO/IEC 14496-12 §8.3 (TrackBox), §8.4 (MediaBox),
// §8.5.2 (SampleDescriptionBox).
//
// Inverts the composition path of the writer (Session 10): given a
// parsed `trak` box plus the moov-level `pssh` set, reconstruct a
// ``CMAFTrackConfiguration`` value with the right codec arm, the
// matching codec configuration record, the optional encryption
// parameters, and the surfaced extension boxes (color, mastering
// display, Dolby Vision, pixel aspect ratio, clean aperture, edit
// list).

import Foundation

internal enum CMAFTrackResolver {

    /// Build a ``CMAFTrackConfiguration`` from a parsed `trak`.
    ///
    /// - Parameters:
    ///   - trak: the parsed ``TrackBox``.
    ///   - profile: the CMAF profile to attach (recovered from the
    ///     init-segment's `ftyp`).
    ///   - psshBoxes: the moov-level `pssh` boxes, copied verbatim
    ///     into the track's ``CMAFEncryptionParameters`` if the
    ///     track is encrypted.
    static func resolve(
        trak: TrackBox,
        profile: CMAFProfile,
        psshBoxes: [ProtectionSystemSpecificHeaderBox]
    ) throws -> CMAFTrackConfiguration {
        guard let tkhd = trak.trackHeader else {
            throw CMAFReaderError.missingMandatoryBox(parent: "trak", missing: "tkhd")
        }
        guard let mdia = trak.media else {
            throw CMAFReaderError.missingMandatoryBox(parent: "trak", missing: "mdia")
        }
        guard let mdhd = mdia.mediaHeader else {
            throw CMAFReaderError.missingMandatoryBox(parent: "mdia", missing: "mdhd")
        }
        guard let hdlr = mdia.handlerReference else {
            throw CMAFReaderError.missingMandatoryBox(parent: "mdia", missing: "hdlr")
        }
        guard let minf = mdia.mediaInformation else {
            throw CMAFReaderError.missingMandatoryBox(parent: "mdia", missing: "minf")
        }
        guard let stbl = minf.children.compactMap({ $0 as? SampleTableBox }).first else {
            throw CMAFReaderError.missingMandatoryBox(parent: "minf", missing: "stbl")
        }
        guard let stsd = stbl.children.compactMap({ $0 as? SampleDescriptionBox }).first
        else {
            throw CMAFReaderError.missingMandatoryBox(parent: "stbl", missing: "stsd")
        }
        guard let entry = stsd.entries.first else {
            throw CMAFReaderError.initSegmentInconsistency(
                reason: "stsd contains no sample entry"
            )
        }

        let kind = trackKind(handlerType: hdlr.handlerType)
        let context = TrackResolutionContext(
            trackID: tkhd.trackID,
            profile: profile,
            tkhd: tkhd,
            mdhd: mdhd,
            handlerType: hdlr.handlerType,
            editList: extractEditList(from: trak),
            psshBoxes: psshBoxes
        )

        switch kind {
        case .video: return try resolveVideo(context: context, entry: entry)
        case .audio: return try resolveAudio(context: context, entry: entry)
        case .subtitle: return try resolveSubtitle(context: context, entry: entry)
        case .metadata: return try resolveMetadata(context: context, entry: entry)
        }
    }

    /// Per-track decoded context bundling everything the per-kind
    /// resolvers need. Avoids passing 6+ parameters individually.
    fileprivate struct TrackResolutionContext {
        let trackID: UInt32
        let profile: CMAFProfile
        let tkhd: TrackHeaderBox
        let mdhd: MediaHeaderBox
        let handlerType: FourCC
        let editList: EditListBox?
        let psshBoxes: [ProtectionSystemSpecificHeaderBox]
    }

    // MARK: - Per-kind resolution

    private static func resolveVideo(
        context: TrackResolutionContext,
        entry: any SampleEntry
    ) throws -> CMAFTrackConfiguration {
        let resolved = try VideoSampleEntryResolver.resolve(entry: entry)
        let encryptionParameters = resolved.encryptionParameters(
            psshBoxes: context.psshBoxes
        )
        let video = CMAFTrackConfiguration.VideoFields(
            width: UInt32(context.tkhd.width.rounded()),
            height: UInt32(context.tkhd.height.rounded()),
            codec: resolved.codec,
            codecConfiguration: resolved.codecConfiguration,
            colorInformation: resolved.colorInformation,
            masteringDisplay: resolved.masteringDisplay,
            contentLightLevel: resolved.contentLightLevel,
            dolbyVisionConfiguration: resolved.dolbyVisionConfiguration,
            dolbyVisionELConfiguration: resolved.dolbyVisionELConfiguration,
            pixelAspectRatio: resolved.pixelAspectRatio,
            cleanAperture: resolved.cleanAperture,
            frameRate: CMAFTrackConfiguration.VideoFields.FrameRate(
                numerator: 30,
                denominator: 1
            )
        )
        return CMAFTrackConfiguration(
            trackID: context.trackID,
            kind: .video,
            profile: context.profile,
            timescale: context.mdhd.timescale,
            language: context.mdhd.language,
            videoFields: video,
            editList: context.editList,
            encryptionParameters: encryptionParameters
        )
    }

    private static func resolveAudio(
        context: TrackResolutionContext,
        entry: any SampleEntry
    ) throws -> CMAFTrackConfiguration {
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        let encryptionParameters = resolved.encryptionParameters(
            psshBoxes: context.psshBoxes
        )
        let audio = CMAFTrackConfiguration.AudioFields(
            codec: resolved.codec,
            codecConfiguration: resolved.codecConfiguration,
            channelCount: resolved.channelCount,
            sampleRate: resolved.sampleRate,
            sampleSize: resolved.sampleSize,
            channelLayout: resolved.channelLayout,
            preciseSamplingRate: resolved.preciseSamplingRate
        )
        return CMAFTrackConfiguration(
            trackID: context.trackID,
            kind: .audio,
            profile: context.profile,
            timescale: context.mdhd.timescale,
            language: context.mdhd.language,
            audioFields: audio,
            editList: context.editList,
            encryptionParameters: encryptionParameters
        )
    }

    private static func resolveSubtitle(
        context: TrackResolutionContext,
        entry: any SampleEntry
    ) throws -> CMAFTrackConfiguration {
        let codec: SubtitleCodec
        switch entry {
        case is WebVTTSampleEntry:
            codec = .webVTT
        case let stpp as XMLSubtitleSampleEntry:
            codec = stpp.auxiliaryMIMETypes.contains("im1i") ? .imsc1Image : .imsc1Text
        default:
            throw CMAFReaderError.unexpectedBoxAtLevel(
                parent: "stsd",
                found: type(of: entry).boxType
            )
        }
        return CMAFTrackConfiguration(
            trackID: context.trackID,
            kind: .subtitle,
            profile: context.profile,
            timescale: context.mdhd.timescale,
            language: context.mdhd.language,
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: codec,
                language: context.mdhd.language
            ),
            editList: context.editList
        )
    }

    private static func resolveMetadata(
        context: TrackResolutionContext,
        entry: any SampleEntry
    ) throws -> CMAFTrackConfiguration {
        let metadataType: MetadataType
        switch entry {
        case is ID3SampleEntry:
            metadataType = .id3
        case let mett as TextMetadataSampleEntry:
            if mett.mimeFormat.contains("smpte-336-klv") {
                metadataType = .klv
            } else {
                metadataType = .timedText
            }
        case let urim as URIMetadataSampleEntry:
            metadataType = .uri(urim.uri.uri)
        default:
            throw CMAFReaderError.unexpectedBoxAtLevel(
                parent: "stsd",
                found: type(of: entry).boxType
            )
        }
        return CMAFTrackConfiguration(
            trackID: context.trackID,
            kind: .metadata,
            profile: context.profile,
            timescale: context.mdhd.timescale,
            language: context.mdhd.language,
            metadataFields: CMAFTrackConfiguration.MetadataFields(
                handlerType: context.handlerType,
                metadataType: metadataType
            ),
            editList: context.editList
        )
    }

    // MARK: - Helpers

    private static func trackKind(handlerType: FourCC) -> CMAFTrackKind {
        switch handlerType {
        case "vide": return .video
        case "soun": return .audio
        case "subt", "sbtl": return .subtitle
        default: return .metadata
        }
    }

    private static func extractEditList(from trak: TrackBox) -> EditListBox? {
        guard let edts = trak.children.compactMap({ $0 as? EditBox }).first else {
            return nil
        }
        return edts.children.compactMap { $0 as? EditListBox }.first
    }
}
