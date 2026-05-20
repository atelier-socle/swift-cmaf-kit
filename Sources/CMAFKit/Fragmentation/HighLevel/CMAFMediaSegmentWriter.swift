// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFMediaSegmentWriter
//
// Reference: ISO/IEC 23000-19 §7.3 (CMAF Fragment) and ISO/IEC
// 14496-12 §8.8 (movie fragments / `moof` + `mdat`). Reference:
// IETF RFC 8216bis-13 §B.4.1 (LL-HLS partial chunks). Reference:
// ISO/IEC 23000-19 §7.3.5.1 (every media segment must begin at a
// Stream Access Point).
//
// Stateful writer actor that accumulates samples per track and emits
// one media segment (`styp` + optional `sidx` / `prft` / `emsg` +
// `moof` + `mdat`) per fragment boundary. When a partial-chunk
// boundary is supplied, the writer additionally sub-divides each
// fragment into LL-HLS partial chunks per RFC 8216bis-13 §B.4.1.
//
// Safety doctrine: ``finalize()`` is the canonical termination
// entry point. It transitions the actor to ``State/finalized`` and
// emits any pending fragment. After finalisation, every mutating
// method throws. `deinit` does **not** perform async work — actor
// isolation precludes it — so consumers must always call
// ``finalize()`` to recover the trailing fragment.

import Foundation

