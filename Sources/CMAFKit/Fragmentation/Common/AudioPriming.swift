// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AudioPriming
//
// Reference: ISO/IEC 14496-12 §8.6.6 (EditListBox) and
// "Encapsulation of Opus in ISO Base Media File Format" §4.2
// (pre-skip handling via edit list).
//
// Codecs with encoder delay (Opus, HE-AAC, AAC with SBR / PS) need
// playback to start a defined number of samples into the track. The
// writer auto-emits an `elst` entry whose `mediaTime` equals
// ``preSkip`` to skip those samples at playback time.

import Foundation

/// Audio encoder priming / pre-skip metadata.
///
/// Apply to ``CMAFTrackConfiguration/AudioFields/priming`` when the
/// codec configuration introduces a non-zero number of samples that
/// must be discarded at playback start.
public struct AudioPriming: Sendable, Hashable, Equatable, Codable {
    /// Number of priming samples, measured in audio sample units
    /// (not the track's timescale — the writer translates).
    public let preSkip: UInt32
    /// Optional number of trailing samples to drop (used by some
    /// codecs that introduce end-of-stream padding).
    public let endTrim: UInt32

    public init(preSkip: UInt32, endTrim: UInt32 = 0) {
        self.preSkip = preSkip
        self.endTrim = endTrim
    }
}
