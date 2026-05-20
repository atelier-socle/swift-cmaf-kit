// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - LLHLSConformanceValidator
//
// Reference: IETF RFC 8216bis-15 §B (LL-HLS partial fragments) and
// ISO/IEC 23000-19 §7.3.5.1 (every fragment begins at a SAP).

import Foundation

/// Low-latency HLS conformance validator.
public struct LLHLSConformanceValidator: Sendable {

    /// Configurable PART-TARGET in seconds, used by rule L3.
    public let partTargetSeconds: Double?

    public init(partTargetSeconds: Double? = nil) {
        self.partTargetSeconds = partTargetSeconds
    }

    /// Run every LL-HLS rule on the parsed file.
    public func validate(
        initSegment: ParsedInitSegment,
        mediaSegments: [ParsedMediaSegment]
    ) -> CMAFValidationReport {
        var issues: [CMAFValidationIssue] = []
        let chunkedSegments = mediaSegments.filter { $0.isChunkedSegment }
        guard !chunkedSegments.isEmpty else { return CMAFValidationReport() }
        issues.append(
            contentsOf: checkL1_FirstSampleSyncMatchesIndependent(
                mediaSegments: chunkedSegments
            ))
        issues.append(
            contentsOf: checkL2_SequenceNumbersUnique(
                mediaSegments: mediaSegments
            ))
        issues.append(
            contentsOf: checkL3_PartTarget(
                initSegment: initSegment,
                mediaSegments: chunkedSegments
            ))
        issues.append(
            contentsOf: checkL4_FirstChunkIndependent(
                mediaSegments: chunkedSegments
            ))
        issues.append(
            contentsOf: checkL5_TfdtAdvancesWithinFragment(
                mediaSegments: chunkedSegments
            ))
        return CMAFValidationReport(issues: issues)
    }

    // MARK: - L1: first sample is sync iff INDEPENDENT=YES

    private func checkL1_FirstSampleSyncMatchesIndependent(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        var issues: [CMAFValidationIssue] = []
        // Each chunked segment carries multiple mfhd sequence
        // numbers (one per chunk). The validator assumes the first
        // chunk is the SAP-bearing chunk.
        for segment in mediaSegments where !segment.firstSampleIsSyncSample {
            issues.append(
                CMAFValidationIssue(
                    severity: .error,
                    ruleReference: "IETF RFC 8216bis-15 \u{00A7}B.4.1",
                    description:
                        "Chunked segment's first sample is not a sync "
                        + "sample; the first chunk cannot be INDEPENDENT.",
                    segmentIndex: segment.segmentIndex
                )
            )
        }
        return issues
    }

    // MARK: - L2: every mfhd.sequence_number unique across the file

    private func checkL2_SequenceNumbersUnique(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        var seen: [UInt32: Int] = [:]
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments {
            for seq in segment.movieFragmentSequenceNumbers {
                if let previous = seen[seq] {
                    issues.append(
                        CMAFValidationIssue(
                            severity: .error,
                            ruleReference: "IETF RFC 8216bis-15 \u{00A7}B.4.1",
                            description:
                                "mfhd.sequence_number \(seq) appears in "
                                + "segments \(previous) and "
                                + "\(segment.segmentIndex); must be unique.",
                            segmentIndex: segment.segmentIndex
                        )
                    )
                }
                seen[seq] = segment.segmentIndex
            }
        }
        return issues
    }

    // MARK: - L3: partial chunk duration ≤ PART-TARGET

    private func checkL3_PartTarget(
        initSegment: ParsedInitSegment,
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        guard let partTarget = partTargetSeconds else { return [] }
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments {
            // Approximation: divide the segment's total duration
            // across the chunks (one mfhd per chunk).
            let chunkCount = max(segment.movieFragmentSequenceNumbers.count, 1)
            let totalDuration = segment.samples
                .reduce(into: UInt64(0)) { $0 += UInt64($1.durationInTimescale) }
            guard let timescale = initSegment.trackConfigurations.first?.timescale,
                timescale > 0
            else { continue }
            let perChunkSeconds =
                Double(totalDuration) / Double(timescale)
                / Double(chunkCount)
            if perChunkSeconds > partTarget + 0.01 {
                issues.append(
                    CMAFValidationIssue(
                        severity: .warning,
                        ruleReference: "IETF RFC 8216bis-15 \u{00A7}B.4.1",
                        description:
                            "Average partial chunk duration \(perChunkSeconds)s "
                            + "exceeds PART-TARGET \(partTarget)s.",
                        segmentIndex: segment.segmentIndex
                    )
                )
            }
        }
        return issues
    }

    // MARK: - L4: first chunk of each fragment is INDEPENDENT

    private func checkL4_FirstChunkIndependent(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        mediaSegments
            .filter { $0.firstSampleIsSyncSample == false }
            .map { segment in
                CMAFValidationIssue(
                    severity: .error,
                    ruleReference: "IETF RFC 8216bis-15 \u{00A7}B.4.1",
                    description:
                        "First chunk of a chunked segment must be "
                        + "INDEPENDENT=YES (its first sample must be a sync sample).",
                    segmentIndex: segment.segmentIndex
                )
            }
    }

    // MARK: - L5: tfdt monotonic within a fragment

    private func checkL5_TfdtAdvancesWithinFragment(
        mediaSegments: [ParsedMediaSegment]
    ) -> [CMAFValidationIssue] {
        var issues: [CMAFValidationIssue] = []
        for segment in mediaSegments {
            var lastByTrack: [UInt32: UInt64] = [:]
            for sample in segment.samples {
                if let previous = lastByTrack[sample.trackID],
                    sample.decodeTime < previous
                {
                    issues.append(
                        CMAFValidationIssue(
                            severity: .error,
                            ruleReference: "IETF RFC 8216bis-15 \u{00A7}B.4.1",
                            description:
                                "tfdt.baseMediaDecodeTime regressed within "
                                + "chunked segment (track \(sample.trackID): "
                                + "\(sample.decodeTime) after \(previous)).",
                            trackID: sample.trackID,
                            segmentIndex: segment.segmentIndex
                        )
                    )
                }
                lastByTrack[sample.trackID] = sample.decodeTime
            }
        }
        return issues
    }
}
