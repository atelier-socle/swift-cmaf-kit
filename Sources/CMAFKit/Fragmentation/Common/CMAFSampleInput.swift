// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFSampleInput
//
// Reference: ISO/IEC 14496-12 §8.8 (movie fragments) and ISO/IEC
// 23001-7 §7.2 (sample encryption metadata). One value represents a
// single ISOBMFF sample as it enters the writer.

import Foundation

/// One sample handed to ``CMAFMediaSegmentWriter``.
///
/// The writer accepts pre-encoded sample bytes plus the timing and
/// flag information needed by `trun` / `tfhd` / `senc` boxes. The
/// writer does not parse or transform the bytes; consumers are
/// responsible for delivering them in the correct on-wire form for
/// the declared codec (e.g., length-prefixed NAL units for AVC / HEVC,
/// ADTS-free raw AAC for `mp4a`).
public struct CMAFSampleInput: Sendable, Equatable, Hashable {
    /// Encoded sample bytes. For encrypted tracks the bytes are
    /// already encrypted; CMAFKit emits them verbatim.
    public let bytes: Data
    /// Sample duration in the parent track's timescale.
    public let durationInTimescale: UInt32
    /// Composition-time offset (`composition_time_offset` per
    /// ISO/IEC 14496-12 §8.8.8). Signed; non-zero for B-frame video.
    public let compositionTimeOffset: Int32
    /// Per-sample flags. The writer compares these across the
    /// fragment to decide whether `default_sample_flags` and
    /// `first-sample-flags-present` apply per ISO/IEC 14496-12 §8.8.7.
    public let flags: SampleFlags
    /// Per-sample encryption metadata. Required when the parent
    /// track's configuration carries ``CMAFEncryptionParameters``;
    /// must be `nil` when the track is unencrypted.
    public let encryption: EncryptionMetadata?

    public init(
        bytes: Data,
        durationInTimescale: UInt32,
        compositionTimeOffset: Int32 = 0,
        flags: SampleFlags = .syncSample,
        encryption: EncryptionMetadata? = nil
    ) {
        self.bytes = bytes
        self.durationInTimescale = durationInTimescale
        self.compositionTimeOffset = compositionTimeOffset
        self.flags = flags
        self.encryption = encryption
    }

    /// Per-sample encryption metadata as carried by ``SampleEncryptionBox``.
    public struct EncryptionMetadata: Sendable, Equatable, Hashable {
        /// Per-sample initialisation vector. Length must equal the
        /// track's `defaultPerSampleIVSize` raw value (`8` or `16`).
        public let initializationVector: Data
        /// Subsample partitions when subsample encryption is in use.
        /// `nil` when every byte of the sample is encrypted.
        public let subsamples: [SampleEncryptionBox.SubsamplePartition]?

        public init(
            initializationVector: Data,
            subsamples: [SampleEncryptionBox.SubsamplePartition]? = nil
        ) {
            self.initializationVector = initializationVector
            self.subsamples = subsamples
        }
    }
}
