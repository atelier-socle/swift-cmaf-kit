// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("OpusSpecificBox")
struct OpusSpecificBoxTests {

    @Test
    func monoStereoRoundTrip() async throws {
        let box = OpusSpecificBox(
            outputChannelCount: 2,
            preSkip: 312,
            inputSampleRate: 48000,
            outputGainQ78: 0,
            channelMappingFamily: .rtpMonoStereo
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OpusSpecificBox)
        #expect(parsed == box)
        #expect(parsed.channelMappingTable == nil)
    }

    @Test
    func vorbisFiveOneRoundTrip() async throws {
        let table = OpusSpecificBox.ChannelMappingTable(
            streamCount: 4,
            coupledCount: 2,
            channelMapping: [0, 4, 1, 2, 3, 5]
        )
        let box = OpusSpecificBox(
            outputChannelCount: 6,
            preSkip: 312,
            inputSampleRate: 48000,
            outputGainQ78: 0,
            channelMappingFamily: .vorbisMultichannel,
            channelMappingTable: table
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OpusSpecificBox)
        #expect(parsed == box)
        #expect(parsed.channelMappingTable?.channelMapping.count == 6)
    }

    @Test
    func ambisonicsRoundTrip() async throws {
        let table = OpusSpecificBox.ChannelMappingTable(
            streamCount: 4,
            coupledCount: 0,
            channelMapping: [0, 1, 2, 3]
        )
        let box = OpusSpecificBox(
            outputChannelCount: 4,
            preSkip: 312,
            inputSampleRate: 48000,
            outputGainQ78: 0,
            channelMappingFamily: .ambisonics,
            channelMappingTable: table
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OpusSpecificBox)
        #expect(parsed == box)
    }

    @Test
    func outputGainQ78Decoding() {
        // +6 dB ≈ 0x0600 (1536 raw / 256 = 6.0)
        let box = OpusSpecificBox(
            outputChannelCount: 2,
            preSkip: 0,
            inputSampleRate: 48000,
            outputGainQ78: 1536,
            channelMappingFamily: .rtpMonoStereo
        )
        #expect(box.outputGainDB == 6.0)
    }

    @Test
    func negativeOutputGainQ78Decoding() {
        // -3 dB ≈ -768 raw / 256.
        let box = OpusSpecificBox(
            outputChannelCount: 2,
            preSkip: 0,
            inputSampleRate: 48000,
            outputGainQ78: -768,
            channelMappingFamily: .rtpMonoStereo
        )
        #expect(box.outputGainDB == -3.0)
    }

    @Test
    func negativeOutputGainRoundTrip() async throws {
        let box = OpusSpecificBox(
            outputChannelCount: 2,
            preSkip: 312,
            inputSampleRate: 48000,
            outputGainQ78: -512,
            channelMappingFamily: .rtpMonoStereo
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OpusSpecificBox)
        #expect(parsed.outputGainQ78 == -512)
    }

    @Test
    func inputSampleRatePreserved() async throws {
        let box = OpusSpecificBox(
            outputChannelCount: 2,
            preSkip: 312,
            inputSampleRate: 96000,
            channelMappingFamily: .rtpMonoStereo
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OpusSpecificBox)
        #expect(parsed.inputSampleRate == 96000)
    }

    @Test
    func rejectsUnknownChannelMappingFamily() async throws {
        // dOps with channelMappingFamily=42 (not in our enum).
        var box = BinaryWriter()
        box.writeBox(type: "dOps") { body in
            body.writeUInt8(0)  // version
            body.writeUInt8(2)  // outputChannelCount
            body.writeUInt16(312)  // preSkip
            body.writeUInt32(48000)  // inputSampleRate
            body.writeUInt16(0)  // outputGain
            body.writeUInt8(42)  // family
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: box.data, using: registry)
        }
    }

    @Test
    func boxTypeIsDOps() {
        #expect(OpusSpecificBox.boxType == "dOps")
    }
}
