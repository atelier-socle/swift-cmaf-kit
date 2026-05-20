// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Shared helpers for the 30 reader round-trip scenarios. Each
// scenario takes a track configuration and an explicit sample
// list, emits them through ``CMAFInitSegmentWriter`` +
// ``CMAFMediaSegmentWriter``, then reads the bytes back through
// ``CMAFInitSegmentReader`` + ``CMAFMediaSegmentReader`` and
// asserts byte-perfect equivalence: per-sample `bytes`, `flags`,
// `durationInTimescale`, `compositionTimeOffset`, and (when
// encrypted) `initializationVector`.

import Foundation
import Testing

@testable import CMAFKit

internal enum RoundTripFixtures {

    /// Setup for a single-track round-trip scenario.
    internal struct SingleTrackSetup {
        let configuration: CMAFTrackConfiguration
        let samples: [CMAFSampleInput]
        let fragmentBoundary: CMAFFragmentBoundary
        let partialChunkBoundary: CMAFPartialChunkBoundary?
        let emitSegmentIndex: Bool
        let emitProducerReferenceTime: Bool

        init(
            configuration: CMAFTrackConfiguration,
            samples: [CMAFSampleInput],
            fragmentBoundary: CMAFFragmentBoundary = .sampleCount(2),
            partialChunkBoundary: CMAFPartialChunkBoundary? = nil,
            emitSegmentIndex: Bool = false,
            emitProducerReferenceTime: Bool = false
        ) {
            self.configuration = configuration
            self.samples = samples
            self.fragmentBoundary = fragmentBoundary
            self.partialChunkBoundary = partialChunkBoundary
            self.emitSegmentIndex = emitSegmentIndex
            self.emitProducerReferenceTime = emitProducerReferenceTime
        }
    }

    /// Result of a round-trip: the recovered init segment + the
    /// recovered samples grouped per track.
    internal struct RoundTripResult {
        let recoveredTracks: [CMAFTrackConfiguration]
        let recoveredSamples: [CMAFParsedSample]
        let movieTimescale: UInt32
        let majorBrand: FourCC
        let compatibleBrands: [FourCC]
    }

    /// Run a single-track scenario end-to-end and return the
    /// recovered tracks + samples.
    static func runSingleTrack(
        _ setup: SingleTrackSetup
    ) async throws -> RoundTripResult {
        let initBytes = try CMAFInitSegmentWriter(
            configurations: [setup.configuration]
        ).emit()
        let writer = try CMAFMediaSegmentWriter(
            configuration: setup.configuration,
            fragmentBoundary: setup.fragmentBoundary,
            partialChunkBoundary: setup.partialChunkBoundary,
            emitSegmentIndex: setup.emitSegmentIndex,
            emitProducerReferenceTime: setup.emitProducerReferenceTime
        )
        var emitted: [CMAFFragmentSegment] = []
        for sample in setup.samples {
            emitted += try await writer.appendSample(
                sample, toTrack: setup.configuration.trackID
            )
        }
        emitted += try await writer.finalize()
        var tencMap: [UInt32: TrackEncryptionBox] = [:]
        if let params = setup.configuration.encryptionParameters {
            tencMap[setup.configuration.trackID] = params.makeTrackEncryptionBox()
        }
        return try await readBack(
            initBytes: initBytes,
            mediaSegments: emitted.map(\.bytes),
            tenc: tencMap
        )
    }

    /// Read back the supplied init + media segment bytes via the
    /// reader actor stack. Returns the recovered tracks + samples.
    static func readBack(
        initBytes: Data,
        mediaSegments: [Data],
        tenc: [UInt32: TrackEncryptionBox] = [:]
    ) async throws -> RoundTripResult {
        let initReader = try await CMAFInitSegmentReader(bytes: initBytes)
        let tracks = initReader.tracks()
        let mediaReader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: tracks,
            movieTimescale: initReader.movieTimescale(),
            trackEncryptionContexts: tenc
        )
        var samples: [CMAFParsedSample] = []
        for bytes in mediaSegments {
            let segment = try await mediaReader.appendSegmentBytes(bytes)
            samples.append(contentsOf: segment.samples)
        }
        try await mediaReader.finalize()
        return RoundTripResult(
            recoveredTracks: tracks,
            recoveredSamples: samples,
            movieTimescale: initReader.movieTimescale(),
            majorBrand: initReader.majorBrand(),
            compatibleBrands: initReader.compatibleBrands()
        )
    }

    // MARK: - Sample factories

    /// Builds a video sample series where every even-indexed sample
    /// (0, 2, 4, …) is a sync sample. The CMAF SAP rule
    /// (\u{00A7}7.3.5.1) requires the first sample of every fragment
    /// to be a sync sample; this cadence matches the default
    /// fragment boundary `.sampleCount(2)` used across the
    /// scenarios.
    static func videoSamples(
        count: Int,
        size: Int = 1024,
        duration: UInt32 = 3000,
        seedByte: UInt8 = 0xAB
    ) -> [CMAFSampleInput] {
        var out: [CMAFSampleInput] = []
        out.reserveCapacity(count)
        for index in 0..<count {
            let byte: UInt8 = seedByte &+ UInt8(index & 0x0F)
            let isSync = index % 2 == 0
            let flags: SampleFlags = isSync ? .syncSample : .nonSyncSample
            out.append(
                CMAFSampleInput(
                    bytes: Data(repeating: byte, count: size),
                    durationInTimescale: duration,
                    flags: flags
                )
            )
        }
        return out
    }

    static func allSyncSamples(
        count: Int,
        size: Int = 1024,
        duration: UInt32 = 3000
    ) -> [CMAFSampleInput] {
        (0..<count).map { index in
            CMAFSampleInput(
                bytes: Data(repeating: 0x77 &+ UInt8(index & 0x0F), count: size),
                durationInTimescale: duration,
                flags: .syncSample
            )
        }
    }

    /// Encrypted variant of ``videoSamples(count:size:duration:seedByte:)``
    /// — also marks every even-indexed sample as sync for SAP
    /// conformance.
    static func encryptedSamples(
        count: Int,
        size: Int = 1024,
        duration: UInt32 = 3000,
        ivSize: Int,
        seedByte: UInt8 = 0xCC
    ) -> [CMAFSampleInput] {
        var out: [CMAFSampleInput] = []
        out.reserveCapacity(count)
        for index in 0..<count {
            let payloadByte: UInt8 = seedByte &+ UInt8(index & 0x0F)
            let ivByte: UInt8 = 0x11 &+ UInt8(index & 0x0F)
            let iv: Data =
                ivSize == 0
                ? Data()
                : Data(repeating: ivByte, count: ivSize)
            let bytes = Data(repeating: payloadByte, count: size)
            let flags: SampleFlags = index % 2 == 0 ? .syncSample : .nonSyncSample
            out.append(
                CMAFSampleInput(
                    bytes: bytes,
                    durationInTimescale: duration,
                    flags: flags,
                    encryption: CMAFSampleInput.EncryptionMetadata(
                        initializationVector: iv
                    )
                )
            )
        }
        return out
    }
}

