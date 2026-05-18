// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("MP4AudioSampleEntry")
struct MP4AudioSampleEntryTests {

    private static func makeESDS() -> ElementaryStreamDescriptor {
        ElementaryStreamDescriptor(
            esID: 1,
            decoderConfig: ElementaryStreamDescriptor.DecoderConfigDescriptor(
                objectTypeIndication: .audioISO14496_3,
                streamType: .audioStream,
                upStream: false,
                bufferSizeDB: 1536,
                maxBitrate: 128_000,
                avgBitrate: 96_000,
                decoderSpecificInfo: Data([0x12, 0x10])
            )
        )
    }

    @Test
    func stereo48kRoundTrip() async throws {
        let entry = MP4AudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            elementaryStreamDescriptor: Self.makeESDS()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MP4AudioSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func withChannelLayoutExtensionRoundTrip() async throws {
        let chnl = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .predefined(layout: .fiveOne, omittedChannelsMap: 0)
        )
        let entry = MP4AudioSampleEntry(
            audioFields: AudioSampleEntryFields(channelCount: 6),
            elementaryStreamDescriptor: Self.makeESDS(),
            extensions: AudioSampleEntryExtensions(channelLayout: chnl)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MP4AudioSampleEntry)
        #expect(parsed.extensions.channelLayout == chnl)
        #expect(parsed == entry)
    }

    @Test
    func withSamplingRateExtensionRoundTrip() async throws {
        let srat = SamplingRateBox(samplingRate: 96000)
        let entry = MP4AudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            elementaryStreamDescriptor: Self.makeESDS(),
            extensions: AudioSampleEntryExtensions(samplingRate: srat)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MP4AudioSampleEntry)
        #expect(parsed.extensions.samplingRate?.samplingRate == 96000)
    }

    @Test
    func v1FieldsRoundTrip() async throws {
        let v1 = AudioSampleEntryFields.V1Fields(
            outChannelCount: 2,
            outSampleSize: 16,
            outSampleRate: 0xBB80_0000,
            constBytesPerAudioSample: 0,
            samplesPerFrame: 1024
        )
        let fields = AudioSampleEntryFields(version: .v1, v1Fields: v1)
        let entry = MP4AudioSampleEntry(
            audioFields: fields,
            elementaryStreamDescriptor: Self.makeESDS()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MP4AudioSampleEntry)
        #expect(parsed.audioFields.version == .v1)
        #expect(parsed.audioFields.v1Fields == v1)
    }

    @Test
    func boxTypeIsMp4a() {
        #expect(MP4AudioSampleEntry.boxType == "mp4a")
    }
}

@Suite("AC3SampleEntry")
struct AC3SampleEntryTests {

    @Test
    func stereoRoundTrip() async throws {
        let entry = AC3SampleEntry(
            audioFields: AudioSampleEntryFields(),
            specificBox: AC3SpecificBox(
                fscod: .freq48000,
                bsid: 8,
                bsmod: .completeMain,
                acmod: .stereo,
                lfeon: false,
                bitRateCode: 6
            )
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC3SampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func fiveOneRoundTrip() async throws {
        let entry = AC3SampleEntry(
            audioFields: AudioSampleEntryFields(channelCount: 6),
            specificBox: AC3SpecificBox(
                fscod: .freq48000,
                bsid: 8,
                bsmod: .completeMain,
                acmod: .threeTwo,
                lfeon: true,
                bitRateCode: 12
            )
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC3SampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func boxTypeIsAc3() {
        #expect(AC3SampleEntry.boxType == "ac-3")
    }
}

@Suite("EC3SampleEntry")
struct EC3SampleEntryTests {

    @Test
    func singleSubstreamRoundTrip() async throws {
        let sub = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: false,
            bsmod: .completeMain, acmod: .threeTwo, lfeon: true,
            dependentSubstreamCount: 0
        )
        let entry = EC3SampleEntry(
            audioFields: AudioSampleEntryFields(channelCount: 6),
            specificBox: EC3SpecificBox(dataRate: 384, independentSubstreams: [sub])
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EC3SampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func boxTypeIsEc3() {
        #expect(EC3SampleEntry.boxType == "ec-3")
    }
}

@Suite("AC4SampleEntry")
struct AC4SampleEntryTests {

    @Test
    func emptyPresentationsRoundTrip() async throws {
        let entry = AC4SampleEntry(
            audioFields: AudioSampleEntryFields(),
            specificBox: AC4SpecificBox(bitstreamVersion: 2, presentations: [])
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC4SampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func withPresentationRoundTrip() async throws {
        let presentation = AC4SpecificBox.PresentationEntry(
            presentationVersion: 1,
            presentationConfig: 0x20,
            presentationLength: 4,
            presentationBytes: Data([0x01, 0x02, 0x03, 0x04])
        )
        let entry = AC4SampleEntry(
            audioFields: AudioSampleEntryFields(channelCount: 6),
            specificBox: AC4SpecificBox(
                bitstreamVersion: 2,
                presentations: [presentation]
            )
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC4SampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func boxTypeIsAc4() {
        #expect(AC4SampleEntry.boxType == "ac-4")
    }
}
