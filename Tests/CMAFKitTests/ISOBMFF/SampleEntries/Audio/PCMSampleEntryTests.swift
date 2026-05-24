// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// IntegerPCMSampleEntry (ipcm), FloatingPointPCMSampleEntry (fpcm),
// LegacyPCMSampleEntry (lpcm) — round-trip + BoxRegistry dispatch.

import Foundation
import Testing

@testable import CMAFKit

@Suite("IntegerPCMSampleEntry — round-trip")
struct IntegerPCMSampleEntryTests {

    private func audioFields(
        channels: UInt16 = 2,
        sampleSize: UInt16 = 16, sampleRate: UInt32 = 48_000
    ) -> AudioSampleEntryFields {
        AudioSampleEntryFields(
            channelCount: channels,
            sampleSize: sampleSize,
            sampleRate: UInt32(sampleRate << 16))
    }

    @Test func stereo16Bit48kLittleEndianRoundTrips() async throws {
        let entry = IntegerPCMSampleEntry(
            audioFields: audioFields(),
            pcmConfiguration: PCMConfigurationBox(
                endianness: .littleEndian, pcmSampleSize: 16))
        try await assertRoundTrip(entry, codec: .integer)
    }

    @Test func multichannel24Bit96kRoundTripsWithChnl() async throws {
        let chnl = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .predefined(
                layout: .fiveOne, omittedChannelsMap: 0))
        let entry = IntegerPCMSampleEntry(
            audioFields: audioFields(channels: 6, sampleSize: 24, sampleRate: 96_000),
            pcmConfiguration: PCMConfigurationBox(
                endianness: .littleEndian, pcmSampleSize: 24),
            extensions: AudioSampleEntryExtensions(channelLayout: chnl))
        try await assertRoundTrip(entry, codec: .integer)
    }

    @Test func mono32Bit192kBigEndianRoundTrips() async throws {
        let entry = IntegerPCMSampleEntry(
            audioFields: audioFields(channels: 1, sampleSize: 32, sampleRate: 192_000),
            pcmConfiguration: PCMConfigurationBox(
                endianness: .bigEndian, pcmSampleSize: 32))
        try await assertRoundTrip(entry, codec: .integer)
    }

    @Test func parseRejectsIntegerEntryWithFloatSampleSize() async throws {
        // Build bytes manually: ipcm entry but pcmC declares 64-bit
        // (only valid for fpcm). Parse should throw on validation.
        var writer = BinaryWriter()
        writer.writeBox(type: "ipcm") { body in
            audioFields().encode(to: &body)
            PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 64)
                .encode(to: &body)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test func boxRegistryResolvesIpcmFourCC() async throws {
        let entry = IntegerPCMSampleEntry(
            audioFields: audioFields(),
            pcmConfiguration: PCMConfigurationBox(
                endianness: .littleEndian, pcmSampleSize: 16))
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is IntegerPCMSampleEntry)
    }

    @Test func parseRejectsIpcmWithWrongChildFourCC() async throws {
        // ipcm with a dfLa (FLAC) child where pcmC is expected.
        var writer = BinaryWriter()
        writer.writeBox(type: "ipcm") { body in
            audioFields().encode(to: &body)
            body.writeBox(type: "dfLa") { inner in
                inner.writeUInt32(0)
                inner.writeUInt8(0)
                inner.writeUInt24(0)
            }
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    private func assertRoundTrip(
        _ entry: IntegerPCMSampleEntry,
        codec: PCMSampleCodecKind,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(
            boxes.first as? IntegerPCMSampleEntry, sourceLocation: sourceLocation)
        #expect(parsed == entry, sourceLocation: sourceLocation)
    }
}

@Suite("FloatingPointPCMSampleEntry — round-trip")
struct FloatingPointPCMSampleEntryTests {

    private func audioFields() -> AudioSampleEntryFields {
        AudioSampleEntryFields(
            channelCount: 2, sampleSize: 32,
            sampleRate: UInt32(48_000 << 16))
    }

    @Test func stereo32BitFloatRoundTrips() async throws {
        let entry = FloatingPointPCMSampleEntry(
            audioFields: audioFields(),
            pcmConfiguration: PCMConfigurationBox(
                endianness: .littleEndian, pcmSampleSize: 32))
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FloatingPointPCMSampleEntry)
        #expect(parsed == entry)
    }

    @Test func stereo64BitFloatRoundTrips() async throws {
        let entry = FloatingPointPCMSampleEntry(
            audioFields: audioFields(),
            pcmConfiguration: PCMConfigurationBox(
                endianness: .littleEndian, pcmSampleSize: 64))
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FloatingPointPCMSampleEntry)
        #expect(parsed == entry)
    }

    @Test func parseRejectsFloatEntryWith16BitSampleSize() async throws {
        // 16-bit float (binary16 / half precision) is NOT a
        // CMAF-standard form per ISO/IEC 23003-5.
        var writer = BinaryWriter()
        writer.writeBox(type: "fpcm") { body in
            audioFields().encode(to: &body)
            PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 16)
                .encode(to: &body)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test func boxRegistryResolvesFpcmFourCC() async throws {
        let entry = FloatingPointPCMSampleEntry(
            audioFields: audioFields(),
            pcmConfiguration: PCMConfigurationBox(
                endianness: .littleEndian, pcmSampleSize: 32))
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is FloatingPointPCMSampleEntry)
    }

    @Test func parseRejectsFpcmWithWrongChildFourCC() async throws {
        var writer = BinaryWriter()
        writer.writeBox(type: "fpcm") { body in
            audioFields().encode(to: &body)
            body.writeBox(type: "dfLa") { inner in
                inner.writeUInt32(0)
                inner.writeUInt8(0)
                inner.writeUInt24(0)
            }
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }
}

