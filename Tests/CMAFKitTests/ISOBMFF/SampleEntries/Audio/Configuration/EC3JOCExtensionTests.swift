// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// EC3JOCExtension — type behaviour + derivation from EC3SpecificBox
// per ETSI TS 102 366 Annex F.6 + Annex H.

import Foundation
import Testing

@testable import CMAFKit

@Suite("EC3JOCExtension — case behaviour")
struct EC3JOCExtensionTests {

    @Test func noneIsNotPresent() {
        #expect(!EC3JOCExtension.none.isPresent)
        #expect(EC3JOCExtension.none.complexityIndex == nil)
    }

    @Test func objectBasedReportsPresentAndComplexity() {
        let value = EC3JOCExtension.objectBased(complexityIndex: 8)
        #expect(value.isPresent)
        #expect(value.complexityIndex == 8)
    }

    @Test func channelBasedReportsPresentAndComplexity() {
        let value = EC3JOCExtension.channelBased(complexityIndex: 4)
        #expect(value.isPresent)
        #expect(value.complexityIndex == 4)
    }

    @Test func bedAndObjectsCanonicalApple16() {
        // Apple HLS CHANNELS="16/JOC" canonical complexity.
        let value = EC3JOCExtension.bedAndObjects(complexityIndex: 16)
        #expect(value.isPresent)
        #expect(value.complexityIndex == 16)
    }

    @Test func programmaticExtensionIsPresentNoComplexity() {
        let raw = Data([0x10, 0x20, 0x30])
        let value = EC3JOCExtension.programmaticExtension(rawBytes: raw)
        #expect(value.isPresent)
        #expect(value.complexityIndex == nil)
    }

    @Test func equalityIsCaseAndAssociatedValueSensitive() {
        #expect(
            EC3JOCExtension.bedAndObjects(complexityIndex: 16)
                == EC3JOCExtension.bedAndObjects(complexityIndex: 16))
        #expect(
            EC3JOCExtension.bedAndObjects(complexityIndex: 16)
                != EC3JOCExtension.bedAndObjects(complexityIndex: 8))
        #expect(
            EC3JOCExtension.bedAndObjects(complexityIndex: 16)
                != EC3JOCExtension.objectBased(complexityIndex: 16))
    }

    @Test func hashableSetContainment() {
        let set: Set<EC3JOCExtension> = [
            .none,
            .bedAndObjects(complexityIndex: 16),
            .objectBased(complexityIndex: 8)
        ]
        #expect(set.contains(.bedAndObjects(complexityIndex: 16)))
        #expect(!set.contains(.bedAndObjects(complexityIndex: 8)))
    }
}

@Suite("EC3SpecificBox — JOC derivation")
struct EC3SpecificBoxJOCTests {

    private func makeSubstream() -> EC3SpecificBox.IndependentSubstream {
        EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000,
            bsid: 16,
            asvc: false,
            bsmod: .completeMain,
            acmod: .threeTwo,
            lfeon: true,
            dependentSubstreamCount: 0)
    }

    @Test func boxWithNilExtensionByteReportsNoneJOC() {
        let box = EC3SpecificBox(
            dataRate: 384,
            independentSubstreams: [makeSubstream()],
            ec3ExtensionTypeA: nil)
        #expect(box.jocExtension == .none)
        #expect(!box.carriesDolbyAtmos)
    }

    @Test func boxWithZeroExtensionByteReportsNoneJOC() {
        // Flag set but no JOC complexity — still none.
        let box = EC3SpecificBox(
            dataRate: 384,
            independentSubstreams: [makeSubstream()],
            ec3ExtensionTypeA: 0)
        #expect(box.jocExtension == .none)
        #expect(!box.carriesDolbyAtmos)
    }

    @Test func boxWithCanonicalAtmosByteReportsBedAndObjects16() {
        // Apple canonical: complexity 16 in the low 5 bits.
        let box = EC3SpecificBox(
            dataRate: 768,
            independentSubstreams: [makeSubstream()],
            ec3ExtensionTypeA: 0x10)
        #expect(box.jocExtension == .bedAndObjects(complexityIndex: 16))
        #expect(box.carriesDolbyAtmos)
    }

    @Test func boxIgnoresReservedUpperBitsInExtensionByte() {
        // Upper 3 bits reserved per Annex H — masked off by the
        // accessor. Byte 0xE0 → complexity 0 → none.
        let box = EC3SpecificBox(
            dataRate: 384,
            independentSubstreams: [makeSubstream()],
            ec3ExtensionTypeA: 0xE0)
        #expect(box.jocExtension == .none)
    }

    @Test func boxWithMixedUpperBitsReportsLowerBitComplexity() {
        // Byte 0xF0 → upper bits set + complexity 16. Mask isolates
        // the complexity index correctly.
        let box = EC3SpecificBox(
            dataRate: 384,
            independentSubstreams: [makeSubstream()],
            ec3ExtensionTypeA: 0xF0)
        #expect(box.jocExtension == .bedAndObjects(complexityIndex: 16))
        #expect(box.carriesDolbyAtmos)
    }

    @Test func atmosBoxRoundTripsByteIdentically() async throws {
        let box = EC3SpecificBox(
            dataRate: 768,
            independentSubstreams: [makeSubstream()],
            ec3ExtensionTypeA: 0x10)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EC3SpecificBox)
        #expect(parsed == box)
        #expect(parsed.jocExtension == .bedAndObjects(complexityIndex: 16))
        #expect(parsed.carriesDolbyAtmos)
    }
}