// MARK: - Assertion helpers

internal enum RoundTripAssertions {

    /// Assert per-sample byte equality, plus flags, duration,
    /// composition-time offset, and encryption metadata.
    static func assertEquivalence(
        original: [CMAFSampleInput],
        parsed: [CMAFParsedSample],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            parsed.count == original.count,
            "round-trip sample count mismatch: parsed=\(parsed.count) original=\(original.count)",
            sourceLocation: sourceLocation
        )
        for index in 0..<min(parsed.count, original.count) {
            let read = parsed[index]
            let written = original[index]
            #expect(
                read.bytes == written.bytes,
                "sample \(index) byte mismatch (size read=\(read.bytes.count) written=\(written.bytes.count))",
                sourceLocation: sourceLocation
            )
            #expect(
                read.durationInTimescale == written.durationInTimescale,
                "sample \(index) duration mismatch",
                sourceLocation: sourceLocation
            )
            #expect(
                read.compositionTimeOffset == written.compositionTimeOffset,
                "sample \(index) composition-time offset mismatch",
                sourceLocation: sourceLocation
            )
            #expect(
                read.flags.isSyncSample == written.flags.isSyncSample,
                "sample \(index) sync-sample flag mismatch",
                sourceLocation: sourceLocation
            )
            if let writtenEnc = written.encryption {
                // For cbcs with a constant IV the per-sample IV is
                // empty by design and the senc box may be absent —
                // a nil parsed encryption is therefore acceptable
                // when the written IV is also empty.
                let writtenIV = writtenEnc.initializationVector
                let readIV = read.encryption?.initializationVector
                if writtenIV.isEmpty {
                    let ok = readIV == nil || readIV == Data()
                    #expect(
                        ok,
                        "sample \(index) IV mismatch (constant-IV scheme)",
                        sourceLocation: sourceLocation
                    )
                } else {
                    #expect(
                        readIV == writtenIV,
                        "sample \(index) IV mismatch",
                        sourceLocation: sourceLocation
                    )
                }
            }
        }
        // Decode-time monotonicity per track.
        var lastByTrack: [UInt32: UInt64] = [:]
        for sample in parsed {
            if let last = lastByTrack[sample.trackID] {
                #expect(
                    sample.decodeTime >= last,
                    "decode time regressed on track \(sample.trackID)",
                    sourceLocation: sourceLocation
                )
            }
            lastByTrack[sample.trackID] = sample.decodeTime
        }
    }

    /// Assert that the recovered tracks match the writer-side track
    /// list shape: same count, same kinds, same codecs, encryption
    /// scheme alignment.
    static func assertTrackShape(
        recovered: [CMAFTrackConfiguration],
        original: [CMAFTrackConfiguration],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            recovered.count == original.count,
            "track count mismatch",
            sourceLocation: sourceLocation
        )
        for (read, written) in zip(recovered, original) {
            assertTrackPair(
                read: read, written: written, sourceLocation: sourceLocation
            )
        }
    }

    private static func assertTrackPair(
        read: CMAFTrackConfiguration,
        written: CMAFTrackConfiguration,
        sourceLocation: SourceLocation
    ) {
        #expect(read.kind == written.kind, sourceLocation: sourceLocation)
        #expect(read.trackID == written.trackID, sourceLocation: sourceLocation)
        let readVideo = read.videoFields?.codec
        let writtenVideo = written.videoFields?.codec
        #expect(readVideo == writtenVideo, sourceLocation: sourceLocation)
        let readAudio = read.audioFields?.codec
        let writtenAudio = written.audioFields?.codec
        #expect(readAudio == writtenAudio, sourceLocation: sourceLocation)
        let readScheme = read.encryptionParameters?.scheme
        let writtenScheme = written.encryptionParameters?.scheme
        #expect(readScheme == writtenScheme, sourceLocation: sourceLocation)
        let readKID = read.encryptionParameters?.defaultKID.rawBytes
        let writtenKID = written.encryptionParameters?.defaultKID.rawBytes
        #expect(readKID == writtenKID, sourceLocation: sourceLocation)
    }
}
