// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFSampleTiming
//
// Reference: ISO/IEC 14496-12 §8.8.8 (TrackRunBox `trun` per-sample
// timing fields).
//
// One value groups the three per-sample timing fields used by a CMAF
// fragment's `trun` payload: the absolute decode time, the duration in
// the track's timescale, and the signed composition-time offset
// (non-zero for B-frame video).

import Foundation

/// Per-sample timing for a CMAF fragment.
///
/// Groups the three timing fields a `trun` row carries per ISO/IEC
/// 14496-12 §8.8.8:
///
/// - ``decodeTime`` — absolute decode time in the track's timescale
///   (equivalent to the `tfdt.baseMediaDecodeTime` + sum of preceding
///   sample durations).
/// - ``durationInTimescale`` — sample duration in the track's timescale,
///   matching `trun.sample_duration`.
/// - ``compositionTimeOffset`` — signed offset matching
///   `trun.sample_composition_time_offset`; non-zero for B-frame video.
///
/// Used by per-track sample producers — for example
/// ``MVHEVCPackager/LayerSampleOutput`` — to convey one frame's timing
/// to downstream writers without re-introducing four independent
/// parameters per call site.
///
/// Reference: ISO/IEC 14496-12 §8.8.8.
public struct CMAFSampleTiming: Sendable, Equatable, Hashable {
    /// Absolute decode time in the track's timescale.
    public let decodeTime: UInt64

    /// Sample duration in the track's timescale.
    public let durationInTimescale: UInt32

    /// Signed composition-time offset in the track's timescale.
    /// `0` for non-B-frame video; non-zero for B-frame video.
    public let compositionTimeOffset: Int32

    public init(
        decodeTime: UInt64,
        durationInTimescale: UInt32,
        compositionTimeOffset: Int32 = 0
    ) {
        self.decodeTime = decodeTime
        self.durationInTimescale = durationInTimescale
        self.compositionTimeOffset = compositionTimeOffset
    }
}
