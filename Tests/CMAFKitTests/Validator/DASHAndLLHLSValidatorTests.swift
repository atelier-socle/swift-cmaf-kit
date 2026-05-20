// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("DASH + LL-HLS conformance validators")
struct DASHAndLLHLSValidatorTests {

    private func dashInit(timescale: UInt32 = 90_000) -> ParsedInitSegment {
        ParsedInitSegment(
            trackConfigurations: [
                WriterFixtures.videoConfig(profile: .dash)
            ],
            movieTimescale: 1000,
            fragmentDuration: nil,
            protectionSystemSpecificHeaders: [],
            majorBrand: "cmfd",
            compatibleBrands: ["iso6", "cmfc", "cmfd", "dash"]
        )
    }

    private func dashSegment(
        hasSidx: Bool = true,
        hasPrft: Bool = false,
        eventMessages: [EventMessageBox] = [],
        index: Int = 0
    ) -> ParsedMediaSegment {
        ParsedMediaSegment(
            segmentIndex: index,
            samples: [],
            movieFragmentSequenceNumbers: [UInt32(index + 1)],
            baseMediaDecodeTimes: [1: UInt64(index * 3000)],
            hasSegmentIndex: hasSidx,
            hasProducerReferenceTime: hasPrft,
            eventMessages: eventMessages,
            segmentIndices: [],
            isChunkedSegment: false,
            firstSampleIsSyncSample: true
        )
    }

    // MARK: - DASH rules

    @Test
    func dashD1_SidxMandatoryFlagged() {
        let validator = DASHConformanceValidator()
        let report = validator.validate(
            initSegment: dashInit(),
            mediaSegments: [dashSegment(hasSidx: false)]
        )
        #expect(report.hasErrors)
        #expect(report.issues.contains { $0.ruleReference.contains("6.3.4.2") })
    }

    @Test
    func dashD1_SidxPresentPasses() {
        let validator = DASHConformanceValidator()
        let report = validator.validate(
            initSegment: dashInit(),
            mediaSegments: [dashSegment(hasSidx: true)]
        )
        #expect(report.hasErrors == false)
    }

    @Test
    func dashD3_PrftPresenceSurfacedAsInfo() {
        let validator = DASHConformanceValidator()
        let report = validator.validate(
            initSegment: dashInit(),
            mediaSegments: [dashSegment(hasSidx: true, hasPrft: true)]
        )
        #expect(report.issues.contains { $0.severity == .info })
    }

    @Test
    func dashD4_EmsgTimescaleMismatchFlagged() {
        let validator = DASHConformanceValidator()
        let mismatchedEvent = EventMessageBox(
            schemeIDURI: "u",
            value: "v",
            timescale: 1234,  // doesn't match any track timescale
            presentationTimeDelta: 0,
            eventDuration: 0,
            id: 1,
            messageData: Data()
        )
        let report = validator.validate(
            initSegment: dashInit(),
            mediaSegments: [
                dashSegment(eventMessages: [mismatchedEvent])
            ]
        )
        #expect(report.hasWarnings)
    }

