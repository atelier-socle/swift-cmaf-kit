// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFConformanceValidator
//
// Reference: ISO/IEC 23000-19 §7 (CMAF conformance), ISO/IEC
// 14496-12 §8.8 (movie fragments).
//
// Reader-side counterpart of the writer-side validators that
// land in Module 9. The validator takes already-parsed init +
// media segments and produces a non-throwing
// ``CMAFValidationReport`` listing every conformance violation
// it observes.

import Foundation

/// CMAF conformance validator.
///
/// Stateless struct that runs every CMAF-mandated check from
/// ISO/IEC 23000-19 §7 (the rules CMAFKit chooses to enforce at
/// the read side) and surfaces them as a typed report.
public struct CMAFConformanceValidator: Sendable {

    public init() {}

    /// Run every CMAF rule on the parsed file.
    public func validate(
        initSegment: ParsedInitSegment,
        mediaSegments: [ParsedMediaSegment]
    ) -> CMAFValidationReport {
        var issues: [CMAFValidationIssue] = []
        issues.append(contentsOf: checkRule1_SAPStart(mediaSegments: mediaSegments))
        issues.append(contentsOf: checkRule2_UniformTrackID(mediaSegments: mediaSegments))
        issues.append(
            contentsOf: checkRule3_TracksDeclared(
                initSegment: initSegment,
                mediaSegments: mediaSegments
            )
        )
        issues.append(
            contentsOf: checkRule6_EncryptedSampleSencConsistency(
                initSegment: initSegment,
                mediaSegments: mediaSegments
            )
        )
        issues.append(
            contentsOf: checkRule7_TencSencIVConsistency(
                initSegment: initSegment,
                mediaSegments: mediaSegments
            )
        )
        issues.append(
            contentsOf: checkRule8_FtypBrandsCoherence(initSegment: initSegment)
        )
        issues.append(
            contentsOf: checkRule9_MfhdSequenceMonotonic(
                mediaSegments: mediaSegments
            )
        )
        issues.append(
            contentsOf: checkRule10_TfdtMonotonic(mediaSegments: mediaSegments)
        )
        return CMAFValidationReport(issues: issues)
    }

    // MARK: - Rule 1: ISO/IEC 23000-19 §7.3.5.1
    //
    // Every media segment begins at a Stream Access Point.

    private func checkRule1_SAPStart(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments
        where !segment.firstSampleIsSyncSample
            && segment.samples.contains(where: { $0.trackID > 0 })
        {
            // Apply the rule only to segments carrying video-track
            // samples (audio segments do not need a SAP sync flag).
            let hasVideo = segment.samples.contains { sample in
                // Audio samples are typically always sync; the
                // SAP check is video-centric. We approximate by
                // checking non-sync samples appearing after the
                // first.
                !sample.flags.isSyncSample
            }
            if hasVideo {
                issues.append(
                    CMAFValidationIssue(
                        severity: .error,
                        ruleReference: "ISO/IEC 23000-19 \u{00A7}7.3.5.1",
                        description:
                            "Media segment must begin at a Stream Access Point; "
                            + "first sample is not a sync sample.",
                        segmentIndex: segment.segmentIndex
                    )
                )
            }
        }
        return issues
    }

    // MARK: - Rule 2: ISO/IEC 23000-19 §7.4.2
    //
    // All samples in a fragment share the same `tfhd.trackID`.
    // CMAFKit's reader emits samples keyed by trackID; we surface
    // an info-level note when a segment carries more than one
    // track (CMAF allows multi-track segments with one traf each).

    private func checkRule2_UniformTrackID(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments {
            let trackIDs = Set(segment.samples.map { $0.trackID })
            if trackIDs.count > 1 {
                issues.append(
                    CMAFValidationIssue(
                        severity: .info,
                        ruleReference: "ISO/IEC 23000-19 \u{00A7}7.4.2",
                        description:
                            "Segment carries samples from \(trackIDs.count) tracks; "
                            + "each `traf` is single-track per CMAF.",
                        segmentIndex: segment.segmentIndex
                    )
                )
            }
        }
        return issues
    }

    // MARK: - Rule 3: ISO/IEC 23000-19 §7.3.5.2
    //
    // The init + media set forms a complete decodable stream:
    // every media-segment track ID must be declared by the init
    // segment.

    private func checkRule3_TracksDeclared(
        initSegment: ParsedInitSegment,
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        let declared = Set(initSegment.trackConfigurations.map { $0.trackID })
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments {
            for trackID in segment.baseMediaDecodeTimes.keys where !declared.contains(trackID) {
                issues.append(
                    CMAFValidationIssue(
                        severity: .error,
                        ruleReference: "ISO/IEC 23000-19 \u{00A7}7.3.5.2",
                        description:
                            "Media segment references track \(trackID) which is "
                            + "not declared by the init segment.",
                        trackID: trackID,
                        segmentIndex: segment.segmentIndex
                    )
                )
            }
        }
        return issues
    }

