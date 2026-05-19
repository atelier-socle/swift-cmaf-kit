// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FragmentTreeBuilder + FragmentInvariance
//
// Reference: ISO/IEC 14496-12 §8.8 (MovieFragmentBox group), §8.8.7
// (TrackFragmentHeaderBox), §8.8.8 (TrackRunBox).
//
// Composes the `moof` subtree for a single CMAF fragment. The
// `FragmentInvariance` helper detects which per-sample fields are
// constant across the fragment so they can be hoisted into
// `tfhd.default_*` and omitted from `trun`. This keeps the on-wire
// output minimal per the CMAF guidance.

import Foundation

/// One sample's worth of input to the fragment builder. The bytes
/// are not stored here — they live in `mdat`. Only the metadata that
/// drives `trun` / `tfhd` flag selection lives in this value.
internal struct FragmentSampleMetadata: Sendable, Equatable {
    let sampleSize: UInt32
    let durationInTimescale: UInt32
    let compositionTimeOffset: Int32
    let flags: SampleFlags
}

/// Result of the field-invariance scan: which fields are constant
/// across the fragment and what the constant values are.
internal struct FragmentInvariance: Sendable, Equatable {
    let defaultSampleDuration: UInt32?
    let defaultSampleSize: UInt32?
    let defaultSampleFlags: UInt32?
    let firstSampleFlagsDiffer: Bool
    let firstSampleFlags: UInt32
    let anyCompositionOffsetNonZero: Bool
    let anyCompositionOffsetNegative: Bool

    /// Scan the fragment's samples for per-sample-field constancy.
    static func scan(samples: [FragmentSampleMetadata]) -> FragmentInvariance {
        guard let first = samples.first else {
            return FragmentInvariance(
                defaultSampleDuration: nil,
                defaultSampleSize: nil,
                defaultSampleFlags: nil,
                firstSampleFlagsDiffer: false,
                firstSampleFlags: 0,
                anyCompositionOffsetNonZero: false,
                anyCompositionOffsetNegative: false
            )
        }

        var allDurationEqual = true
        var allSizeEqual = true
        var allFlagsEqual = true
        var anyCTSNonZero = false
        var anyCTSNegative = false
        let firstFlagsRaw = first.flags.rawValue

        for sample in samples.dropFirst() {
            if sample.durationInTimescale != first.durationInTimescale {
                allDurationEqual = false
            }
            if sample.sampleSize != first.sampleSize {
                allSizeEqual = false
            }
            if sample.flags.rawValue != firstFlagsRaw {
                allFlagsEqual = false
            }
            if sample.compositionTimeOffset != 0 {
                anyCTSNonZero = true
                if sample.compositionTimeOffset < 0 {
                    anyCTSNegative = true
                }
            }
        }
        if first.compositionTimeOffset != 0 {
            anyCTSNonZero = true
            if first.compositionTimeOffset < 0 {
                anyCTSNegative = true
            }
        }

        // Check the "first-sample-flags-present" case: the first sample
        // has different flags from the rest, and the rest are equal
        // among themselves.
        var firstFlagsDiffer = false
        if samples.count > 1, !allFlagsEqual {
            let restFirst = samples[1].flags.rawValue
            var restAllEqual = true
            for sample in samples.dropFirst() where sample.flags.rawValue != restFirst {
                restAllEqual = false
                break
            }
            if restAllEqual && firstFlagsRaw != restFirst {
                firstFlagsDiffer = true
            }
        }

        let defaultDur = allDurationEqual ? first.durationInTimescale : nil
        let defaultSize = allSizeEqual ? first.sampleSize : nil

        // Default flags emit only when all samples share flags, OR when
        // only the first differs (in which case we set defaults to the
        // "rest" value and surface `first_sample_flags` in `trun`).
        let defaultFlags: UInt32?
        if allFlagsEqual {
            defaultFlags = firstFlagsRaw
        } else if firstFlagsDiffer {
            defaultFlags = samples[1].flags.rawValue
        } else {
            defaultFlags = nil
        }

        return FragmentInvariance(
            defaultSampleDuration: defaultDur,
            defaultSampleSize: defaultSize,
            defaultSampleFlags: defaultFlags,
            firstSampleFlagsDiffer: firstFlagsDiffer,
            firstSampleFlags: firstFlagsRaw,
            anyCompositionOffsetNonZero: anyCTSNonZero,
            anyCompositionOffsetNegative: anyCTSNegative
        )
    }
}

