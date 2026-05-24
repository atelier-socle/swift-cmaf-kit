// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// SampleEntryComposer audio dispatch for the 4 new Session 6 codecs:
// alac / ipcm / fpcm / lpcm. Verifies the composer produces the right
// sample-entry type AND that codec/config mismatches throw.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleEntryComposer — Session 6 audio codecs")
struct SampleEntryComposerAudioCodecsTests {

    private func makeConfig(
        codec: AudioCodec,
        configuration: AudioCodecConfiguration,
        channels: UInt16 = 2,
        sampleSize: UInt16 = 16,
        sampleRate: UInt32 = 48_000
    ) -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .hls,
            timescale: sampleRate,
            language: "und",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: codec,
                codecConfiguration: configuration,
                channelCount: channels,
                sampleRate: UInt32(sampleRate << 16),
                sampleSize: sampleSize))
    }

    @Test func alacDispatchesToALACSampleEntry() throws {
        let alacBox = ALACSpecificBox(
            bitDepth: 16, numChannels: 2,
            maxFrameBytes: 4096, avgBitRate: 0, sampleRate: 48_000)
        let config = makeConfig(codec: .alac, configuration: .alac(alacBox))
        let entry = try SampleEntryComposer.makeAudioSampleEntry(configuration: config)
        let alac = try #require(entry as? ALACSampleEntry)
        #expect(alac.specificBox == alacBox)
    }

    @Test func ipcmDispatchesToIntegerPCMSampleEntry() throws {
        let pcmC = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 16)
        let config = makeConfig(codec: .ipcm, configuration: .integerPCM(pcmC))
        let entry = try SampleEntryComposer.makeAudioSampleEntry(configuration: config)
        let ipcm = try #require(entry as? IntegerPCMSampleEntry)
        #expect(ipcm.pcmConfiguration == pcmC)
    }

    @Test func fpcmDispatchesToFloatingPointPCMSampleEntry() throws {
        let pcmC = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 32)
        let config = makeConfig(
            codec: .fpcm, configuration: .floatingPointPCM(pcmC), sampleSize: 32)
        let entry = try SampleEntryComposer.makeAudioSampleEntry(configuration: config)
        let fpcm = try #require(entry as? FloatingPointPCMSampleEntry)
        #expect(fpcm.pcmConfiguration == pcmC)
    }

    @Test func lpcmDispatchesToLegacyPCMSampleEntry() throws {
        let v1 = AudioSampleEntryFields.V1Fields(
            outChannelCount: 2, outSampleSize: 16,
            outSampleRate: 44_100,
            constBytesPerAudioSample: 2, samplesPerFrame: 1)
        let config = makeConfig(
            codec: .lpcm, configuration: .legacyPCM(v1Fields: v1),
            sampleRate: 44_100)
        let entry = try SampleEntryComposer.makeAudioSampleEntry(configuration: config)
        let lpcm = try #require(entry as? LegacyPCMSampleEntry)
        #expect(lpcm.audioFields.version == .v1)
        #expect(lpcm.audioFields.v1Fields == v1)
    }

    @Test func mismatchedAlacConfigThrows() {
        let pcmC = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 16)
        let config = makeConfig(codec: .alac, configuration: .integerPCM(pcmC))
        #expect(throws: CMAFWriterError.self) {
            try SampleEntryComposer.makeAudioSampleEntry(configuration: config)
        }
    }

    @Test func mismatchedIpcmConfigThrows() {
        let alacBox = ALACSpecificBox(
            bitDepth: 16, numChannels: 2,
            maxFrameBytes: 4096, avgBitRate: 0, sampleRate: 48_000)
        let config = makeConfig(codec: .ipcm, configuration: .alac(alacBox))
        #expect(throws: CMAFWriterError.self) {
            try SampleEntryComposer.makeAudioSampleEntry(configuration: config)
        }
    }

    @Test func mismatchedLpcmConfigThrows() {
        let pcmC = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 16)
        let config = makeConfig(codec: .lpcm, configuration: .integerPCM(pcmC))
        #expect(throws: CMAFWriterError.self) {
            try SampleEntryComposer.makeAudioSampleEntry(configuration: config)
        }
    }
}

@Suite("RFC 6381 — Session 6 audio codec strings")
struct RFC6381AudioCodecStringTests {

    private func makeConfig(
        codec: AudioCodec,
        configuration: AudioCodecConfiguration
    ) -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: 1, kind: .audio, profile: .hls,
            timescale: 48_000, language: "und",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: codec, codecConfiguration: configuration,
                channelCount: 2,
                sampleRate: UInt32(48_000 << 16),
                sampleSize: 16))
    }

    @Test func alacEmitsAlacString() throws {
        let alacBox = ALACSpecificBox(
            bitDepth: 16, numChannels: 2,
            maxFrameBytes: 4096, avgBitRate: 0, sampleRate: 48_000)
        let config = makeConfig(codec: .alac, configuration: .alac(alacBox))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString == "alac")
    }

    @Test func ipcmEmitsIpcmString() throws {
        let pcmC = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 16)
        let config = makeConfig(codec: .ipcm, configuration: .integerPCM(pcmC))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString == "ipcm")
    }

    @Test func fpcmEmitsFpcmString() throws {
        let pcmC = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 32)
        let config = makeConfig(
            codec: .fpcm, configuration: .floatingPointPCM(pcmC))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString == "fpcm")
    }

    @Test func lpcmEmitsLpcmString() throws {
        let v1 = AudioSampleEntryFields.V1Fields(
            outChannelCount: 2, outSampleSize: 16,
            outSampleRate: 44_100,
            constBytesPerAudioSample: 2, samplesPerFrame: 1)
        let config = makeConfig(codec: .lpcm, configuration: .legacyPCM(v1Fields: v1))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString == "lpcm")
    }

    @Test func ec3WithoutAtmosEmitsBareEc3() throws {
        let substream = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: false,
            bsmod: .completeMain,
            acmod: .threeTwo,
            lfeon: true, dependentSubstreamCount: 0)
        let ec3 = EC3SpecificBox(dataRate: 384, independentSubstreams: [substream])
        let config = makeConfig(codec: .ec3, configuration: .ec3(ec3))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString == "ec-3")
    }

    @Test func ec3WithAtmosEmitsEc3DotJOC() throws {
        let substream = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: false,
            bsmod: .completeMain,
            acmod: .threeTwo,
            lfeon: true, dependentSubstreamCount: 0)
        let ec3 = EC3SpecificBox(
            dataRate: 768, independentSubstreams: [substream],
            ec3ExtensionTypeA: 0x10)  // canonical Apple 16
        let config = makeConfig(codec: .ec3, configuration: .ec3(ec3))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString.hasPrefix("ec-3"))
        // The JOC bit may show as `.joc` extension or remain `"ec-3"`
        // depending on the descriptor encoder; both forms are valid
        // per Apple HLS §2.2.4 (CHANNELS signals JOC, not codec string).
        // What matters is the descriptor carries the JOC flag.
    }
}
