// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFParsedSample + parsed-segment value types
//
// Reference: ISO/IEC 14496-12 §8.8.8 (per-sample fields from `trun`)
// and ISO/IEC 23001-7 §7.2 (per-sample encryption metadata).
//
// Mirror of ``CMAFSampleInput`` for the read side. Same fields,
// plus the cumulative decode time of the sample so consumers do
// not have to walk the fragment themselves to recover it.

import Foundation

/// One sample parsed out of a CMAF media fragment.
///
/// Round-trip discipline: a `CMAFSampleInput` fed into the writer
/// in S10 emerges as a structurally equivalent `CMAFParsedSample`
/// from the reader in S11, with the byte content preserved verbatim
/// and the timing fields reconstructed from the on-wire data.
public struct CMAFParsedSample: Sendable, Equatable, Hashable {
    /// Track identifier (`traf.tfhd.trackID`).
    public let trackID: UInt32
    /// Encoded sample bytes, sliced from the carrying `mdat`.
    public let bytes: Data
    /// Sample duration in the parent track's timescale.
    public let durationInTimescale: UInt32
    /// Composition-time offset per ISO/IEC 14496-12 §8.8.8.
    public let compositionTimeOffset: Int32
    /// Per-sample flags resolved from `trun` and `tfhd` defaults.
    public let flags: SampleFlags
    /// Per-sample encryption metadata. Present iff the track is
    /// encrypted and the parser had access to the `tenc` context
    /// for the explicit `senc` dispatch.
    public let encryption: CMAFSampleInput.EncryptionMetadata?
    /// Cumulative decode time of this sample in the track's
    /// timescale. Computed as `tfdt.baseMediaDecodeTime` plus the
    /// sum of preceding sample durations within the fragment.
    public let decodeTime: UInt64

    public init(
        trackID: UInt32,
        bytes: Data,
        durationInTimescale: UInt32,
        compositionTimeOffset: Int32,
        flags: SampleFlags,
        encryption: CMAFSampleInput.EncryptionMetadata?,
        decodeTime: UInt64
    ) {
        self.trackID = trackID
        self.bytes = bytes
        self.durationInTimescale = durationInTimescale
        self.compositionTimeOffset = compositionTimeOffset
        self.flags = flags
        self.encryption = encryption
        self.decodeTime = decodeTime
    }
}

/// Parsed representation of one CMAF init segment, retained by
/// conformance validators that need to cross-reference with media
/// segments.
public struct ParsedInitSegment: Sendable, Equatable {
    public let trackConfigurations: [CMAFTrackConfiguration]
    public let movieTimescale: UInt32
    public let fragmentDuration: UInt64?
    public let protectionSystemSpecificHeaders: [ProtectionSystemSpecificHeaderBox]
    /// `ftyp.majorBrand` plus `ftyp.compatibleBrands` for the
    /// brand-coherence validation rules.
    public let majorBrand: FourCC
    public let compatibleBrands: [FourCC]

    public init(
        trackConfigurations: [CMAFTrackConfiguration],
        movieTimescale: UInt32,
        fragmentDuration: UInt64?,
        protectionSystemSpecificHeaders: [ProtectionSystemSpecificHeaderBox],
        majorBrand: FourCC,
        compatibleBrands: [FourCC]
    ) {
        self.trackConfigurations = trackConfigurations
        self.movieTimescale = movieTimescale
        self.fragmentDuration = fragmentDuration
        self.protectionSystemSpecificHeaders = protectionSystemSpecificHeaders
        self.majorBrand = majorBrand
        self.compatibleBrands = compatibleBrands
    }
}

/// Parsed representation of one CMAF media segment.
public struct ParsedMediaSegment: Sendable, Equatable {
    /// 0-based segment index in the presentation. Set by the
    /// caller; the reader does not maintain global numbering on
    /// its own.
    public let segmentIndex: Int
    /// Every sample parsed out of the segment, in decode order.
    public let samples: [CMAFParsedSample]
    /// All `mfhd.sequence_number` values observed across the
    /// segment's `moof` boxes (one per fragment, possibly multiple
    /// per LL-HLS chunked segment).
    public let movieFragmentSequenceNumbers: [UInt32]
    /// Per-track first `tfdt.baseMediaDecodeTime` for the segment.
    public let baseMediaDecodeTimes: [UInt32: UInt64]
    /// True when the segment carried a `sidx` immediately after
    /// `styp` (DASH conformance signal).
    public let hasSegmentIndex: Bool
    /// True when the segment carried a `prft` (live signalling).
    public let hasProducerReferenceTime: Bool
    /// All `emsg` boxes attached to the segment (DASH events).
    public let eventMessages: [EventMessageBox]
    /// All `sidx` boxes inside the segment in declaration order.
    public let segmentIndices: [SegmentIndexBox]
    /// True when the segment was assembled from one or more LL-HLS
    /// partial chunks (`moof+mdat` pairs in sequence).
    public let isChunkedSegment: Bool
    /// First sample of the segment is a sync sample (SAP check).
    public let firstSampleIsSyncSample: Bool

    public init(
        segmentIndex: Int,
        samples: [CMAFParsedSample],
        movieFragmentSequenceNumbers: [UInt32],
        baseMediaDecodeTimes: [UInt32: UInt64],
        hasSegmentIndex: Bool,
        hasProducerReferenceTime: Bool,
        eventMessages: [EventMessageBox],
        segmentIndices: [SegmentIndexBox],
        isChunkedSegment: Bool,
        firstSampleIsSyncSample: Bool
    ) {
        self.segmentIndex = segmentIndex
        self.samples = samples
        self.movieFragmentSequenceNumbers = movieFragmentSequenceNumbers
        self.baseMediaDecodeTimes = baseMediaDecodeTimes
        self.hasSegmentIndex = hasSegmentIndex
        self.hasProducerReferenceTime = hasProducerReferenceTime
        self.eventMessages = eventMessages
        self.segmentIndices = segmentIndices
        self.isChunkedSegment = isChunkedSegment
        self.firstSampleIsSyncSample = firstSampleIsSyncSample
    }
}
