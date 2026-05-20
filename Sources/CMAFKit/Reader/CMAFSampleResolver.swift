// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFSampleResolver (internal)
//
// Reference: ISO/IEC 14496-12 §8.8.7 (TrackFragmentHeaderBox) and
// §8.8.8 (TrackRunBox), §8.8.13 (TrackFragmentDecodeTimeBox);
// ISO/IEC 23001-7 §7.2 (SampleEncryptionBox).
//
// Walks one `moof+mdat` pair (or one LL-HLS partial chunk) and
// produces typed ``CMAFParsedSample`` instances. Encrypted samples
// surface per-sample IVs + subsample partitions via the explicit
// senc-dispatch path: when the reader meets a `senc` opaque box
// inside a `traf`, it re-parses it using the track's
// ``TrackEncryptionBox`` to supply `ivSize` context. This keeps
// ``BoxRegistry`` pure (no context parameter) while delivering the
// fully-typed result.

import Foundation

internal enum CMAFSampleResolver {

    /// Result of walking one fragment: every sample emitted plus
    /// metadata the higher-level reader needs for cross-fragment
    /// validation (mfhd sequence, first-track baseMediaDecodeTime,
    /// first-sample sync flag).
    internal struct FragmentWalk: Sendable, Equatable {
        let samples: [CMAFParsedSample]
        let mfhdSequenceNumber: UInt32
        /// Per-track `tfdt.baseMediaDecodeTime` recorded by this
        /// fragment. The key is `tfhd.trackID`.
        let baseMediaDecodeTimes: [UInt32: UInt64]
        let firstSampleIsSyncSample: Bool
    }

    /// Walk one `moof`+`mdat` pair.
    ///
    /// - Parameters:
    ///   - moof: the parsed ``MovieFragmentBox``.
    ///   - mdat: the parsed ``MediaDataBox`` that follows `moof`.
    ///   - trackEncryptionContexts: the track-encryption boxes from
    ///     the init segment, keyed by track ID. The reader uses
    ///     these to supply `ivSize` for explicit `senc` parsing.
    static func walk(
        moof: MovieFragmentBox,
        mdat: MediaDataBox,
        trackEncryptionContexts: [UInt32: TrackEncryptionBox]
    ) async throws -> FragmentWalk {
        guard
            let mfhd = moof.children
                .compactMap({ $0 as? MovieFragmentHeaderBox })
                .first
        else {
            throw CMAFReaderError.missingMandatoryBox(parent: "moof", missing: "mfhd")
        }

        var allSamples: [CMAFParsedSample] = []
        var baseMediaDecodeTimes: [UInt32: UInt64] = [:]

        for traf in moof.children.compactMap({ $0 as? TrackFragmentBox }) {
            guard
                let tfhd = traf.children
                    .compactMap({ $0 as? TrackFragmentHeaderBox })
                    .first
            else {
                throw CMAFReaderError.missingMandatoryBox(parent: "traf", missing: "tfhd")
            }
            let tfdt = traf.children
                .compactMap { $0 as? TrackFragmentDecodeTimeBox }
                .first
            let baseDecodeTime = tfdt?.baseMediaDecodeTime ?? 0
            baseMediaDecodeTimes[tfhd.trackID] = baseDecodeTime

            let trackEncryption = trackEncryptionContexts[tfhd.trackID]
            let sencSamples: [SampleEncryptionBox.SampleEncryptionEntry] =
                try await resolveSampleEncryption(
                    in: traf,
                    trackEncryption: trackEncryption
                )

            let truns = traf.children.compactMap { $0 as? TrackRunBox }
            var samplesEmittedSoFar = 0
            var accumulatedDuration: UInt64 = 0
            // `byteCursor` is mdat-relative: the first sample sits at
            // offset 0 inside ``MediaDataBox.data``. The trun
            // `dataOffset` field is moof-relative and used only by
            // the writer to anchor `moof+8`; the reader walks samples
            // sequentially through `mdat.data`.
            var byteCursor = 0
            for trun in truns {
                for index in 0..<trun.table.count {
                    let entry = trun.table[index]
                    let duration =
                        entry.sampleDuration
                        ?? tfhd.defaultSampleDuration
                        ?? 0
                    let size =
                        entry.sampleSize
                        ?? tfhd.defaultSampleSize
                        ?? 0
                    let ctsOffset = Int32(
                        truncatingIfNeeded: entry.sampleCompositionTimeOffset ?? 0
                    )
                    let flagsRaw = resolveSampleFlags(
                        index: index,
                        entry: entry,
                        trun: trun,
                        tfhd: tfhd
                    )
                    let bytes = try sliceMDAT(
                        mdat: mdat,
                        byteCursor: byteCursor,
                        sampleSize: Int(size),
                        trackID: tfhd.trackID,
                        sampleIndex: UInt32(samplesEmittedSoFar)
                    )
                    let encryptionMetadata =
                        sencSamples.indices
                            .contains(samplesEmittedSoFar)
                        ? sencEntryAsMetadata(sencSamples[samplesEmittedSoFar])
                        : nil
                    let sample = CMAFParsedSample(
                        trackID: tfhd.trackID,
                        bytes: bytes,
                        durationInTimescale: duration,
                        compositionTimeOffset: ctsOffset,
                        flags: SampleFlags(rawValue: flagsRaw),
                        encryption: encryptionMetadata,
                        decodeTime: baseDecodeTime + accumulatedDuration
                    )
                    allSamples.append(sample)
                    accumulatedDuration += UInt64(duration)
                    samplesEmittedSoFar += 1
                    byteCursor += Int(size)
                }
            }
        }

        let firstSync = allSamples.first?.flags.isSyncSample ?? false
        return FragmentWalk(
            samples: allSamples,
            mfhdSequenceNumber: mfhd.sequenceNumber,
            baseMediaDecodeTimes: baseMediaDecodeTimes,
            firstSampleIsSyncSample: firstSync
        )
    }