/// Internal helper composing the `moof` for a single fragment of one
/// track.
internal enum FragmentTreeBuilder {

    /// Build `moof` for a single-track fragment plus the metadata
    /// needed by the caller to assemble `mdat` and patch the data
    /// offset back into `trun.data_offset`.
    ///
    /// - Parameters:
    ///   - trackID: the parent track's identifier.
    ///   - sequenceNumber: 1-based fragment sequence number.
    ///   - baseMediaDecodeTime: `tfdt.baseMediaDecodeTime`.
    ///   - samples: per-sample metadata (size + timing + flags).
    ///   - mdatPayloadOffset: byte offset of the first sample inside
    ///     the eventual `mdat` body relative to the start of `moof`.
    ///     `moof.size + 8` (mdat header) plus zero for the first
    ///     sample. The writer sets this value at finalisation time.
    /// - Returns: the composed `moof` plus the resolved invariance.
    static func makeMovieFragment(
        trackID: UInt32,
        sequenceNumber: UInt32,
        baseMediaDecodeTime: UInt64,
        samples: [FragmentSampleMetadata],
        dataOffsetFromMoof: Int32
    ) -> (MovieFragmentBox, FragmentInvariance) {
        let invariance = FragmentInvariance.scan(samples: samples)

        let mfhd = MovieFragmentHeaderBox(sequenceNumber: sequenceNumber)

        let tfhd = TrackFragmentHeaderBox(
            trackID: trackID,
            defaultSampleDuration: invariance.defaultSampleDuration,
            defaultSampleSize: invariance.defaultSampleSize,
            defaultSampleFlags: invariance.defaultSampleFlags
        )

        let tfdt = TrackFragmentDecodeTimeBox(baseMediaDecodeTime: baseMediaDecodeTime)

        let trun = makeTrackRun(
            samples: samples,
            invariance: invariance,
            dataOffsetFromMoof: dataOffsetFromMoof
        )

        let trafHeader = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
        let traf = TrackFragmentBox(
            header: trafHeader,
            children: [tfhd, tfdt, trun]
        )

        let moofHeader = ISOBoxHeader(type: "moof", size: 0, headerSize: 8)
        let moof = MovieFragmentBox(header: moofHeader, children: [mfhd, traf])
        return (moof, invariance)
    }

    /// Build the `trun` from the fragment's samples and the detected
    /// invariance.
    private static func makeTrackRun(
        samples: [FragmentSampleMetadata],
        invariance: FragmentInvariance,
        dataOffsetFromMoof: Int32
    ) -> TrackRunBox {
        var perSampleFlags: UInt32 = 0
        if invariance.defaultSampleDuration == nil {
            perSampleFlags |= TrackRunTable.flagSampleDuration
        }
        if invariance.defaultSampleSize == nil {
            perSampleFlags |= TrackRunTable.flagSampleSize
        }
        // Per-sample flags are emitted only when neither tfhd default
        // nor first-sample-flags-present covers them.
        let needsPerSampleFlags =
            invariance.defaultSampleFlags == nil && !invariance.firstSampleFlagsDiffer
        if needsPerSampleFlags {
            perSampleFlags |= TrackRunTable.flagSampleFlags
        }
        if invariance.anyCompositionOffsetNonZero {
            perSampleFlags |= TrackRunTable.flagSampleCompositionTimeOffsets
        }

        let version: UInt8 = invariance.anyCompositionOffsetNegative ? 1 : 0

        var entries: [TrackRunEntry] = []
        entries.reserveCapacity(samples.count)
        for sample in samples {
            entries.append(
                TrackRunEntry(
                    sampleDuration: invariance.defaultSampleDuration == nil
                        ? sample.durationInTimescale : nil,
                    sampleSize: invariance.defaultSampleSize == nil
                        ? sample.sampleSize : nil,
                    sampleFlags: needsPerSampleFlags ? sample.flags.rawValue : nil,
                    sampleCompositionTimeOffset: invariance.anyCompositionOffsetNonZero
                        ? Int64(sample.compositionTimeOffset) : nil
                ))
        }
        let table = TrackRunTable(
            entries: entries,
            perSampleFlags: perSampleFlags,
            version: version
        )
        return TrackRunBox(
            version: version,
            dataOffset: dataOffsetFromMoof,
            firstSampleFlags: invariance.firstSampleFlagsDiffer
                ? invariance.firstSampleFlags : nil,
            table: table
        )
    }
}
