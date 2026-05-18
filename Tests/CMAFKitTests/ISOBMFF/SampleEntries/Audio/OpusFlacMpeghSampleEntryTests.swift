// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("OpusSampleEntry")
struct OpusSampleEntryTests {

    @Test
    func monoStereoRoundTrip() async throws {
        let entry = OpusSampleEntry(
            audioFields: AudioSampleEntryFields(),
            specificBox: OpusSpecificBox(
                outputChannelCount: 2,
                preSkip: 312,
                inputSampleRate: 48000,
                channelMappingFamily: .rtpMonoStereo
            )
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OpusSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func vorbisFiveOneRoundTrip() async throws {
        let table = OpusSpecificBox.ChannelMappingTable(
            streamCount: 4,
            coupledCount: 2,
            channelMapping: [0, 4, 1, 2, 3, 5]
        )
        let entry = OpusSampleEntry(
            audioFields: AudioSampleEntryFields(channelCount: 6),
            specificBox: OpusSpecificBox(
                outputChannelCount: 6,
                preSkip: 312,
                inputSampleRate: 48000,
                channelMappingFamily: .vorbisMultichannel,
                channelMappingTable: table
            )
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OpusSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func boxTypeIsOpus() {
        #expect(OpusSampleEntry.boxType == "Opus")
    }
}

@Suite("FLACSampleEntry")
struct FLACSampleEntryTests {

    private static func makeFLACBox(channels: UInt8 = 2, sampleRate: UInt32 = 48000) -> FLACSpecificBox {
        let info = FLACStreamInfo(
            minBlockSize: 4096,
            maxBlockSize: 4096,
            minFrameSize: 14,
            maxFrameSize: 4096,
            sampleRate: sampleRate,
            channels: channels,
            bitsPerSample: 16,
            totalSamples: 0,
            md5: Data(repeating: 0xAB, count: 16)
        )
        let block = FLACSpecificBox.FLACMetadataBlock(
            isLast: true,
            blockType: .streamInfo,
            blockData: info.encode()
        )
        return FLACSpecificBox(metadataBlocks: [block])
    }

    @Test
    func stereoRoundTrip() async throws {
        let entry = FLACSampleEntry(
            audioFields: AudioSampleEntryFields(),
            specificBox: Self.makeFLACBox()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FLACSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func multiChannelRoundTrip() async throws {
        let entry = FLACSampleEntry(
            audioFields: AudioSampleEntryFields(channelCount: 6),
            specificBox: Self.makeFLACBox(channels: 6, sampleRate: 96000)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FLACSampleEntry)
        #expect(parsed == entry)
        #expect(parsed.specificBox.streamInfo?.channels == 6)
    }

    @Test
    func boxTypeIsFLaC() {
        #expect(FLACSampleEntry.boxType == "fLaC")
    }
}

@Suite("MPEGHAudioSampleEntry (mhm1)")
struct MPEGHAudioSampleEntryTests {

    @Test
    func minimalRoundTrip() async throws {
        let entry = MPEGHAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            configuration: MPEGHConfigurationBox(
                profileLevelIndication: .lcProfileLevel3,
                referenceChannelLayout: 6,
                mpegh3daConfig: Data([0x01, 0x02])
            )
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MPEGHAudioSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func withCompatibilitySetRoundTrip() async throws {
        let entry = MPEGHAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            configuration: MPEGHConfigurationBox(
                profileLevelIndication: .lcProfileLevel3,
                referenceChannelLayout: 6,
                mpegh3daConfig: Data([0x01, 0x02])
            ),
            compatibilitySet: MPEGHProfileLevelCompatibilitySetBox(
                compatibleProfileLevels: [.lcProfileLevel1, .lcProfileLevel2]
            )
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MPEGHAudioSampleEntry)
        #expect(parsed == entry)
        #expect(parsed.compatibilitySet?.compatibleProfileLevels.count == 2)
    }

    @Test
    func boxTypeIsMhm1() {
        #expect(MPEGHAudioSampleEntry.boxType == "mhm1")
    }
}

@Suite("MPEGHAudioSampleEntryMultiStream (mhm2)")
struct MPEGHAudioSampleEntryMultiStreamTests {

    @Test
    func minimalRoundTrip() async throws {
        let entry = MPEGHAudioSampleEntryMultiStream(
            audioFields: AudioSampleEntryFields(),
            configuration: MPEGHConfigurationBox(
                profileLevelIndication: .lcProfileLevel3,
                referenceChannelLayout: 6,
                mpegh3daConfig: Data([0x01])
            )
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MPEGHAudioSampleEntryMultiStream)
        #expect(parsed == entry)
    }

    @Test
    func boxTypeIsMhm2() {
        #expect(MPEGHAudioSampleEntryMultiStream.boxType == "mhm2")
    }
}
