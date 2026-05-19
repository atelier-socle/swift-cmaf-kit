// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleEntryComposer
//
// Reference: ISO/IEC 14496-12 §8.5.2.2 (SampleDescriptionBox entries).
// Reference: ISO/IEC 14496-15 §5.3, §8.3 (AVC, HEVC sample entries).
// Reference: ETSI TS 102 366 Annex F (AC-3, E-AC-3 sample entries).
// Reference: ETSI TS 103 190 (AC-4 sample entry).
// Reference: ISO/IEC 23001-7 §4 (encrypted sample-entry rewrite).
//
// Composes the sample-entry box for one track from its
// ``CMAFTrackConfiguration``. When the track carries encryption
// parameters, the sample-entry FourCC is rewritten to `encv` / `enca`
// and a `sinf` is appended carrying the original codec FourCC plus
// scheme metadata.

import Foundation

/// Internal helper turning a ``CMAFTrackConfiguration`` into the
/// concrete `(any ISOBox)` value to place inside `stsd.entries`.
internal enum SampleEntryComposer {

    /// Compose the sample-entry for a video track.
    static func makeVideoSampleEntry(
        configuration: CMAFTrackConfiguration
    ) throws -> any ISOBox {
        guard let video = configuration.videoFields else {
            throw CMAFWriterError.configurationInvalid(
                reason: "video track \(configuration.trackID) missing videoFields"
            )
        }
        let visualFields = VisualSampleEntryFields(
            width: UInt16(clamping: video.width),
            height: UInt16(clamping: video.height)
        )
        let extensions = makeVideoExtensions(from: video)

        if let encryption = configuration.encryptionParameters {
            return EncryptedVideoSampleEntry(
                visualFields: visualFields,
                originalCodecConfiguration: video.codecConfiguration,
                protectionSchemeInfo: encryption.makeProtectionSchemeInfoBox(
                    originalFormat: video.codec.sampleEntryFourCC
                ),
                extensions: extensions
            )
        }

        switch video.codec {
        case .avc1:
            guard case let .avc(record) = video.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "avc1 sample entry requires .avc codec configuration"
                )
            }
            return AVCSampleEntry(
                visualFields: visualFields,
                configuration: record,
                extensions: extensions
            )
        case .avc3:
            guard case let .avc(record) = video.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "avc3 sample entry requires .avc codec configuration"
                )
            }
            return AVCSampleEntryInband(
                visualFields: visualFields,
                configuration: record,
                extensions: extensions
            )
        case .hvc1:
            guard case let .hevc(record) = video.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "hvc1 sample entry requires .hevc codec configuration"
                )
            }
            return HEVCSampleEntry(
                visualFields: visualFields,
                configuration: record,
                extensions: extensions
            )
        case .hev1:
            guard case let .hevc(record) = video.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "hev1 sample entry requires .hevc codec configuration"
                )
            }
            return HEVCSampleEntryInband(
                visualFields: visualFields,
                configuration: record,
                extensions: extensions
            )
        case .dvh1, .dvhe:
            guard case let .hevc(record) = video.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "\(video.codec.sampleEntryFourCC) requires .hevc codec configuration"
                )
            }
            guard let dvcC = video.dolbyVisionConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "Dolby Vision sample entry requires dolbyVisionConfiguration"
                )
            }
            let dvConfig = dvcC.configuration
            let dvELConfig = video.dolbyVisionELConfiguration?.elConfiguration
            if video.codec == .dvhe {
                return DolbyVisionHEVCSampleEntryInband(
                    visualFields: visualFields,
                    hevcConfiguration: record,
                    dolbyVisionConfiguration: dvConfig,
                    dolbyVisionELConfiguration: dvELConfig,
                    extensions: extensions
                )
            }
            return DolbyVisionHEVCSampleEntry(
                visualFields: visualFields,
                hevcConfiguration: record,
                dolbyVisionConfiguration: dvConfig,
                dolbyVisionELConfiguration: dvELConfig,
                extensions: extensions
            )
        case .vp08:
            guard case let .vp(record) = video.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "vp08 sample entry requires .vp codec configuration"
                )
            }
            return VP8SampleEntry(
                visualFields: visualFields,
                configuration: record,
                extensions: extensions
            )
        case .vp09:
            guard case let .vp(record) = video.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "vp09 sample entry requires .vp codec configuration"
                )
            }
            return VP9SampleEntry(
                visualFields: visualFields,
                configuration: record,
                extensions: extensions
            )
        case .av01:
            guard case let .av1(record) = video.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "av01 sample entry requires .av1 codec configuration"
                )
            }
            return AV1SampleEntry(
                visualFields: visualFields,
                configuration: record,
                extensions: extensions
            )
        case .mp4v:
            guard case let .mp4Visual(esds) = video.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "mp4v sample entry requires .mp4Visual codec configuration"
                )
            }
            return MP4VisualSampleEntry(
                visualFields: visualFields,
                elementaryStreamDescriptor: esds,
                extensions: extensions
            )
        }
    }

    /// Compose the sample-entry for an audio track.
    static func makeAudioSampleEntry(
        configuration: CMAFTrackConfiguration
    ) throws -> any ISOBox {
        guard let audio = configuration.audioFields else {
            throw CMAFWriterError.configurationInvalid(
                reason: "audio track \(configuration.trackID) missing audioFields"
            )
        }
        let audioFields = AudioSampleEntryFields(
            channelCount: audio.channelCount,
            sampleSize: audio.sampleSize,
            sampleRate: audio.sampleRate
        )
        let extensions = AudioSampleEntryExtensions(
            channelLayout: audio.channelLayout,
            samplingRate: audio.preciseSamplingRate
        )

        if let encryption = configuration.encryptionParameters {
            return EncryptedAudioSampleEntry(
                audioFields: audioFields,
                originalCodecConfiguration: audio.codecConfiguration,
                protectionSchemeInfo: encryption.makeProtectionSchemeInfoBox(
                    originalFormat: audio.codec.sampleEntryFourCC
                ),
                extensions: extensions
            )
        }

        switch audio.codec {
        case .mp4a:
            guard case let .mp4Audio(esds) = audio.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "mp4a requires .mp4Audio codec configuration"
                )
            }
            return MP4AudioSampleEntry(
                audioFields: audioFields,
                elementaryStreamDescriptor: esds,
                extensions: extensions
            )
        case .ac3:
            guard case let .ac3(specific) = audio.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "ac-3 requires .ac3 codec configuration"
                )
            }
            return AC3SampleEntry(
                audioFields: audioFields,
                specificBox: specific,
                extensions: extensions
            )
        case .ec3:
            guard case let .ec3(specific) = audio.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "ec-3 requires .ec3 codec configuration"
                )
            }
            return EC3SampleEntry(
                audioFields: audioFields,
                specificBox: specific,
                extensions: extensions
            )
        case .ac4:
            guard case let .ac4(specific) = audio.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "ac-4 requires .ac4 codec configuration"
                )
            }
            return AC4SampleEntry(
                audioFields: audioFields,
                specificBox: specific,
                extensions: extensions
            )
        case .opus:
            guard case let .opus(specific) = audio.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "Opus requires .opus codec configuration"
                )
            }
            return OpusSampleEntry(
                audioFields: audioFields,
                specificBox: specific,
                extensions: extensions
            )
        case .flac:
            guard case let .flac(specific) = audio.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "fLaC requires .flac codec configuration"
                )
            }
            return FLACSampleEntry(
                audioFields: audioFields,
                specificBox: specific,
                extensions: extensions
            )
        case .mpegHMain:
            guard case let .mpegH(specific) = audio.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "MPEG-H main requires .mpegH codec configuration"
                )
            }
            return MPEGHAudioSampleEntry(
                audioFields: audioFields,
                configuration: specific,
                extensions: extensions
            )
        case .mpegHMultiStream:
            guard case let .mpegH(specific) = audio.codecConfiguration else {
                throw CMAFWriterError.configurationInvalid(
                    reason: "MPEG-H multi-stream requires .mpegH codec configuration"
                )
            }
            return MPEGHAudioSampleEntryMultiStream(
                audioFields: audioFields,
                configuration: specific,
                extensions: extensions
            )
        }
    }

    private static func makeVideoExtensions(
        from video: CMAFTrackConfiguration.VideoFields
    ) -> VideoSampleEntryExtensions {
        VideoSampleEntryExtensions(
            colorInformation: video.colorInformation,
            masteringDisplay: video.masteringDisplay,
            contentLightLevel: video.contentLightLevel,
            dolbyVisionConfiguration: video.dolbyVisionConfiguration,
            dolbyVisionELConfiguration: video.dolbyVisionELConfiguration,
            pixelAspectRatio: video.pixelAspectRatio,
            cleanAperture: video.cleanAperture
        )
    }
}