@Suite("LegacyPCMSampleEntry — round-trip")
struct LegacyPCMSampleEntryTests {

    private func v1Fields(
        channels: UInt16 = 2,
        sampleSize: UInt16 = 16, sampleRate: UInt32 = 44_100
    ) -> AudioSampleEntryFields {
        AudioSampleEntryFields(
            version: .v1,
            channelCount: channels,
            sampleSize: sampleSize,
            sampleRate: UInt32(sampleRate << 16),
            v1Fields: AudioSampleEntryFields.V1Fields(
                outChannelCount: channels,
                outSampleSize: sampleSize,
                outSampleRate: sampleRate,
                constBytesPerAudioSample: UInt32(sampleSize / 8),
                samplesPerFrame: 1))
    }

    @Test func stereo16Bit44_1kRoundTrips() async throws {
        let entry = LegacyPCMSampleEntry(audioFields: v1Fields())
        try await assertRoundTrip(entry)
    }

    @Test func multichannel24Bit48kRoundTripsWithChnl() async throws {
        let chnl = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .predefined(
                layout: .fiveOne, omittedChannelsMap: 0))
        let entry = LegacyPCMSampleEntry(
            audioFields: v1Fields(channels: 6, sampleSize: 24, sampleRate: 48_000),
            extensions: AudioSampleEntryExtensions(channelLayout: chnl))
        try await assertRoundTrip(entry)
    }

    @Test func v1FieldsPreservedByteIdentically() async throws {
        let entry = LegacyPCMSampleEntry(
            audioFields: AudioSampleEntryFields(
                version: .v1,
                channelCount: 2, sampleSize: 16,
                sampleRate: UInt32(44_100 << 16),
                v1Fields: AudioSampleEntryFields.V1Fields(
                    outChannelCount: 2, outSampleSize: 16,
                    outSampleRate: 44_100,
                    constBytesPerAudioSample: 2, samplesPerFrame: 1)))
        try await assertRoundTrip(entry)
    }

    @Test func boxRegistryResolvesLpcmFourCC() async throws {
        let entry = LegacyPCMSampleEntry(audioFields: v1Fields())
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is LegacyPCMSampleEntry)
    }

    @Test func parseRejectsLpcmWithV0AudioFields() async throws {
        // Hand-craft an lpcm with version-0 audio fields — must be
        // rejected per ISO/IEC 14496-12 §12.2.3.2.
        var writer = BinaryWriter()
        writer.writeBox(type: "lpcm") { body in
            let v0 = AudioSampleEntryFields(
                version: .v0,
                channelCount: 2,
                sampleSize: 16,
                sampleRate: UInt32(44_100 << 16))
            v0.encode(to: &body)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    private func assertRoundTrip(
        _ entry: LegacyPCMSampleEntry,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(
            boxes.first as? LegacyPCMSampleEntry, sourceLocation: sourceLocation)
        #expect(parsed == entry, sourceLocation: sourceLocation)
    }
}
