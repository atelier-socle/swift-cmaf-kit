// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFFragmentBoundary + CMAFPartialChunkBoundary
//
// Reference: ISO/IEC 23000-19 §7.3 (CMAF Fragment constraints) and
// §7.3.5 (CMAF Chunk subdivision for low-latency delivery). The
// fragment-boundary strategies below drive when the media-segment
// writer cuts a `moof`+`mdat` pair, and when LL-HLS partial chunks
// are emitted within a fragment.

import Foundation

/// State exposed to a custom fragment-boundary predicate.
public struct CMAFFragmentState: Sendable {
    /// Number of samples observed in the current fragment, not yet
    /// flushed.
    public let currentFragmentSampleCount: UInt32
    /// Aggregate duration of samples observed in the current fragment,
    /// in the track's timescale.
    public let currentFragmentDurationInTimescale: UInt64
    /// The track's timescale.
    public let timescale: UInt32
    /// Whether the sample about to be considered for the boundary is
    /// a sync sample.
    public let isCurrentSampleSync: Bool
}

/// Strategy controlling where the media-segment writer cuts a CMAF
/// fragment (`moof`+`mdat` boundary).
public enum CMAFFragmentBoundary: Sendable {
    /// Cut after the given number of samples.
    case sampleCount(UInt32)
    /// Cut once the accumulated duration meets or exceeds the
    /// threshold (in seconds; converted to track timescale internally).
    case durationSeconds(Double)
    /// Cut on every sync sample. CMAF requires every media segment
    /// to begin at a Stream Access Point per ISO/IEC 23000-19
    /// §7.3.5.1, so this strategy is the safest choice for video.
    case onSyncSample
    /// Custom predicate evaluated after each sample. Return `true` to
    /// close the current fragment **after** the sample just appended.
    case custom(@Sendable (CMAFFragmentState) -> Bool)
}

extension CMAFFragmentBoundary: Equatable {
    public static func == (lhs: CMAFFragmentBoundary, rhs: CMAFFragmentBoundary) -> Bool {
        switch (lhs, rhs) {
        case (.sampleCount(let a), .sampleCount(let b)): return a == b
        case (.durationSeconds(let a), .durationSeconds(let b)): return a == b
        case (.onSyncSample, .onSyncSample): return true
        case (.custom, .custom): return false  // closures are not equatable
        default: return false
        }
    }
}

/// Strategy controlling LL-HLS partial-chunk emission within a CMAF
/// fragment per IETF RFC 8216bis §B.4.1.
public enum CMAFPartialChunkBoundary: Sendable, Equatable {
    /// Emit a partial chunk after the given number of samples within
    /// the current fragment.
    case sampleCount(UInt32)
    /// Emit a partial chunk after the given duration in seconds. A
    /// typical LL-HLS deployment uses 0.2 s to 1.0 s.
    case durationSeconds(Double)
    /// Emit a partial chunk after every individual sample. Most
    /// aggressive setting; useful for ultra-low-latency.
    case perSample
}