/// Stateful writer actor emitting CMAF media segments.
///
/// The writer is single-track per instance. Consumers compose
/// per-track writers (one per `trak`) at the consumer layer; cross-
/// track interleaving is handled at the orchestration layer.
public actor CMAFMediaSegmentWriter {

    /// Lifecycle state.
    public enum State: Sendable, Equatable {
        /// No sample has been appended yet.
        case empty
        /// One or more samples have been appended but the fragment
        /// boundary has not yet been hit.
        case openFragment(decodeTime: UInt64, samples: Int)
        /// ``finalize()`` has been called; mutating methods throw.
        case finalized
    }

    /// Current lifecycle state.
    public private(set) var state: State = .empty

    /// True after ``finalize()``.
    public var isFinalized: Bool { state == .finalized }

    public let configuration: CMAFTrackConfiguration
    public let fragmentBoundary: CMAFFragmentBoundary
    public let partialChunkBoundary: CMAFPartialChunkBoundary?
    public let emitSegmentIndex: Bool
    public let emitProducerReferenceTime: Bool

    /// Whether the configuration's profile demands LL-HLS chunking.
    private var requiresPartialChunking: Bool {
        partialChunkBoundary != nil
    }

    // MARK: Pending fragment state

    private var pendingSamples: [SegmentByteAssembler.WriterSample] = []
    private var pendingDecodeTime: UInt64 = 0
    private var pendingDurationInTimescale: UInt64 = 0
    private var nextSequenceNumber: UInt32 = 1
    private var nextBaseMediaDecodeTime: UInt64 = 0
    private var attachedEventMessages: [EventMessageBox] = []

    // MARK: Pending partial-chunk state

    /// Samples accumulated in the *current* partial chunk (a strict
    /// subset of ``pendingSamples`` since the last chunk emit).
    private var samplesInCurrentChunk: [SegmentByteAssembler.WriterSample] = []
    /// Duration accumulated in the current partial chunk.
    private var currentChunkDurationInTimescale: UInt64 = 0
    /// Decode time at which the current chunk started.
    private var currentChunkDecodeTime: UInt64 = 0
    /// Already-emitted chunks for the current fragment.
    private var pendingFragmentChunks: [CMAFPartialChunk] = []

    /// Construct a writer for one track configuration.
    ///
    /// - Throws: ``CMAFWriterError/configurationInvalid(reason:)`` or
    ///   ``CMAFWriterError/cmafConformanceViolation(rule:)`` when the
    ///   supplied configuration violates a CMAF / DASH / LL-HLS rule
    ///   that the writer enforces at construction time.
    public init(
        configuration: CMAFTrackConfiguration,
        fragmentBoundary: CMAFFragmentBoundary,
        partialChunkBoundary: CMAFPartialChunkBoundary? = nil,
        emitSegmentIndex: Bool = false,
        emitProducerReferenceTime: Bool = false
    ) throws {
        try Self.validate(
            configuration: configuration,
            fragmentBoundary: fragmentBoundary,
            partialChunkBoundary: partialChunkBoundary,
            emitSegmentIndex: emitSegmentIndex
        )
        self.configuration = configuration
        self.fragmentBoundary = fragmentBoundary
        self.partialChunkBoundary = partialChunkBoundary
        self.emitSegmentIndex = emitSegmentIndex
        self.emitProducerReferenceTime = emitProducerReferenceTime
    }

    // MARK: - Public surface

    /// Append one sample. Returns zero or more media segments when
    /// fragment boundaries are hit by the appended sample.
    ///
    /// - Throws:
    ///   - ``CMAFWriterError/sampleInvalid(reason:)`` for invalid
    ///     sample metadata (track ID mismatch, oversize sample).
    ///   - ``CMAFWriterError/encryptionParametersMissing(track:)``
    ///     when the track is encrypted but the sample carries no
    ///     encryption metadata.
    ///   - ``CMAFWriterError/encryptionIVSizeMismatch(declared:actual:)``
    ///     when the per-sample IV size does not match
    ///     `tenc.defaultPerSampleIVSize`.
    ///   - ``CMAFWriterError/cmafConformanceViolation(rule:)`` when
    ///     the runtime SAP check fails (a video fragment is opened
    ///     by a non-sync sample).
    ///   - ``CMAFWriterError/configurationInvalid(reason:)`` when the
    ///     writer has already been ``finalize()``-ed.
    public func appendSample(
        _ sample: CMAFSampleInput,
        toTrack trackID: UInt32
    ) throws -> [CMAFFragmentSegment] {
        guard state != .finalized else {
            throw CMAFWriterError.configurationInvalid(
                reason: "writer is finalized; further samples cannot be appended"
            )
        }
        guard trackID == configuration.trackID else {
            throw CMAFWriterError.sampleInvalid(
                reason:
                    "sample track ID \(trackID) does not match configured "
                    + "track ID \(configuration.trackID)"
            )
        }
        if sample.bytes.count > Int(UInt32.max) {
            throw CMAFWriterError.sampleSizeOverflow(
                sampleNumber: UInt32(pendingSamples.count)
            )
        }
        if let encryptionParams = configuration.encryptionParameters {
            guard let meta = sample.encryption else {
                throw CMAFWriterError.encryptionParametersMissing(track: trackID)
            }
            let declaredIVSize = encryptionParams.defaultPerSampleIVSize.rawValue
            if UInt8(meta.initializationVector.count) != declaredIVSize {
                throw CMAFWriterError.encryptionIVSizeMismatch(
                    declared: declaredIVSize,
                    actual: UInt8(meta.initializationVector.count)
                )
            }
        }

        if pendingSamples.isEmpty {
            pendingDecodeTime = nextBaseMediaDecodeTime
            currentChunkDecodeTime = pendingDecodeTime
            // Runtime SAP check (CMAF §7.3.5.1): the first sample of
            // every video media segment must be a sync sample.
            if configuration.kind == .video && !sample.flags.isSyncSample {
                throw CMAFWriterError.cmafConformanceViolation(
                    rule:
                        "CMAF \u{00A7}7.3.5.1: every video media segment must begin "
                        + "at a Stream Access Point (the first sample of a video "
                        + "fragment must be a sync sample)"
                )
            }
        }

        let metadata = FragmentSampleMetadata(
            sampleSize: UInt32(sample.bytes.count),
            durationInTimescale: sample.durationInTimescale,
            compositionTimeOffset: sample.compositionTimeOffset,
            flags: sample.flags
        )
        let writerSample = SegmentByteAssembler.WriterSample(
            metadata: metadata,
            bytes: sample.bytes,
            encryption: sample.encryption
        )
        pendingSamples.append(writerSample)
        pendingDurationInTimescale += UInt64(sample.durationInTimescale)
        samplesInCurrentChunk.append(writerSample)
        currentChunkDurationInTimescale += UInt64(sample.durationInTimescale)

        state = .openFragment(
            decodeTime: pendingDecodeTime,
            samples: pendingSamples.count
        )

        // First, evaluate the partial-chunk boundary. A chunk close
        // happens INSIDE the current fragment, no fragment emission.
        if requiresPartialChunking,
            try shouldClosePartialChunk(
                currentSampleIsSync: sample.flags.isSyncSample
            )
        {
            try emitCurrentPartialChunk()
        }

        // Now evaluate the fragment boundary.
        if try shouldCloseFragment(currentSampleIsSync: sample.flags.isSyncSample) {
            if let segment = try emitCurrentFragment() {
                return [segment]
            }
        }
        return []
    }

    /// Attach an `emsg` to be emitted at the start of the *next*
    /// fragment, before its `moof`. Used for DASH event signalling.
    public func attachEventMessage(_ message: EventMessageBox) {
        attachedEventMessages.append(message)
    }

    /// Force-finalise the current fragment and emit the segment, if
    /// any samples have been appended.
    public func finalizeCurrentFragment() throws -> CMAFFragmentSegment? {
        guard state != .finalized else {
            throw CMAFWriterError.configurationInvalid(
                reason: "writer is finalized"
            )
        }
        return try emitCurrentFragment()
    }

    /// Finalise the writer: emit any pending fragment and transition
    /// to ``State/finalized``. After this call, every mutating method
    /// throws ``CMAFWriterError/configurationInvalid(reason:)``.
    @discardableResult
    public func finalize() throws -> [CMAFFragmentSegment] {
        guard state != .finalized else {
            throw CMAFWriterError.configurationInvalid(
                reason: "writer already finalized"
            )
        }
        var emitted: [CMAFFragmentSegment] = []
        if let segment = try emitCurrentFragment() {
            emitted.append(segment)
        }
        state = .finalized
        return emitted
    }

    /// `deinit` documents the contract: any pending fragment is
    /// dropped. Consumers should always call ``finalize()`` to
    /// recover the trailing fragment. No async work happens here —
    /// actor isolation forbids it.
    deinit {
        // Intentionally empty. The pending fragment is lost if the
        // consumer did not call `finalize()`. Documented as the
        // contract above.
    }

    // MARK: - Boundary evaluation

    private func shouldCloseFragment(currentSampleIsSync: Bool) throws -> Bool {
        switch fragmentBoundary {
        case .sampleCount(let target):
            return UInt32(pendingSamples.count) >= target
        case .durationSeconds(let seconds):
            let thresholdTicks = UInt64(seconds * Double(configuration.timescale))
            return pendingDurationInTimescale >= thresholdTicks
        case .onSyncSample:
            return pendingSamples.count > 1 && currentSampleIsSync
        case .custom(let predicate):
            return predicate(
                CMAFFragmentState(
                    currentFragmentSampleCount: UInt32(pendingSamples.count),
                    currentFragmentDurationInTimescale: pendingDurationInTimescale,
                    timescale: configuration.timescale,
                    isCurrentSampleSync: currentSampleIsSync
                ))
        }
    }

    private func shouldClosePartialChunk(currentSampleIsSync: Bool) throws -> Bool {
        guard let boundary = partialChunkBoundary else { return false }
        switch boundary {
        case .sampleCount(let target):
            return UInt32(samplesInCurrentChunk.count) >= target
        case .durationSeconds(let seconds):
            let thresholdTicks = UInt64(seconds * Double(configuration.timescale))
            return currentChunkDurationInTimescale >= thresholdTicks
        case .perSample:
            return !samplesInCurrentChunk.isEmpty
        }
    }

    // MARK: - Fragment + chunk emission

    private func emitCurrentFragment() throws -> CMAFFragmentSegment? {
        guard !pendingSamples.isEmpty else { return nil }

        let cutBeforeLast: Bool
        if case .onSyncSample = fragmentBoundary,
            pendingSamples.count > 1,
            pendingSamples.last?.metadata.flags.isSyncSample == true,
            state != .finalized
        {
            cutBeforeLast = true
        } else {
            cutBeforeLast = false
        }

        var samplesToEmit = pendingSamples
        var holdover: SegmentByteAssembler.WriterSample?
        var durationToEmit = pendingDurationInTimescale
        if cutBeforeLast, let last = pendingSamples.last {
            samplesToEmit.removeLast()
            holdover = last
            durationToEmit -= UInt64(last.metadata.durationInTimescale)
        }

        // Drain any in-flight partial chunk so the fragment closes
        // on a chunk boundary.
        if requiresPartialChunking && !samplesInCurrentChunk.isEmpty && holdover == nil {
            try emitCurrentPartialChunk()
        }

        let fragmentBytes: Data
        let chunks: [CMAFPartialChunk]?
        if requiresPartialChunking {
            // The fragment bytes are the concatenation of every
            // chunk emitted for it.
            chunks = pendingFragmentChunks
            fragmentBytes = pendingFragmentChunks.reduce(into: Data()) {
                $0.append($1.bytes)
            }
        } else {
            let assembled = try SegmentByteAssembler.emitFragment(
                trackID: configuration.trackID,
                sequenceNumber: nextSequenceNumber,
                baseMediaDecodeTime: pendingDecodeTime,
                samples: samplesToEmit,
                encryption: configuration.encryptionParameters
            )
            nextSequenceNumber += 1
            fragmentBytes = assembled.bytes
            chunks = nil
        }

        var assembled = Data()
        let styp = BrandComposer.makeSegmentTypeBox(configurations: [configuration])
        var stypWriter = BinaryWriter()
        styp.encode(to: &stypWriter)
        assembled.append(stypWriter.data)

        for event in attachedEventMessages {
            var ew = BinaryWriter()
            event.encode(to: &ew)
            assembled.append(ew.data)
        }
        attachedEventMessages.removeAll(keepingCapacity: true)

        if emitProducerReferenceTime {
            let prft = ProducerReferenceTimeBox(
                version: 1,
                referenceTrackID: configuration.trackID,
                ntpTimestamp: ntpTimestampNow(),
                mediaDecodeTime: pendingDecodeTime
            )
            var pw = BinaryWriter()
            prft.encode(to: &pw)
            assembled.append(pw.data)
        }

        if emitSegmentIndex {
            let sidx = makeSegmentIndex(
                fragmentByteSize: fragmentBytes.count,
                durationInTimescale: durationToEmit,
                isSyncStart: samplesToEmit.first?.metadata.flags.isSyncSample ?? false
            )
            var sw = BinaryWriter()
            sidx.encode(to: &sw)
            assembled.append(sw.data)
        }

        assembled.append(fragmentBytes)

        let resolvedSequenceNumber: UInt32
        if let firstChunkCount = chunks?.count, firstChunkCount > 0 {
            resolvedSequenceNumber = nextSequenceNumber - UInt32(firstChunkCount)
        } else {
            resolvedSequenceNumber =
                nextSequenceNumber - (requiresPartialChunking ? 0 : 1)
        }
        let segment = CMAFFragmentSegment(
            bytes: assembled,
            sequenceNumber: resolvedSequenceNumber,
            baseMediaDecodeTime: pendingDecodeTime,
            durationInTimescale: durationToEmit,
            isStreamAccessPoint: samplesToEmit.first?.metadata.flags.isSyncSample ?? false,
            partialChunks: chunks
        )

        // Reset for next fragment.
        nextBaseMediaDecodeTime = pendingDecodeTime + durationToEmit
        pendingSamples.removeAll(keepingCapacity: true)
        pendingDurationInTimescale = 0
        pendingFragmentChunks.removeAll(keepingCapacity: true)
        samplesInCurrentChunk.removeAll(keepingCapacity: true)
        currentChunkDurationInTimescale = 0
        currentChunkDecodeTime = nextBaseMediaDecodeTime

        if let holdoverSample = holdover {
            pendingSamples.append(holdoverSample)
            pendingDecodeTime = nextBaseMediaDecodeTime
            pendingDurationInTimescale = UInt64(holdoverSample.metadata.durationInTimescale)
            samplesInCurrentChunk.append(holdoverSample)
            currentChunkDurationInTimescale =
                UInt64(holdoverSample.metadata.durationInTimescale)
            state = .openFragment(decodeTime: pendingDecodeTime, samples: 1)
        } else {
            state = .empty
        }
        return segment
    }

    private func emitCurrentPartialChunk() throws {
        guard !samplesInCurrentChunk.isEmpty else { return }
        let chunkIndex = UInt32(pendingFragmentChunks.count)
        let isIndependent =
            chunkIndex == 0
            || samplesInCurrentChunk.first?.metadata.flags.isSyncSample == true

        let assembled = try SegmentByteAssembler.emitFragment(
            trackID: configuration.trackID,
            sequenceNumber: nextSequenceNumber,
            baseMediaDecodeTime: currentChunkDecodeTime,
            samples: samplesInCurrentChunk,
            encryption: configuration.encryptionParameters
        )
        nextSequenceNumber += 1

        let chunk = CMAFPartialChunk(
            bytes: assembled.bytes,
            chunkIndex: chunkIndex,
            isIndependent: isIndependent,
            durationInTimescale: currentChunkDurationInTimescale
        )
        pendingFragmentChunks.append(chunk)

        currentChunkDecodeTime += currentChunkDurationInTimescale
        samplesInCurrentChunk.removeAll(keepingCapacity: true)
        currentChunkDurationInTimescale = 0
    }

    // MARK: - Helpers

    private func makeSegmentIndex(
        fragmentByteSize: Int,
        durationInTimescale: UInt64,
        isSyncStart: Bool
    ) -> SegmentIndexBox {
        let entry = SegmentIndexEntry(
            referenceType: false,
            referencedSize: UInt32(clamping: fragmentByteSize),
            subsegmentDuration: UInt32(clamping: durationInTimescale),
            startsWithSAP: isSyncStart,
            sapType: isSyncStart ? 1 : 0,
            sapDeltaTime: 0
        )
        return SegmentIndexBox(
            version: 1,
            referenceID: configuration.trackID,
            timescale: configuration.timescale,
            earliestPresentationTime: pendingDecodeTime,
            firstOffset: 0,
            table: SegmentIndexTable(entries: [entry])
        )
    }

    /// Current NTP timestamp (32 bits seconds since 1900 + 32 bits
    /// fractional seconds). Returns 0 when the platform clock cannot
    /// be sourced; consumers needing precise wall-clock semantics
    /// should override via a future injection point.
    private func ntpTimestampNow() -> UInt64 {
        let secondsBetween1900And1970: UInt64 = 2_208_988_800
        let now = Date().timeIntervalSince1970
        let secondsPart = UInt64(now)
        let fractionPart = UInt32((now - Double(secondsPart)) * Double(UInt32.max))
        return (UInt64(secondsBetween1900And1970 + secondsPart) << 32)
            | UInt64(fractionPart)
    }

}
