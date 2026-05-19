// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFFragmentSegment + CMAFPartialChunk
//
// Reference: ISO/IEC 23000-19 §7.3 (CMAF Fragment) and §7.3.5
// (CMAF Chunk). One ``CMAFFragmentSegment`` value carries the bytes
// of one media segment (`styp` + `moof` + `mdat` and any leading
// `sidx` / `prft` / `emsg`); the optional ``partialChunks`` array is
// non-nil when the writer was configured for LL-HLS partial-chunk
// emission.

import Foundation

/// One media segment produced by ``CMAFMediaSegmentWriter``.
public struct CMAFFragmentSegment: Sendable, Equatable, Hashable {
    /// The complete segment bytes as they would be written to disk
    /// or pushed onto a transport.
    public let bytes: Data
    /// Fragment sequence number, matching `mfhd.sequence_number`.
    /// Monotonically increases per writer instance.
    public let sequenceNumber: UInt32
    /// Decode start time of the first sample in the fragment, in the
    /// reference track's timescale (matches `tfdt.baseMediaDecodeTime`).
    public let baseMediaDecodeTime: UInt64
    /// Aggregate sample duration carried by the fragment, in the
    /// reference track's timescale.
    public let durationInTimescale: UInt64
    /// True when the first sample of the fragment is a Stream Access
    /// Point per ISO/IEC 14496-12 §8.16.3.3. CMAF requires this for
    /// every media segment per ISO/IEC 23000-19 §7.3.5.1.
    public let isStreamAccessPoint: Bool
    /// Optional LL-HLS partial chunks when the writer emitted them.
    /// `nil` when the writer was not configured for partial chunks.
    public let partialChunks: [CMAFPartialChunk]?

    public init(
        bytes: Data,
        sequenceNumber: UInt32,
        baseMediaDecodeTime: UInt64,
        durationInTimescale: UInt64,
        isStreamAccessPoint: Bool,
        partialChunks: [CMAFPartialChunk]? = nil
    ) {
        self.bytes = bytes
        self.sequenceNumber = sequenceNumber
        self.baseMediaDecodeTime = baseMediaDecodeTime
        self.durationInTimescale = durationInTimescale
        self.isStreamAccessPoint = isStreamAccessPoint
        self.partialChunks = partialChunks
    }
}

/// One LL-HLS partial chunk emitted within a parent fragment.
public struct CMAFPartialChunk: Sendable, Equatable, Hashable {
    /// Bytes of one `moof`+`mdat` pair carrying a subset of the
    /// parent fragment's samples.
    public let bytes: Data
    /// 0-based index within the parent fragment.
    public let chunkIndex: UInt32
    /// True when this chunk begins at a Stream Access Point — only
    /// the first chunk of a fragment can be independent per IETF
    /// RFC 8216bis §B.4.1.
    public let isIndependent: Bool
    /// Aggregate sample duration carried by the chunk, in the
    /// reference track's timescale.
    public let durationInTimescale: UInt64

    public init(
        bytes: Data,
        chunkIndex: UInt32,
        isIndependent: Bool,
        durationInTimescale: UInt64
    ) {
        self.bytes = bytes
        self.chunkIndex = chunkIndex
        self.isIndependent = isIndependent
        self.durationInTimescale = durationInTimescale
    }
}
