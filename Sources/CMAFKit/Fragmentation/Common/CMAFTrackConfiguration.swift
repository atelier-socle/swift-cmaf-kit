// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFTrackConfiguration
//
// Reference: ISO/IEC 23000-19 §7 (CMAF Track constraints) and
// ISO/IEC 14496-12 §8.3 / §8.5 (Track and SampleDescription).
//
// One value describes everything the writer needs to compose a track:
// the codec, its configuration record, the dimensions / sample rate,
// the language, optional encryption parameters, and the default
// per-sample flags emitted in `trex`.

import Foundation

/// Configuration for one track inside an init or media segment.
///
/// Exactly one of ``videoFields``, ``audioFields``, ``subtitleFields``,
/// ``metadataFields`` is non-nil; the choice must match ``kind``.
public struct CMAFTrackConfiguration: Sendable, Equatable {
    /// Track identifier as used in `tkhd.track_ID` and the writer's
    /// internal sample dispatch.
    public let trackID: UInt32
    /// Kind of media carried by this track.
    public let kind: CMAFTrackKind
    /// CMAF profile selected for the segments emitted from this
    /// configuration. Drives `ftyp` / `styp` brand composition.
    public let profile: CMAFProfile
    /// Track timescale, as emitted in `mdhd.timescale`.
    public let timescale: UInt32
    /// ISO 639-2/T 3-byte language code (e.g., `"eng"`, `"fra"`,
    /// `"und"`).
    public let language: String
    /// Video-specific fields. Present iff `kind == .video`.
    public let videoFields: VideoFields?
    /// Audio-specific fields. Present iff `kind == .audio`.
    public let audioFields: AudioFields?
    /// Subtitle-specific fields. Present iff `kind == .subtitle`.
    public let subtitleFields: SubtitleFields?
    /// Metadata-track-specific fields. Present iff `kind == .metadata`.
    public let metadataFields: MetadataFields?
    /// Optional edit list emitted as `edts/elst`. Required for audio
    /// codecs with non-zero priming (`Opus`, HE-AAC).
    public let editList: EditListBox?
    /// Optional Common Encryption parameters. When present the writer
    /// rewrites the sample entry to `encv`/`enca` and emits
    /// `sinf`/`schm`/`schi`/`tenc` plus moov-level `pssh` boxes.
    public let encryptionParameters: CMAFEncryptionParameters?
    /// Default per-sample flags emitted in `trex`.
    public let defaultSampleFlags: SampleFlags
    /// Typed accessibility metadata for the track. Defaults to `nil`
    /// — tracks without accessibility signalling behave identically
    /// to v0.1.0. HLSKit consumes this for `EXT-X-MEDIA` attribute
    /// emission; DASHKit consumes this for `<Role>` / `<Accessibility>`
    /// descriptor emission. See ``AccessibilityMetadata``.
    public let accessibility: AccessibilityMetadata?

    public init(
        trackID: UInt32,
        kind: CMAFTrackKind,
        profile: CMAFProfile,
        timescale: UInt32,
        language: String,
        videoFields: VideoFields? = nil,
        audioFields: AudioFields? = nil,
        subtitleFields: SubtitleFields? = nil,
        metadataFields: MetadataFields? = nil,
        editList: EditListBox? = nil,
        encryptionParameters: CMAFEncryptionParameters? = nil,
        defaultSampleFlags: SampleFlags = SampleFlags(),
        accessibility: AccessibilityMetadata? = nil
    ) {
        self.trackID = trackID
        self.kind = kind
        self.profile = profile
        self.timescale = timescale
        self.language = language
        self.videoFields = videoFields
        self.audioFields = audioFields
        self.subtitleFields = subtitleFields
        self.metadataFields = metadataFields
        self.editList = editList
        self.encryptionParameters = encryptionParameters
        self.defaultSampleFlags = defaultSampleFlags
        self.accessibility = accessibility
    }

    /// Video-track fields. Carries everything required by the sample
    /// entry plus the dimensions emitted in `tkhd.width`/`tkhd.height`.
    public struct VideoFields: Sendable, Equatable {
        public let width: UInt32
        public let height: UInt32
        public let codec: VideoCodec
        public let codecConfiguration: VideoCodecConfiguration
        public let colorInformation: ColorInformationBox?
        public let masteringDisplay: MasteringDisplayColourVolumeBox?
        public let contentLightLevel: ContentLightLevelBox?
        public let dolbyVisionConfiguration: DolbyVisionConfigurationBox?
        public let dolbyVisionELConfiguration: DolbyVisionELConfigurationBox?
        public let pixelAspectRatio: PixelAspectRatioBox?
        public let cleanAperture: CleanApertureBox?
        public let frameRate: FrameRate
        public let isStillImage: Bool

        public init(
            width: UInt32,
            height: UInt32,
            codec: VideoCodec,
            codecConfiguration: VideoCodecConfiguration,
            colorInformation: ColorInformationBox? = nil,
            masteringDisplay: MasteringDisplayColourVolumeBox? = nil,
            contentLightLevel: ContentLightLevelBox? = nil,
            dolbyVisionConfiguration: DolbyVisionConfigurationBox? = nil,
            dolbyVisionELConfiguration: DolbyVisionELConfigurationBox? = nil,
            pixelAspectRatio: PixelAspectRatioBox? = nil,
            cleanAperture: CleanApertureBox? = nil,
            frameRate: FrameRate,
            isStillImage: Bool = false
        ) {
            self.width = width
            self.height = height
            self.codec = codec
            self.codecConfiguration = codecConfiguration
            self.colorInformation = colorInformation
            self.masteringDisplay = masteringDisplay
            self.contentLightLevel = contentLightLevel
            self.dolbyVisionConfiguration = dolbyVisionConfiguration
            self.dolbyVisionELConfiguration = dolbyVisionELConfiguration
            self.pixelAspectRatio = pixelAspectRatio
            self.cleanAperture = cleanAperture
            self.frameRate = frameRate
            self.isStillImage = isStillImage
        }

