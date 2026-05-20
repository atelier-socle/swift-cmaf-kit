// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFConformanceValidator — 10 rules")
struct CMAFConformanceValidatorTests {

    private func makeInitSegment(
        tracks: [CMAFTrackConfiguration] = [WriterFixtures.videoConfig()],
        compatibleBrands: [FourCC] = ["iso6", "cmfc"]
    ) -> ParsedInitSegment {
        ParsedInitSegment(
            trackConfigurations: tracks,
            movieTimescale: 1000,
            fragmentDuration: nil,
            protectionSystemSpecificHeaders: [],
            majorBrand: "cmfc",
            compatibleBrands: compatibleBrands
        )
    }

    private func makeSegment(
        index: Int = 0,
        samples: [CMAFParsedSample] = [],
        sequenceNumbers: [UInt32] = [1],
        baseDecodeTimes: [UInt32: UInt64] = [1: 0],
        firstSync: Bool = true
    ) -> ParsedMediaSegment {
        ParsedMediaSegment(
            segmentIndex: index,
            samples: samples,
            movieFragmentSequenceNumbers: sequenceNumbers,
            baseMediaDecodeTimes: baseDecodeTimes,
            hasSegmentIndex: false,
            hasProducerReferenceTime: false,
            eventMessages: [],
            segmentIndices: [],
            isChunkedSegment: false,
            firstSampleIsSyncSample: firstSync
        )
    }

    @Test
    func cleanInputProducesNoErrors() {
        let validator = CMAFConformanceValidator()
        let report = validator.validate(
            initSegment: makeInitSegment(),
            mediaSegments: [makeSegment()]
        )
        #expect(report.hasErrors == false)
    }

    @Test
    func rule3_TrackNotDeclaredFlaggedError() {
        let validator = CMAFConformanceValidator()
        let segment = makeSegment(baseDecodeTimes: [99: 0])
        let report = validator.validate(
            initSegment: makeInitSegment(),
            mediaSegments: [segment]
        )
        #expect(report.hasErrors)
        #expect(report.issues.contains { $0.ruleReference.contains("7.3.5.2") })
    }

    @Test
    func rule8_MissingIso6Brand() {
        let validator = CMAFConformanceValidator()
        let init1 = makeInitSegment(compatibleBrands: ["cmfc"])  // missing iso6
        let report = validator.validate(
            initSegment: init1,
            mediaSegments: []
        )
        #expect(report.hasErrors)
        #expect(report.issues.contains { $0.description.contains("iso6") })
    }

    @Test
    func rule8_MissingCmfcBrand() {
        let validator = CMAFConformanceValidator()
        let init1 = makeInitSegment(compatibleBrands: ["iso6"])  // missing cmfc
        let report = validator.validate(
            initSegment: init1,
            mediaSegments: []
        )
        #expect(report.issues.contains { $0.description.contains("cmfc") })
    }

    @Test
    func rule9_SequenceNumberRegressionFlagged() {
        let validator = CMAFConformanceValidator()
        let s1 = makeSegment(index: 0, sequenceNumbers: [10])
        let s2 = makeSegment(index: 1, sequenceNumbers: [5])  // regression
        let report = validator.validate(
            initSegment: makeInitSegment(),
            mediaSegments: [s1, s2]
        )
        #expect(report.issues.contains { $0.ruleReference.contains("7.4.1") })
    }

    @Test
    func rule9_MonotonicSequencePassesClean() {
        let validator = CMAFConformanceValidator()
        let s1 = makeSegment(index: 0, sequenceNumbers: [1])
        let s2 = makeSegment(index: 1, sequenceNumbers: [2])
        let report = validator.validate(
            initSegment: makeInitSegment(),
            mediaSegments: [s1, s2]
        )
        #expect(report.issues.contains { $0.ruleReference.contains("7.4.1") } == false)
    }

    @Test
    func rule10_TfdtRegressionFlagged() {
        let validator = CMAFConformanceValidator()
        let s1 = makeSegment(index: 0, baseDecodeTimes: [1: 1000])
        let s2 = makeSegment(index: 1, baseDecodeTimes: [1: 500])  // regression
        let report = validator.validate(
            initSegment: makeInitSegment(),
            mediaSegments: [s1, s2]
        )
        #expect(report.issues.contains { $0.ruleReference.contains("8.8.13") })
    }

    @Test
    func rule10_MonotonicTfdtPasses() {
        let validator = CMAFConformanceValidator()
        let s1 = makeSegment(index: 0, baseDecodeTimes: [1: 0])
        let s2 = makeSegment(index: 1, baseDecodeTimes: [1: 3000])
        let report = validator.validate(
            initSegment: makeInitSegment(),
            mediaSegments: [s1, s2]
        )
        #expect(report.issues.contains { $0.ruleReference.contains("8.8.13") } == false)
    }

    @Test
    func rule2_MultiTrackSegmentEmitsInfo() {
        let validator = CMAFConformanceValidator()
        let v1 = CMAFParsedSample(
            trackID: 1, bytes: Data(), durationInTimescale: 3000,
            compositionTimeOffset: 0,
            flags: .syncSample, encryption: nil, decodeTime: 0
        )
        let v2 = CMAFParsedSample(
            trackID: 2, bytes: Data(), durationInTimescale: 3000,
            compositionTimeOffset: 0,
            flags: .syncSample, encryption: nil, decodeTime: 0
        )
        let segment = makeSegment(
            samples: [v1, v2],
            baseDecodeTimes: [1: 0, 2: 0]
        )
        let report = validator.validate(
            initSegment: makeInitSegment(
                tracks: [
                    WriterFixtures.videoConfig(trackID: 1),
                    WriterFixtures.audioConfig(trackID: 2)
                ]
            ),
            mediaSegments: [segment]
        )
        #expect(report.issues.contains { $0.severity == .info })
    }

    @Test
    func validationReportMergesAcrossRuns() {
        let a = CMAFValidationReport(issues: [
            CMAFValidationIssue(
                severity: .info,
                ruleReference: "ref-a",
                description: "first"
            )
        ])
        let b = CMAFValidationReport(issues: [
            CMAFValidationIssue(
                severity: .error,
                ruleReference: "ref-b",
                description: "second"
            )
        ])
        let merged = a.merged(with: b)
        #expect(merged.issues.count == 2)
        #expect(merged.hasErrors)
    }

    @Test
    func reportIssuesFilterBySeverity() {
        let report = CMAFValidationReport(issues: [
            CMAFValidationIssue(severity: .info, ruleReference: "r", description: ""),
            CMAFValidationIssue(severity: .warning, ruleReference: "r", description: ""),
            CMAFValidationIssue(severity: .error, ruleReference: "r", description: "")
        ])
        #expect(report.issues(at: .error).count == 1)
        #expect(report.issues(at: .warning).count == 1)
        #expect(report.issues(at: .info).count == 1)
    }

    @Test
    func isCleanWhenNoIssues() {
        let report = CMAFValidationReport()
        #expect(report.isClean)
    }
}
