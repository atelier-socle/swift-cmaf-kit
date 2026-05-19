// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFFragmentBoundary + CMAFPartialChunkBoundary")
struct CMAFFragmentBoundaryTests {

    @Test
    func sampleCountEqualityForPlainCases() {
        #expect(CMAFFragmentBoundary.sampleCount(48) == CMAFFragmentBoundary.sampleCount(48))
        #expect(CMAFFragmentBoundary.sampleCount(48) != CMAFFragmentBoundary.sampleCount(49))
    }

    @Test
    func durationSecondsEquality() {
        #expect(CMAFFragmentBoundary.durationSeconds(2.0) == CMAFFragmentBoundary.durationSeconds(2.0))
        #expect(CMAFFragmentBoundary.durationSeconds(2.0) != CMAFFragmentBoundary.durationSeconds(4.0))
    }

    @Test
    func onSyncSampleEqualsItself() {
        #expect(CMAFFragmentBoundary.onSyncSample == CMAFFragmentBoundary.onSyncSample)
    }

    @Test
    func customClosureBoundaryReturnsFalseEquality() {
        let a = CMAFFragmentBoundary.custom { _ in false }
        let b = CMAFFragmentBoundary.custom { _ in false }
        // Closures are not Equatable; the conformance returns false.
        #expect((a == b) == false)
    }

    @Test
    func partialChunkBoundaryEquality() {
        #expect(CMAFPartialChunkBoundary.perSample == CMAFPartialChunkBoundary.perSample)
        #expect(
            CMAFPartialChunkBoundary.sampleCount(3) == CMAFPartialChunkBoundary.sampleCount(3)
        )
        #expect(
            CMAFPartialChunkBoundary.durationSeconds(0.2)
                == CMAFPartialChunkBoundary.durationSeconds(0.2)
        )
    }

    @Test
    func fragmentStateExposesAllFields() {
        let state = CMAFFragmentState(
            currentFragmentSampleCount: 48,
            currentFragmentDurationInTimescale: 144_000,
            timescale: 48_000,
            isCurrentSampleSync: true
        )
        #expect(state.currentFragmentSampleCount == 48)
        #expect(state.currentFragmentDurationInTimescale == 144_000)
        #expect(state.timescale == 48_000)
        #expect(state.isCurrentSampleSync)
    }
}