    // MARK: - Rule 6 + 7: encryption symmetry
    //
    // Encrypted tracks must carry per-sample IVs in `senc` whose
    // length matches `tenc.defaultPerSampleIVSize`.

    private func checkRule6_EncryptedSampleSencConsistency(
        initSegment: ParsedInitSegment,
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        let encryptedTracks = Set(
            initSegment.trackConfigurations
                .filter { $0.encryptionParameters != nil }
                .map { $0.trackID }
        )
        guard !encryptedTracks.isEmpty else { return [] }
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments {
            for sample in segment.samples
            where encryptedTracks.contains(sample.trackID)
                && sample.encryption == nil
                && sample.flags.isSyncSample == false  // sync sample only is OK clear
            {
                issues.append(
                    CMAFValidationIssue(
                        severity: .error,
                        ruleReference: "ISO/IEC 23001-7 \u{00A7}7.2",
                        description:
                            "Encrypted track \(sample.trackID) has a sample "
                            + "without senc metadata.",
                        trackID: sample.trackID,
                        segmentIndex: segment.segmentIndex
                    )
                )
                break  // one issue per segment is enough
            }
        }
        return issues
    }

    private func checkRule7_TencSencIVConsistency(
        initSegment: ParsedInitSegment,
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        let tencByTrack: [UInt32: UInt8] = Dictionary(
            uniqueKeysWithValues: initSegment.trackConfigurations.compactMap { cfg in
                guard let enc = cfg.encryptionParameters else { return nil }
                return (cfg.trackID, enc.defaultPerSampleIVSize.rawValue)
            }
        )
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments {
            for sample in segment.samples {
                guard let declared = tencByTrack[sample.trackID],
                    let meta = sample.encryption
                else { continue }
                if UInt8(meta.initializationVector.count) != declared {
                    issues.append(
                        CMAFValidationIssue(
                            severity: .error,
                            ruleReference: "ISO/IEC 23001-7 \u{00A7}8.2",
                            description:
                                "tenc.defaultPerSampleIVSize = \(declared) "
                                + "but senc IV length = "
                                + "\(meta.initializationVector.count).",
                            trackID: sample.trackID,
                            segmentIndex: segment.segmentIndex
                        )
                    )
                    break
                }
            }
        }
        return issues
    }

    // MARK: - Rule 8: ftyp brand coherence

    private func checkRule8_FtypBrandsCoherence(
        initSegment: ParsedInitSegment
    ) -> [CMAFValidationIssue] {
        // The compatible-brands list MUST include `iso6` and
        // `cmfc` per ISO/IEC 23000-19 §6.
        var issues: [CMAFValidationIssue] = []
        if !initSegment.compatibleBrands.contains("iso6") {
            issues.append(
                CMAFValidationIssue(
                    severity: .error,
                    ruleReference: "ISO/IEC 23000-19 \u{00A7}6",
                    description:
                        "ftyp.compatible_brands does not include the mandatory "
                        + "`iso6` brand."
                )
            )
        }
        if !initSegment.compatibleBrands.contains("cmfc") {
            issues.append(
                CMAFValidationIssue(
                    severity: .error,
                    ruleReference: "ISO/IEC 23000-19 \u{00A7}6",
                    description:
                        "ftyp.compatible_brands does not include the mandatory "
                        + "`cmfc` brand."
                )
            )
        }
        return issues
    }

    // MARK: - Rule 9: mfhd.sequence_number monotonic

    private func checkRule9_MfhdSequenceMonotonic(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        var issues: [CMAFValidationIssue] = []
        var lastSeq: UInt32 = 0
        for segment in mediaSegments {
            for seq in segment.movieFragmentSequenceNumbers {
                if seq <= lastSeq && lastSeq > 0 {
                    issues.append(
                        CMAFValidationIssue(
                            severity: .error,
                            ruleReference: "ISO/IEC 23000-19 \u{00A7}7.4.1",
                            description:
                                "mfhd.sequence_number must monotonically "
                                + "increase across segments; observed "
                                + "\(seq) after \(lastSeq).",
                            segmentIndex: segment.segmentIndex
                        )
                    )
                }
                lastSeq = max(lastSeq, seq)
            }
        }
        return issues
    }

    // MARK: - Rule 10: tfdt.baseMediaDecodeTime monotonic per track

    private func checkRule10_TfdtMonotonic(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        var lastDecodeTimes: [UInt32: UInt64] = [:]
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments {
            for (trackID, decodeTime) in segment.baseMediaDecodeTimes {
                if let previous = lastDecodeTimes[trackID], decodeTime <= previous {
                    issues.append(
                        CMAFValidationIssue(
                            severity: .error,
                            ruleReference: "ISO/IEC 14496-12 \u{00A7}8.8.13",
                            description:
                                "tfdt.baseMediaDecodeTime must monotonically "
                                + "advance per track; observed \(decodeTime) "
                                + "after \(previous).",
                            trackID: trackID,
                            segmentIndex: segment.segmentIndex
                        )
                    )
                }
                lastDecodeTimes[trackID] = decodeTime
            }
        }
        return issues
    }
}
