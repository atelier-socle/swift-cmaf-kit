// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFMediaSegmentReader
//
// Reference: ISO/IEC 23000-19 §7.3 (CMAF Fragment) and ISO/IEC
// 14496-12 §8.8 (`moof`+`mdat`). Companion to the writer actor in
// Module 9 (Session 10).
//
// Stateful actor that ingests media-segment bytes and yields
// typed ``CMAFParsedSample`` instances per call. The actor
// maintains per-segment metadata across the stream (last
// `mfhd.sequence_number` per track, last `tfdt.baseMediaDecodeTime`
// per track) so the conformance validators downstream can flag
// cross-segment violations.
//
// Safety doctrine: ``finalize()`` is the canonical termination
// entry point. After it, every mutating call throws. `deinit`
// never performs async work — actor isolation forbids it — so
// consumers should always call `finalize()` to clear retained
// state.

import Foundation

/// Stateful actor reading CMAF media segments.
public actor CMAFMediaSegmentReader {

    /// Lifecycle state.
    public enum State: Sendable, Equatable {
        /// Constructed; no segment bytes ingested yet.
        case idle
        /// At least one call to `appendSegmentBytes(_:)` has
        /// completed.
        case streaming
        /// ``finalize()`` has been called.
        case finalized
    }

    /// Current lifecycle state.
    public private(set) var state: State = .idle

    /// True after ``finalize()``.
    public var isFinalized: Bool { state == .finalized }

    /// Init-segment track configurations.
    public let trackConfigurations: [CMAFTrackConfiguration]
    /// `mvhd.timescale` from the init segment.
    public let movieTimescale: UInt32
    /// `tenc` boxes per track ID, used for explicit `senc`
    /// dispatch.
    public let trackEncryptionContexts: [UInt32: TrackEncryptionBox]

    // MARK: Cross-segment state

    /// Per-track last observed `tfdt.baseMediaDecodeTime`.
    public private(set) var lastBaseMediaDecodeTimes: [UInt32: UInt64] = [:]
    /// Highest `mfhd.sequence_number` observed across all
    /// fragments ingested so far.
    public private(set) var lastSequenceNumber: UInt32 = 0
    /// 0-based count of media segments ingested.
    public private(set) var segmentsConsumed: Int = 0

    public init(
        initSegmentConfiguration: [CMAFTrackConfiguration],
        movieTimescale: UInt32,
        trackEncryptionContexts: [UInt32: TrackEncryptionBox] = [:]
    ) throws {
        self.trackConfigurations = initSegmentConfiguration
        self.movieTimescale = movieTimescale
        self.trackEncryptionContexts = trackEncryptionContexts
    }

    // MARK: - Public surface

    /// Ingest one CMAF media segment.
    ///
    /// - Returns: the parsed samples emitted by this segment, in
    ///   decode order, grouped logically by their `trackID`.
    /// - Throws: ``CMAFReaderError`` for structural inconsistencies.
    @discardableResult
    public func appendSegmentBytes(_ bytes: Data) async throws -> ParsedMediaSegment {
        guard state != .finalized else {
            throw CMAFReaderError.initSegmentInconsistency(
                reason: "reader is finalized; further segments cannot be appended"
            )
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let segment = try await composeSegment(boxes: boxes)
        segmentsConsumed += 1
        state = .streaming
        if let lastSeq = segment.movieFragmentSequenceNumbers.last {
            lastSequenceNumber = max(lastSequenceNumber, lastSeq)
        }
        for (trackID, decodeTime) in segment.baseMediaDecodeTimes {
            lastBaseMediaDecodeTimes[trackID] = decodeTime
        }
        return segment
    }

    /// Finalise the reader. Subsequent calls to
    /// `appendSegmentBytes(_:)` or `finalize()` throw.
    public func finalize() async throws {
        guard state != .finalized else {
            throw CMAFReaderError.initSegmentInconsistency(
                reason: "reader already finalized"
            )
        }
        state = .finalized
    }

    /// `deinit` documents the safety contract: the reader retains
    /// no async work, and finalisation is a synchronous state
    /// transition. Consumers should still call ``finalize()`` to
    /// signal end-of-stream intent.
    deinit {
        // Intentionally empty. Actor isolation precludes async work
        // here; the state machine is closed by `finalize()`.
    }

    // MARK: - Internals

    private func composeSegment(
        boxes: [any ISOBox]
    ) async throws -> ParsedMediaSegment {
        let moofs = boxes.compactMap { $0 as? MovieFragmentBox }
        let mdats = boxes.compactMap { $0 as? MediaDataBox }
        guard !moofs.isEmpty, moofs.count == mdats.count else {
            throw CMAFReaderError.mediaSegmentInconsistency(
                reason: "expected matching moof+mdat pairs; got "
                    + "\(moofs.count) moof and \(mdats.count) mdat"
            )
        }
        var samples: [CMAFParsedSample] = []
        var mfhds: [UInt32] = []
        var decodeTimes: [UInt32: UInt64] = [:]
        for (moof, mdat) in zip(moofs, mdats) {
            let walk = try await CMAFSampleResolver.walk(
                moof: moof,
                mdat: mdat,
                trackEncryptionContexts: trackEncryptionContexts
            )
            samples.append(contentsOf: walk.samples)
            mfhds.append(walk.mfhdSequenceNumber)
            // Keep the first occurrence per segment (the head of the
            // first fragment).
            for (trackID, time) in walk.baseMediaDecodeTimes
            where decodeTimes[trackID] == nil {
                decodeTimes[trackID] = time
            }
        }
        let segmentIndices = boxes.compactMap { $0 as? SegmentIndexBox }
        let eventMessages = boxes.compactMap { $0 as? EventMessageBox }
        let hasSegmentIndex = !segmentIndices.isEmpty
        let hasPrft = boxes.contains { $0 is ProducerReferenceTimeBox }
        let firstSync = samples.first?.flags.isSyncSample ?? false
        return ParsedMediaSegment(
            segmentIndex: segmentsConsumed,
            samples: samples,
            movieFragmentSequenceNumbers: mfhds,
            baseMediaDecodeTimes: decodeTimes,
            hasSegmentIndex: hasSegmentIndex,
            hasProducerReferenceTime: hasPrft,
            eventMessages: eventMessages,
            segmentIndices: segmentIndices,
            isChunkedSegment: moofs.count > 1,
            firstSampleIsSyncSample: firstSync
        )
    }
}
