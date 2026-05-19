// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleFlags")
struct SampleFlagsTests {

    @Test
    func defaultsAreZero() {
        let flags = SampleFlags()
        #expect(flags.rawValue == 0)
    }

    @Test
    func syncSampleHasDependsOn2AndNotNonSync() {
        let flags = SampleFlags.syncSample
        #expect(flags.sampleDependsOn == 2)
        #expect(flags.isSyncSample)
        #expect(flags.sampleIsNonSyncSample == false)
    }

    @Test
    func nonSyncSampleHasDependsOn1AndNonSync() {
        let flags = SampleFlags.nonSyncSample
        #expect(flags.sampleDependsOn == 1)
        #expect(flags.sampleIsNonSyncSample)
    }

    @Test
    func rawValueRoundTripPreservesAllFields() {
        let flags = SampleFlags(
            isLeading: 2,
            sampleDependsOn: 1,
            sampleIsDependedOn: 2,
            sampleHasRedundancy: 3,
            samplePaddingValue: 5,
            sampleIsNonSyncSample: true,
            sampleDegradationPriority: 0xBEEF
        )
        let raw = flags.rawValue
        let parsed = SampleFlags(rawValue: raw)
        #expect(parsed == flags)
    }

    @Test
    func paddingValueFitsThreeBits() {
        let flags = SampleFlags(samplePaddingValue: 7)
        #expect(flags.samplePaddingValue == 7)
    }

    @Test
    func degradationPriorityFitsLowSixteenBits() {
        let flags = SampleFlags(sampleDegradationPriority: 0xFFFF)
        #expect(flags.rawValue & 0xFFFF == 0xFFFF)
    }

    @Test
    func bitLayoutIsoCompliant() {
        // is_leading is at bits 26..27 of the 32-bit field per
        // ISO/IEC 14496-12 §8.8.3.1.
        let flags = SampleFlags(isLeading: 3)
        #expect(flags.rawValue == 0x0C00_0000)
    }

    @Test
    func nonSyncBitIsBit16() {
        let flags = SampleFlags(sampleIsNonSyncSample: true)
        #expect(flags.rawValue == 0x0001_0000)
    }
}
