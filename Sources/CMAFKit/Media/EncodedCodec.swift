// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EncodedCodec
//
// Discriminated union of every codec CMAFKit can produce or consume. Some cases
// carry profile information (e.g., `aac(AACProfile)`).

import Foundation

/// A codec identifier, optionally carrying profile or sub-format information.
///
/// Used by `EncodedFrame` and the high-level CMAF audio and video
/// configuration aggregates.
public enum EncodedCodec: Sendable, Hashable {
    // Video
    /// H.264 / AVC.
    case h264
    /// HEVC / H.265.
    case h265
    /// Multi-layer HEVC (MV-HEVC), `hvc2`-class sample entries.
    case h265MultiLayer
    /// Multi-Layer Main / Multiview Main HEVC per ISO/IEC 14496-15 §8.4.
    /// 8-bit depth profile family (Apple Vision Pro Spatial Video default).
    case mvHEVC
    /// Multi-Layer Main 10 / Three-Dimensional Main 10 HEVC per
    /// ISO/IEC 14496-15 §8.4 and ITU-T H.265 §I.A.4. 10-bit depth profile.
    case mvHEVC10
    /// AV1.
    case av1
    /// Apple ProRes (with profile flavor).
    case proRes(ProResFlavor)
    /// Motion JPEG.
    case motionJPEG

    // Audio
    /// MPEG-4 Advanced Audio Coding (with profile / object type).
    case aac(AACProfile)
    /// Dolby AC-3.
    case ac3
    /// Dolby Enhanced AC-3 (E-AC-3) — Atmos JOC detection happens at frame level.
    case eac3
    /// Xiph Opus.
    case opus
    /// Xiph FLAC.
    case flac
    /// Apple Lossless Audio Codec.
    case alac
    /// MPEG-1/2 Layer III (MP3).
    case mp3
    /// Linear PCM (with sample format).
    case pcm(PCMFormat)

    /// H.266 (VVC) — **out of scope for CMAFKit 0.1.0**. Listed for API
    /// future-proofing; no sample entry is produced for this case in 0.1.0.
    case vvc
}
