// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFTrackKind + codec enums
//
// Reference: ISO/IEC 14496-12 §8.4.3 (HandlerReferenceBox handler types).
// Reference: ISO/IEC 23000-19 §7.4 (CMAF Track constraints — single
//            primary track per CMAF Track).
//
// CMAFKit projects the handler-type FourCCs into a typed Swift enum so
// the writer dispatches on track kind without string comparison.

import Foundation

/// Kind of media carried by a CMAF track.
///
/// Maps to the `hdlr.handler_type` FourCC defined by ISO/IEC 14496-12
/// §8.4.3 — `vide`, `soun`, `subt`, `meta`.
public enum CMAFTrackKind: Sendable, Hashable, Equatable, Codable, CaseIterable {
    /// Video track (`hdlr.handler_type == "vide"`).
    case video
    /// Audio track (`hdlr.handler_type == "soun"`).
    case audio
    /// Subtitle track (`hdlr.handler_type == "subt"` or "sbtl").
    case subtitle
    /// Timed metadata track (`hdlr.handler_type == "meta"`).
    case metadata

    /// The `hdlr.handler_type` FourCC emitted for this kind.
    public var handlerType: FourCC {
        switch self {
        case .video: return "vide"
        case .audio: return "soun"
        case .subtitle: return "subt"
        case .metadata: return "meta"
        }
    }
}

/// Video codec supported by the CMAF writer.
///
/// Each case maps to a specific sample-entry FourCC. The `inBand`
/// variants (`avc3`, `hev1`, `dvhe`) signal that parameter sets may
/// appear within the bitstream itself; the non-suffixed variants
/// (`avc1`, `hvc1`, `dvh1`) require parameter sets only in the
/// configuration record.
public enum VideoCodec: Sendable, Hashable, Equatable, Codable, CaseIterable {
    case avc1
    case avc3
    case hvc1
    case hev1
    case dvh1
    case dvhe
    case vp08
    case vp09
    case av01
    case mp4v

    /// The on-wire sample-entry FourCC for this codec.
    public var sampleEntryFourCC: FourCC {
        switch self {
        case .avc1: return "avc1"
        case .avc3: return "avc3"
        case .hvc1: return "hvc1"
        case .hev1: return "hev1"
        case .dvh1: return "dvh1"
        case .dvhe: return "dvhe"
        case .vp08: return "vp08"
        case .vp09: return "vp09"
        case .av01: return "av01"
        case .mp4v: return "mp4v"
        }
    }
}

/// Audio codec supported by the CMAF writer.
public enum AudioCodec: Sendable, Hashable, Equatable, Codable, CaseIterable {
    case mp4a
    case ac3
    case ec3
    case ac4
    case opus
    case flac
    /// MPEG-H 3D Audio, main stream (`mhm1`).
    case mpegHMain
    /// MPEG-H 3D Audio, multi-stream (`mhm2`).
    case mpegHMultiStream

    /// The on-wire sample-entry FourCC for this codec.
    public var sampleEntryFourCC: FourCC {
        switch self {
        case .mp4a: return "mp4a"
        case .ac3: return "ac-3"
        case .ec3: return "ec-3"
        case .ac4: return "ac-4"
        case .opus: return "Opus"
        case .flac: return "fLaC"
        case .mpegHMain: return "mhm1"
        case .mpegHMultiStream: return "mhm2"
        }
    }
}

/// Subtitle codec supported by the CMAF writer.
public enum SubtitleCodec: Sendable, Hashable, Equatable, Codable, CaseIterable {
    /// WebVTT (`wvtt`).
    case webVTT
    /// IMSC1 TTML text profile (`stpp` with `application/ttml+xml`).
    case imsc1Text
    /// IMSC1 image profile (`stpp` with PNG / SMPTE-TT image data).
    case imsc1Image

    /// The on-wire sample-entry FourCC for this codec.
    public var sampleEntryFourCC: FourCC {
        switch self {
        case .webVTT: return "wvtt"
        case .imsc1Text, .imsc1Image: return "stpp"
        }
    }
}

/// Kind of timed metadata payload.
public enum MetadataType: Sendable, Hashable, Equatable, Codable {
    /// ID3v2 timed-metadata samples per the HLS / ID3 timed metadata
    /// recommendation (handler `meta`, sample entry `id3 `).
    case id3
    /// KLV (Key-Length-Value) timed metadata per SMPTE ST 336.
    case klv
    /// Generic text-metadata stream (`mett` sample entry with the
    /// consumer's MIME identifier).
    case timedText
    /// URI-scheme metadata (`urim` sample entry with the supplied
    /// URI as the scheme identifier).
    case uri(String)
}