    // MARK: - Helpers

    private static func resolveSampleFlags(
        index: Int,
        entry: TrackRunEntry,
        trun: TrackRunBox,
        tfhd: TrackFragmentHeaderBox
    ) -> UInt32 {
        if let perSample = entry.sampleFlags {
            return perSample
        }
        if index == 0,
            (trun.flags & TrackRunBox.flagFirstSampleFlags) != 0,
            let firstFlags = trun.firstSampleFlags
        {
            return firstFlags
        }
        if let defaults = tfhd.defaultSampleFlags {
            return defaults
        }
        return 0
    }

    private static func sliceMDAT(
        mdat: MediaDataBox,
        byteCursor: Int,
        sampleSize: Int,
        trackID: UInt32,
        sampleIndex: UInt32
    ) throws -> Data {
        // The dataOffset is relative to the start of `moof` (when
        // tfhd.defaultBaseIsMoof). The bytes of the sample inside
        // mdat begin at `byteCursor - (moofSize + 8)`. CMAFKit's
        // reader instead reads the dataOffset as the byte position
        // within `mdat`'s body — the writer always emits
        // `dataOffsetFromMoof = moofSize + 8`, so within mdat the
        // first sample sits at offset 0. We therefore subtract the
        // implicit `moofSize + 8` from `byteCursor` ourselves;
        // because we lack moofSize here, we re-anchor by walking
        // forward through trun entries with byteCursor starting at
        // the trun's relative dataOffset value.
        //
        // The mdat body starts at 0 inside `mdat.data`. The
        // first sample's byte position there equals the trun
        // dataOffset minus (moofSize + 8). The caller passes the
        // raw trun dataOffset; we normalise to mdat-relative by
        // walking trun samples accumulating their sizes.
        //
        // Concretely: for the first sample of the first trun,
        // mdat-relative offset is 0; for subsequent samples it is
        // the running sum of preceding sample sizes. So
        // `byteCursor` here is already mdat-relative iff the
        // caller initialised it to 0 for the first sample. We
        // expect that; consumers of this resolver pass an
        // mdat-relative cursor.
        guard byteCursor + sampleSize <= mdat.data.count else {
            throw CMAFReaderError.sampleDataExceedsMDAT(
                trackID: trackID,
                sampleIndex: sampleIndex
            )
        }
        return mdat.data.subdata(in: byteCursor..<byteCursor + sampleSize)
    }

    private static func sencEntryAsMetadata(
        _ entry: SampleEncryptionBox.SampleEncryptionEntry
    ) -> CMAFSampleInput.EncryptionMetadata {
        CMAFSampleInput.EncryptionMetadata(
            initializationVector: entry.initializationVector,
            subsamples: entry.subsamples
        )
    }

    /// Re-parse the `senc` opaque box carried inside `traf` using
    /// the track's `tenc.defaultPerSampleIVSize` for context.
    ///
    /// Per the option B design, ``BoxRegistry`` does not register
    /// `senc` (it needs context). The registry's default fallback
    /// parses the box as ``UnknownBox``; the reader upgrades it
    /// here.
    private static func resolveSampleEncryption(
        in traf: TrackFragmentBox,
        trackEncryption: TrackEncryptionBox?
    ) async throws -> [SampleEncryptionBox.SampleEncryptionEntry] {
        guard let tenc = trackEncryption else { return [] }
        guard
            let sencUnknown = traf.children.compactMap({ $0 as? UnknownBox })
                .first(where: { $0.actualType == "senc" })
        else { return [] }
        var reader = BinaryReader(sencUnknown.payload)
        let registry = await BoxRegistry.defaultRegistry()
        let senc = try await SampleEncryptionBox.parse(
            reader: &reader,
            header: sencUnknown.header,
            registry: registry,
            ivSize: tenc.defaultPerSampleIVSize
        )
        return senc.samples
    }
}