        /// Video frame rate as an exact `numerator / denominator`
        /// rational. Avoids floating-point drift over long clips.
        public struct FrameRate: Sendable, Hashable, Equatable, Codable {
            public let numerator: UInt32
            public let denominator: UInt32

            public init(numerator: UInt32, denominator: UInt32) {
                precondition(denominator > 0, "FrameRate denominator must be > 0")
                self.numerator = numerator
                self.denominator = denominator
            }
        }
    }

    /// Audio-track fields.
    public struct AudioFields: Sendable, Equatable {
        public let codec: AudioCodec
        public let codecConfiguration: AudioCodecConfiguration
        /// Channel count as carried in the legacy 16-bit field of
        /// AudioSampleEntry. The modern `chnl` override (when set)
        /// supersedes this for layout-aware consumers.
        public let channelCount: UInt16
        /// Sample rate as the legacy 16.16 fixed-point value
        /// (`sampleRate << 16`). For example, 48000 Hz is stored as
        /// `48000`. The modern `srat` override carries an exact value.
        public let sampleRate: UInt32
        /// Legacy bit depth field (`AudioSampleEntry.sampleSize`).
        public let sampleSize: UInt16
        /// Optional modern channel-layout override.
        public let channelLayout: ChannelLayoutBox?
        /// Optional modern sampling-rate override.
        public let preciseSamplingRate: SamplingRateBox?
        /// Optional priming / encoder-delay metadata. When non-nil
        /// and ``editList`` is nil on the enclosing track, the writer
        /// auto-generates a single-entry `elst` with `mediaTime =
        /// preSkip`.
        public let priming: AudioPriming?

        public init(
            codec: AudioCodec,
            codecConfiguration: AudioCodecConfiguration,
            channelCount: UInt16,
            sampleRate: UInt32,
            sampleSize: UInt16 = 16,
            channelLayout: ChannelLayoutBox? = nil,
            preciseSamplingRate: SamplingRateBox? = nil,
            priming: AudioPriming? = nil
        ) {
            self.codec = codec
            self.codecConfiguration = codecConfiguration
            self.channelCount = channelCount
            self.sampleRate = sampleRate
            self.sampleSize = sampleSize
            self.channelLayout = channelLayout
            self.preciseSamplingRate = preciseSamplingRate
            self.priming = priming
        }
    }

    /// Subtitle-track fields.
    public struct SubtitleFields: Sendable, Equatable {
        public let codec: SubtitleCodec
        /// ISO 639-2/T language code for the subtitle stream itself.
        /// May differ from the track-level ``language`` (e.g., a
        /// French audio track with English subtitles).
        public let language: String
        /// Typed accessibility metadata for the subtitle stream
        /// itself (distinct from the parent track's accessibility).
        /// Defaults to `nil` — back-compat with v0.1.0.
        public let accessibility: AccessibilityMetadata?

        public init(
            codec: SubtitleCodec,
            language: String,
            accessibility: AccessibilityMetadata? = nil
        ) {
            self.codec = codec
            self.language = language
            self.accessibility = accessibility
        }
    }

    /// Timed-metadata track fields.
    public struct MetadataFields: Sendable, Equatable {
        /// Handler-type FourCC for the metadata stream (typically
        /// `meta` or a vendor-specific value).
        public let handlerType: FourCC
        public let metadataType: MetadataType

        public init(handlerType: FourCC, metadataType: MetadataType) {
            self.handlerType = handlerType
            self.metadataType = metadataType
        }
    }
}

extension CMAFTrackConfiguration {

    /// Typed BCP 47 view over the ``language`` field.
    ///
    /// Returns `nil` when the underlying string is empty, equal to
    /// `"und"` (undetermined per ISO 639-2 §3.1), or fails to parse as
    /// ISO 639-2. The non-throwing semantics make this safe for use in
    /// HLS variant playlist generation and DASH MPD `@lang` attribute
    /// generation where a parse failure should silently degrade rather
    /// than crash.
    ///
    /// For callers that need explicit error handling, use
    /// ``BCP47LanguageTag/fromISO6392T(_:)`` directly on ``language``.
    ///
    /// References:
    /// - IETF RFC 5646 — Tags for Identifying Languages
    /// - ISO 639-2 — Alpha-3 code (special-purpose code `und`)
    /// - ISO/IEC 14496-12 §8.4.2.3 — Media Header Box
    public var bcp47Language: BCP47LanguageTag? {
        Self.bcp47Tag(from: language)
    }

    fileprivate static func bcp47Tag(from raw: String) -> BCP47LanguageTag? {
        guard !raw.isEmpty, raw.lowercased() != "und" else { return nil }
        return try? BCP47LanguageTag.fromISO6392T(raw)
    }
}

extension CMAFTrackConfiguration.SubtitleFields {

    /// Typed BCP 47 view over the subtitle stream's own ``language``
    /// field. Returns `nil` on empty / `"und"` / parse failure
    /// (silent-degrade semantics — same rationale as
    /// ``CMAFTrackConfiguration/bcp47Language``).
    ///
    /// References:
    /// - IETF RFC 5646
    /// - ISO 639-2
    public var bcp47Language: BCP47LanguageTag? {
        CMAFTrackConfiguration.bcp47Tag(from: language)
    }
}
