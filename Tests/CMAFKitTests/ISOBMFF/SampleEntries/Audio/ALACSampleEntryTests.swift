// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// ALACSampleEntry round-trip + BoxRegistry dispatch.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ALACSampleEntry — round-trip")
struct ALACSampleEntryRoundTripTests {

    private func canonicalAudioFields(
        channels: UInt16 = 2,
        sampleRate: UInt32 = 44_100
    ) -> AudioSampleEntryFields {
        AudioSampleEntryFields(
            channelCount: channels,
            sampleSize: 16,
            sampleRate: UInt32(sampleRate << 16))
    }

    @Test func minimalEntryStereo16BitRoundTrips() async throws {
        let entry = ALACSampleEntry(
            audioFields: canonicalAudioFields(),
            specificBox: ALACSpecificBox(
                bitDepth: 16,
                numChannels: 2,
                maxFrameBytes: 4096,
                avgBitRate: 0,
                sampleRate: 44_100))
        try await assertRoundTrip(entry)
    }

    @Test func highResStereo24Bit96kRoundTrips() async throws {
        let entry = ALACSampleEntry(
            audioFields: canonicalAudioFields(channels: 2, sampleRate: 96_000),
            specificBox: ALACSpecificBox(
                bitDepth: 24,
                numChannels: 2,
                maxFrameBytes: 8192,
                avgBitRate: 1_536_000,
                sampleRate: 96_000))
        try await assertRoundTrip(entry)
    }

    @Test func multichannel51RoundTripsWithChnl() async throws {
        let chnl = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .predefined(
                layout: .fiveOne, omittedChannelsMap: 0))
        let entry = ALACSampleEntry(
            audioFields: canonicalAudioFields(channels: 6, sampleRate: 48_000),
            specificBox: ALACSpecificBox(
                bitDepth: 24,
                numChannels: 6,
                maxFrameBytes: 16_384,
                avgBitRate: 4_608_000,
                sampleRate: 48_000),
            extensions: AudioSampleEntryExtensions(channelLayout: chnl))
        try await assertRoundTrip(entry)
    }

    @Test func parseFailsWhenChildIsNotAlac() async throws {
        // Synthesise an audio sample entry with a child whose fourCC is
        // not "alac" — parse must throw.
        var writer = BinaryWriter()
        writer.writeBox(type: "alac") { body in
            canonicalAudioFields().encode(to: &body)
            // Write a `dfLa` (FLAC) box where `alac` is expected.
            body.writeBox(type: "dfLa") { inner in
                inner.writeUInt32(0)  // FullBox v/f
                inner.writeUInt8(0)  // last-metadata-block-flag + type
                inner.writeUInt24(0)  // length=0
            }
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test func boxRegistryResolvesAlacToSampleEntry() async throws {
        let entry = ALACSampleEntry(
            audioFields: canonicalAudioFields(),
            specificBox: ALACSpecificBox(
                bitDepth: 16, numChannels: 2,
                maxFrameBytes: 4096, avgBitRate: 0, sampleRate: 44_100))
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        // The global registry maps `alac` to ALACSampleEntry — not
        // ALACSpecificBox. This is the collision-resolution doctrine.
        #expect(boxes.first is ALACSampleEntry)
    }

    private func assertRoundTrip(
        _ entry: ALACSampleEntry,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(
            boxes.first as? ALACSampleEntry, sourceLocation: sourceLocation)
        #expect(parsed == entry, sourceLocation: sourceLocation)
    }
}
