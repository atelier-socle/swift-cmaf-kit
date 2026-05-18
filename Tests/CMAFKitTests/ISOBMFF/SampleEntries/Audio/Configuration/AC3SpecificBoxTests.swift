// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AC3SpecificBox")
struct AC3SpecificBoxTests {

    @Test
    func defaultStereoRoundTrip() async throws {
        let box = AC3SpecificBox(
            fscod: .freq48000,
            bsid: 8,
            bsmod: .completeMain,
            acmod: .stereo,
            lfeon: false,
            bitRateCode: 6
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC3SpecificBox)
        #expect(parsed == box)
    }

    @Test
    func bodyIsThreeBytes() {
        let box = AC3SpecificBox(
            fscod: .freq48000,
            bsid: 8,
            bsmod: .completeMain,
            acmod: .stereo,
            lfeon: false,
            bitRateCode: 0
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // 8 header + 3 body = 11 bytes.
        #expect(writer.data.count == 11)
    }

    @Test
    func fiveOneRoundTrip() async throws {
        let box = AC3SpecificBox(
            fscod: .freq48000,
            bsid: 8,
            bsmod: .completeMain,
            acmod: .threeTwo,
            lfeon: true,
            bitRateCode: 12
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC3SpecificBox)
        #expect(parsed.acmod == .threeTwo)
        #expect(parsed.lfeon == true)
    }

    @Test
    func fscod44100RoundTrip() async throws {
        let box = AC3SpecificBox(
            fscod: .freq44100,
            bsid: 8,
            bsmod: .completeMain,
            acmod: .stereo,
            lfeon: false,
            bitRateCode: 6
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC3SpecificBox)
        #expect(parsed.fscod == .freq44100)
    }

    @Test
    func allBitStreamModesRoundTrip() async throws {
        let modes: [AC3BitStreamMode] = [
            .completeMain, .musicAndEffects, .visuallyImpaired,
            .hearingImpaired, .dialogue, .commentary, .emergency,
            .voiceOverOrKaraoke
        ]
        for mode in modes {
            let box = AC3SpecificBox(
                fscod: .freq48000,
                bsid: 8,
                bsmod: mode,
                acmod: .stereo,
                lfeon: false,
                bitRateCode: 0
            )
            var writer = BinaryWriter()
            box.encode(to: &writer)
            let registry = await BoxRegistry.defaultRegistry()
            let reader = ISOBoxReader()
            let boxes = try await reader.readBoxes(from: writer.data, using: registry)
            let parsed = try #require(boxes.first as? AC3SpecificBox)
            #expect(parsed.bsmod == mode)
        }
    }

    @Test
    func allAudioCodingModesRoundTrip() async throws {
        let modes: [AC3AudioCodingMode] = [
            .dualMono, .mono, .stereo, .threeZero,
            .twoOne, .threeOne, .twoTwo, .threeTwo
        ]
        for mode in modes {
            let box = AC3SpecificBox(
                fscod: .freq48000,
                bsid: 8,
                bsmod: .completeMain,
                acmod: mode,
                lfeon: false,
                bitRateCode: 0
            )
            var writer = BinaryWriter()
            box.encode(to: &writer)
            let registry = await BoxRegistry.defaultRegistry()
            let reader = ISOBoxReader()
            let boxes = try await reader.readBoxes(from: writer.data, using: registry)
            let parsed = try #require(boxes.first as? AC3SpecificBox)
            #expect(parsed.acmod == mode)
        }
    }

    @Test
    func bsidAtMaxValue() async throws {
        let box = AC3SpecificBox(
            fscod: .freq48000,
            bsid: 16,
            bsmod: .completeMain,
            acmod: .stereo,
            lfeon: false,
            bitRateCode: 0
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC3SpecificBox)
        #expect(parsed.bsid == 16)
    }

    @Test
    func bitRateCodeAt31RoundTrip() async throws {
        let box = AC3SpecificBox(
            fscod: .freq48000,
            bsid: 8,
            bsmod: .completeMain,
            acmod: .stereo,
            lfeon: false,
            bitRateCode: 31
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC3SpecificBox)
        #expect(parsed.bitRateCode == 31)
    }

    @Test
    func boxTypeIsDac3() {
        #expect(AC3SpecificBox.boxType == "dac3")
    }
}

@Suite("EC3SpecificBox")
struct EC3SpecificBoxTests {

    @Test
    func singleSubstreamRoundTrip() async throws {
        let substream = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000,
            bsid: 16,
            asvc: false,
            bsmod: .completeMain,
            acmod: .stereo,
            lfeon: false,
            dependentSubstreamCount: 0
        )
        let box = EC3SpecificBox(
            dataRate: 192,
            independentSubstreams: [substream]
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EC3SpecificBox)
        #expect(parsed == box)
    }

    @Test
    func twoSubstreamsRoundTrip() async throws {
        let sub1 = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: false,
            bsmod: .completeMain, acmod: .stereo, lfeon: false,
            dependentSubstreamCount: 0
        )
        let sub2 = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: true,
            bsmod: .dialogue, acmod: .mono, lfeon: false,
            dependentSubstreamCount: 0
        )
        let box = EC3SpecificBox(
            dataRate: 256,
            independentSubstreams: [sub1, sub2]
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EC3SpecificBox)
        #expect(parsed.independentSubstreams.count == 2)
        #expect(parsed.independentSubstreams[1].bsmod == .dialogue)
    }

    @Test
    func dependentSubstreamWithChannelLocation() async throws {
        let substream = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: false,
            bsmod: .completeMain, acmod: .threeTwo, lfeon: true,
            dependentSubstreamCount: 1,
            dependentSubstreamChannelLocation: 0x100
        )
        let box = EC3SpecificBox(
            dataRate: 384,
            independentSubstreams: [substream]
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EC3SpecificBox)
        #expect(parsed.independentSubstreams[0].dependentSubstreamCount == 1)
        #expect(parsed.independentSubstreams[0].dependentSubstreamChannelLocation == 0x100)
    }

    @Test
    func withExtensionTypeA() async throws {
        let substream = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: false,
            bsmod: .completeMain, acmod: .stereo, lfeon: false,
            dependentSubstreamCount: 0
        )
        let box = EC3SpecificBox(
            dataRate: 192,
            independentSubstreams: [substream],
            ec3ExtensionTypeA: 0x42
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EC3SpecificBox)
        #expect(parsed.ec3ExtensionTypeA == 0x42)
    }

    @Test
    func dataRatePreserved() async throws {
        let substream = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: false,
            bsmod: .completeMain, acmod: .stereo, lfeon: false,
            dependentSubstreamCount: 0
        )
        let box = EC3SpecificBox(
            dataRate: 1024,
            independentSubstreams: [substream]
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EC3SpecificBox)
        #expect(parsed.dataRate == 1024)
    }

    @Test
    func boxTypeIsDec3() {
        #expect(EC3SpecificBox.boxType == "dec3")
    }
}