    @Test
    func dashD7_TimescaleBelow1000Warned() {
        let validator = DASHConformanceValidator()
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .dash,
            timescale: 500,
            language: "eng",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: .mp4a,
                codecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
                channelCount: 2,
                sampleRate: 48_000
            )
        )
        let initSeg = ParsedInitSegment(
            trackConfigurations: [track],
            movieTimescale: 1000,
            fragmentDuration: nil,
            protectionSystemSpecificHeaders: [],
            majorBrand: "cmfd",
            compatibleBrands: ["iso6", "cmfc", "cmfd"]
        )
        let report = validator.validate(
            initSegment: initSeg,
            mediaSegments: [dashSegment(hasSidx: true)]
        )
        #expect(report.hasWarnings)
    }

    // MARK: - LL-HLS rules

    private func llHLSInit() -> ParsedInitSegment {
        ParsedInitSegment(
            trackConfigurations: [
                WriterFixtures.videoConfig(profile: .lowLatency)
            ],
            movieTimescale: 1000,
            fragmentDuration: nil,
            protectionSystemSpecificHeaders: [],
            majorBrand: "cmfl",
            compatibleBrands: ["iso6", "cmfc", "cmfl"]
        )
    }

    private func chunkedSegment(
        firstSync: Bool = true,
        sequenceNumbers: [UInt32] = [1, 2],
        index: Int = 0
    ) -> ParsedMediaSegment {
        ParsedMediaSegment(
            segmentIndex: index,
            samples: [],
            movieFragmentSequenceNumbers: sequenceNumbers,
            baseMediaDecodeTimes: [1: UInt64(index * 3000)],
            hasSegmentIndex: false,
            hasProducerReferenceTime: false,
            eventMessages: [],
            segmentIndices: [],
            isChunkedSegment: true,
            firstSampleIsSyncSample: firstSync
        )
    }

    @Test
    func llHLSL2_DuplicateSequenceFlagged() {
        let validator = LLHLSConformanceValidator()
        let s1 = chunkedSegment(sequenceNumbers: [1, 2], index: 0)
        let s2 = chunkedSegment(sequenceNumbers: [2, 3], index: 1)
        let report = validator.validate(
            initSegment: llHLSInit(),
            mediaSegments: [s1, s2]
        )
        #expect(report.hasErrors)
    }

    @Test
    func llHLSL4_FirstChunkMustBeIndependent() {
        let validator = LLHLSConformanceValidator()
        let s = chunkedSegment(firstSync: false)
        let report = validator.validate(
            initSegment: llHLSInit(),
            mediaSegments: [s]
        )
        #expect(report.hasErrors)
    }

    @Test
    func llHLSL3_PartialChunkExceedsTarget() {
        // 4 samples × 3000 timescale at 90_000 = 0.133s total.
        // 2 chunks → 0.0666s per chunk. PART-TARGET 0.05 → exceeds.
        let validator = LLHLSConformanceValidator(partTargetSeconds: 0.05)
        let samples = (0..<4).map { i in
            CMAFParsedSample(
                trackID: 1,
                bytes: Data(),
                durationInTimescale: 3000,
                compositionTimeOffset: 0,
                flags: i == 0 ? .syncSample : .nonSyncSample,
                encryption: nil,
                decodeTime: UInt64(i * 3000)
            )
        }
        let s = ParsedMediaSegment(
            segmentIndex: 0,
            samples: samples,
            movieFragmentSequenceNumbers: [1, 2],
            baseMediaDecodeTimes: [1: 0],
            hasSegmentIndex: false,
            hasProducerReferenceTime: false,
            eventMessages: [],
            segmentIndices: [],
            isChunkedSegment: true,
            firstSampleIsSyncSample: true
        )
        let report = validator.validate(
            initSegment: llHLSInit(),
            mediaSegments: [s]
        )
        #expect(report.hasWarnings)
    }

    @Test
    func llHLSL5_TfdtRegressionWithinChunkedSegmentFlagged() {
        let validator = LLHLSConformanceValidator()
        let samples = [
            CMAFParsedSample(
                trackID: 1, bytes: Data(), durationInTimescale: 3000,
                compositionTimeOffset: 0, flags: .syncSample,
                encryption: nil, decodeTime: 5000
            ),
            CMAFParsedSample(
                trackID: 1, bytes: Data(), durationInTimescale: 3000,
                compositionTimeOffset: 0, flags: .nonSyncSample,
                encryption: nil, decodeTime: 2000  // regression
            )
        ]
        let s = ParsedMediaSegment(
            segmentIndex: 0,
            samples: samples,
            movieFragmentSequenceNumbers: [1, 2],
            baseMediaDecodeTimes: [1: 5000],
            hasSegmentIndex: false,
            hasProducerReferenceTime: false,
            eventMessages: [],
            segmentIndices: [],
            isChunkedSegment: true,
            firstSampleIsSyncSample: true
        )
        let report = validator.validate(
            initSegment: llHLSInit(),
            mediaSegments: [s]
        )
        #expect(report.hasErrors)
    }

    @Test
    func llHLSValidatorWithoutChunkedSegmentsReturnsClean() {
        let validator = LLHLSConformanceValidator()
        let nonChunked = ParsedMediaSegment(
            segmentIndex: 0,
            samples: [],
            movieFragmentSequenceNumbers: [1],
            baseMediaDecodeTimes: [:],
            hasSegmentIndex: false,
            hasProducerReferenceTime: false,
            eventMessages: [],
            segmentIndices: [],
            isChunkedSegment: false,
            firstSampleIsSyncSample: true
        )
        let report = validator.validate(
            initSegment: llHLSInit(),
            mediaSegments: [nonChunked]
        )
        #expect(report.isClean)
    }
}
