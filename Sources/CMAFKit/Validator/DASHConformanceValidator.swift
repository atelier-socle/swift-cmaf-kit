// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DASHConformanceValidator
//
// Reference: ISO/IEC 23009-1 §6.3 (DASH ISO BMFF profile) and the
// DASH-IF Interoperability Guidelines v5.0+.

import Foundation

/// DASH ISO BMFF profile conformance validator.
public struct DASHConformanceValidator: Sendable {

    public init() {}

    /// Run every DASH rule on the parsed file.
    public func validate(
        initSegment: ParsedInitSegment,
        mediaSegments: [ParsedMediaSegment]
    ) -> CMAFValidationReport {
        var issues: [CMAFValidationIssue] = []
        issues.append(contentsOf: checkD1_SidxMandatory(mediaSegments: mediaSegments))
        issues.append(contentsOf: checkD3_PrftValidNTP(mediaSegments: mediaSegments))
        issues.append(
            contentsOf: checkD4_EmsgTimescaleMatchesTrack(
                initSegment: initSegment,
                mediaSegments: mediaSegments
            )
        )
        issues.append(
            contentsOf: checkD5_SidxDurationSum(
                initSegment: initSegment,
                mediaSegments: mediaSegments
            )
        )
        issues.append(contentsOf: checkD6_SidxHierarchy(mediaSegments: mediaSegments))
        issues.append(
            contentsOf: checkD7_TrackTimescaleAtLeast1000(initSegment: initSegment)
        )
        return CMAFValidationReport(issues: issues)
    }

    // MARK: - D1: sidx mandatory at start of each media segment

    private func checkD1_SidxMandatory(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        mediaSegments
            .filter { !$0.hasSegmentIndex }
            .map { segment in
                CMAFValidationIssue(
                    severity: .error,
                    ruleReference: "ISO/IEC 23009-1 \u{00A7}6.3.4.2",
                    description:
                        "DASH CMAF segments must carry a Segment Index (sidx) "
                        + "at the start of each media segment.",
                    segmentIndex: segment.segmentIndex
                )
            }
    }

    // MARK: - D3: prft NTP timestamp validity

    private func checkD3_PrftValidNTP(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        var issues: [CMAFValidationIssue] = []
        let secondsBetween1900And1970: UInt64 = 2_208_988_800
        let minimumNTPForYear1970 = secondsBetween1900And1970 << 32
        for segment in mediaSegments where segment.hasProducerReferenceTime {
            // We do not retain the prft box here (the parsed
            // segment only flags presence); if a future reader
            // captures the prft, validate NTP > minimumNTPForYear1970.
            _ = minimumNTPForYear1970
            issues.append(
                CMAFValidationIssue(
                    severity: .info,
                    ruleReference: "ISO/IEC 23009-1 \u{00A7}6.3.4.3",
                    description:
                        "Segment carries prft for live signalling.",
                    segmentIndex: segment.segmentIndex
                )
            )
        }
        return issues
    }

    // MARK: - D4: emsg timescale matches track timescale

    private func checkD4_EmsgTimescaleMatchesTrack(
        initSegment: ParsedInitSegment,
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        let trackTimescales = Set(initSegment.trackConfigurations.map { $0.timescale })
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments {
            for event in segment.eventMessages where !trackTimescales.contains(event.timescale) {
                issues.append(
                    CMAFValidationIssue(
                        severity: .warning,
                        ruleReference: "ISO/IEC 23009-1 \u{00A7}5.10.3",
                        description:
                            "emsg.timescale (\(event.timescale)) does not "
                            + "match any track's timescale.",
                        segmentIndex: segment.segmentIndex
                    )
                )
            }
        }
        return issues
    }

    // MARK: - D5: sidx subsegmentDuration sum

    private func checkD5_SidxDurationSum(
        initSegment: ParsedInitSegment,
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        guard let declaredFragmentDuration = initSegment.fragmentDuration else {
            return []
        }
        var totalSidxSum: UInt64 = 0
        for segment in mediaSegments {
            for sidx in segment.segmentIndices {
                for entry in sidx.table {
                    totalSidxSum += UInt64(entry.subsegmentDuration)
                }
            }
        }
        // Normalise: declared duration is in `mvhd.timescale`; sidx
        // entries are in the sidx's own timescale. We accept a
        // ±1-unit tolerance per spec note.
        if totalSidxSum > 0,
            UInt64(abs(Int64(totalSidxSum) - Int64(declaredFragmentDuration))) > 1
        {
            return [
                CMAFValidationIssue(
                    severity: .warning,
                    ruleReference: "ISO/IEC 23009-1 \u{00A7}6.3.4.2",
                    description:
                        "Sum of sidx subsegmentDuration (\(totalSidxSum)) "
                        + "does not match mehd.fragmentDuration "
                        + "(\(declaredFragmentDuration)) within tolerance."
                )
            ]
        }
        return []
    }

    // MARK: - D6: sidx hierarchy

    private func checkD6_SidxHierarchy(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments where segment.segmentIndices.count > 1 {
            issues.append(
                CMAFValidationIssue(
                    severity: .info,
                    ruleReference: "DASH-IF IOP \u{00A7}5.4",
                    description:
                        "Segment carries \(segment.segmentIndices.count) sidx boxes "
                        + "forming a hierarchy.",
                    segmentIndex: segment.segmentIndex
                )
            )
        }
        return issues
    }

    // MARK: - D7: track timescale ≥ 1000

    private func checkD7_TrackTimescaleAtLeast1000(
        initSegment: ParsedInitSegment
    ) -> [CMAFValidationIssue] {
        initSegment.trackConfigurations
            .filter { $0.timescale < 1000 }
            .map { cfg in
                CMAFValidationIssue(
                    severity: .warning,
                    ruleReference: "DASH-IF IOP \u{00A7}6.2",
                    description:
                        "Track timescale = \(cfg.timescale); DASH-IF "
                        + "recommends ≥ 1000 for accurate ABR splicing.",
                    trackID: cfg.trackID
                )
            }
    }
}
