// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleFlags
//
// Reference: ISO/IEC 14496-12 §8.8.3.1 (sample flags) and §8.8.7
// (TrackFragmentHeaderBox), §8.8.8 (TrackRunBox). The 32-bit on-wire
// sample-flags field is bit-packed; CMAFKit projects it into a typed
// struct so callers do not manipulate raw bits.

import Foundation

/// Per-sample flags used by `trex`, `tfhd`, and `trun` per
/// ISO/IEC 14496-12 §8.8.3.1.
///
/// The on-wire field is a 32-bit big-endian word:
///
/// ```
///   bits  0..3   reserved (always 0)
///   bits  4..5   is_leading
///   bits  6..7   sample_depends_on
///   bits  8..9   sample_is_depended_on
///   bits 10..11  sample_has_redundancy
///   bits 12..14  sample_padding_value
///   bit  15      sample_is_non_sync_sample
///   bits 16..31  sample_degradation_priority
/// ```
public struct SampleFlags: Sendable, Hashable, Equatable, Codable {
    /// 2-bit `is_leading` value (0..3).
    public let isLeading: UInt8
    /// 2-bit `sample_depends_on` value (0..3).
    public let sampleDependsOn: UInt8
    /// 2-bit `sample_is_depended_on` value (0..3).
    public let sampleIsDependedOn: UInt8
    /// 2-bit `sample_has_redundancy` value (0..3).
    public let sampleHasRedundancy: UInt8
    /// 3-bit `sample_padding_value` (0..7).
    public let samplePaddingValue: UInt8
    /// True when the sample is **not** a sync sample.
    public let sampleIsNonSyncSample: Bool
    /// 16-bit `sample_degradation_priority`.
    public let sampleDegradationPriority: UInt16

    public init(
        isLeading: UInt8 = 0,
        sampleDependsOn: UInt8 = 0,
        sampleIsDependedOn: UInt8 = 0,
        sampleHasRedundancy: UInt8 = 0,
        samplePaddingValue: UInt8 = 0,
        sampleIsNonSyncSample: Bool = false,
        sampleDegradationPriority: UInt16 = 0
    ) {
        precondition(isLeading <= 3, "is_leading must fit in 2 bits")
        precondition(sampleDependsOn <= 3, "sample_depends_on must fit in 2 bits")
        precondition(sampleIsDependedOn <= 3, "sample_is_depended_on must fit in 2 bits")
        precondition(sampleHasRedundancy <= 3, "sample_has_redundancy must fit in 2 bits")
        precondition(samplePaddingValue <= 7, "sample_padding_value must fit in 3 bits")
        self.isLeading = isLeading
        self.sampleDependsOn = sampleDependsOn
        self.sampleIsDependedOn = sampleIsDependedOn
        self.sampleHasRedundancy = sampleHasRedundancy
        self.samplePaddingValue = samplePaddingValue
        self.sampleIsNonSyncSample = sampleIsNonSyncSample
        self.sampleDegradationPriority = sampleDegradationPriority
    }

    /// Pack into the 32-bit big-endian field used by `trex`, `tfhd`,
    /// and `trun`.
    public var rawValue: UInt32 {
        var word: UInt32 = 0
        word |= UInt32(isLeading & 0x03) << 26
        word |= UInt32(sampleDependsOn & 0x03) << 24
        word |= UInt32(sampleIsDependedOn & 0x03) << 22
        word |= UInt32(sampleHasRedundancy & 0x03) << 20
        word |= UInt32(samplePaddingValue & 0x07) << 17
        word |= (sampleIsNonSyncSample ? UInt32(1) : 0) << 16
        word |= UInt32(sampleDegradationPriority)
        return word
    }

    /// Construct from the 32-bit on-wire field.
    public init(rawValue: UInt32) {
        self.isLeading = UInt8((rawValue >> 26) & 0x03)
        self.sampleDependsOn = UInt8((rawValue >> 24) & 0x03)
        self.sampleIsDependedOn = UInt8((rawValue >> 22) & 0x03)
        self.sampleHasRedundancy = UInt8((rawValue >> 20) & 0x03)
        self.samplePaddingValue = UInt8((rawValue >> 17) & 0x07)
        self.sampleIsNonSyncSample = (rawValue >> 16) & 0x01 != 0
        self.sampleDegradationPriority = UInt16(rawValue & 0xFFFF)
    }

    /// True when the sample is a sync sample (also known as a random
    /// access point or IDR for AVC / HEVC).
    public var isSyncSample: Bool { !sampleIsNonSyncSample }

    /// Default flags suitable for a non-sync video sample (P / B frame).
    public static let nonSyncSample = SampleFlags(
        sampleDependsOn: 1,
        sampleIsNonSyncSample: true
    )

    /// Default flags suitable for a sync video sample (IDR / IRAP /
    /// keyframe).
    public static let syncSample = SampleFlags(
        sampleDependsOn: 2,
        sampleIsNonSyncSample: false
    )
}
