// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AudioSpecificConfig")
struct AudioSpecificConfigTests {

    @Test
    func aacLCStereo48kRoundTrip() throws {
        let asc = AudioSpecificConfig(
            audioObjectType: .aacLC,
            samplingFrequency: .indexed(.freq48000),
            channelConfiguration: .stereo,
            gaSpecificConfig: GASpecificConfig(
                frameLengthFlag: false,
                dependsOnCoreCoder: false,
                extensionFlag: false
            )
        )
        let encoded = asc.encode()
        let decoded = try AudioSpecificConfig.parse(bitstream: encoded)
        #expect(decoded == asc)
    }

    @Test
    func aacLCStereo44_1kRoundTrip() throws {
        let asc = AudioSpecificConfig(
            audioObjectType: .aacLC,
            samplingFrequency: .indexed(.freq44100),
            channelConfiguration: .stereo,
            gaSpecificConfig: GASpecificConfig(
                frameLengthFlag: false,
                dependsOnCoreCoder: false,
                extensionFlag: false
            )
        )
        let encoded = asc.encode()
        let decoded = try AudioSpecificConfig.parse(bitstream: encoded)
        #expect(decoded == asc)
    }

    @Test
    func parseKnownAACLCStereo48kHex() throws {
        // 0x1190: AOT=2 (LC), sf_index=3 (48k), chan=2, frame=0, depcc=0, ext=0
        // Bits: 00010 0011 0010 000 + pad
        //       = 0001 0001 1001 0000 = 0x11 0x90
        let bytes = Data([0x11, 0x90])
        let asc = try AudioSpecificConfig.parse(bitstream: bytes)
        #expect(asc.audioObjectType == .aacLC)
        if case .indexed(let idx) = asc.samplingFrequency {
            #expect(idx == .freq48000)
        } else {
            Issue.record("expected indexed")
        }
        #expect(asc.channelConfiguration == .stereo)
    }

    @Test
    func explicitSamplingRateRoundTrip() throws {
        let asc = AudioSpecificConfig(
            audioObjectType: .aacLC,
            samplingFrequency: .explicit(rate: 32_000),
            channelConfiguration: .stereo,
            gaSpecificConfig: GASpecificConfig(
                frameLengthFlag: false,
                dependsOnCoreCoder: false,
                extensionFlag: false
            )
        )
        let encoded = asc.encode()
        let decoded = try AudioSpecificConfig.parse(bitstream: encoded)
        if case .explicit(let rate) = decoded.samplingFrequency {
            #expect(rate == 32_000)
        } else {
            Issue.record("expected explicit")
        }
    }

    @Test
    func mpeg4AOTViaEscapeRoundTrip() throws {
        let asc = AudioSpecificConfig(
            audioObjectType: .usac,
            samplingFrequency: .indexed(.freq48000),
            channelConfiguration: .stereo
        )
        let encoded = asc.encode()
        let decoded = try AudioSpecificConfig.parse(bitstream: encoded)
        #expect(decoded.audioObjectType == .usac)
    }

    @Test
    func erAACLDRoundTrip() throws {
        let asc = AudioSpecificConfig(
            audioObjectType: .erAACLD,
            samplingFrequency: .indexed(.freq48000),
            channelConfiguration: .stereo,
            gaSpecificConfig: GASpecificConfig(
                frameLengthFlag: false,
                dependsOnCoreCoder: false,
                extensionFlag: false
            )
        )
        let encoded = asc.encode()
        let decoded = try AudioSpecificConfig.parse(bitstream: encoded)
        #expect(decoded == asc)
    }

    @Test
    func aac5_1RoundTrip() throws {
        let asc = AudioSpecificConfig(
            audioObjectType: .aacLC,
            samplingFrequency: .indexed(.freq48000),
            channelConfiguration: .fiveOne,
            gaSpecificConfig: GASpecificConfig(
                frameLengthFlag: false,
                dependsOnCoreCoder: false,
                extensionFlag: false
            )
        )
        let encoded = asc.encode()
        let decoded = try AudioSpecificConfig.parse(bitstream: encoded)
        #expect(decoded.channelConfiguration == .fiveOne)
    }

    @Test
    func rejectsUnknownAOT() {
        // 5-bit AOT = 0 is also valid (allCases-checked), but the
        // escape pattern with raw 32 maps to layer1 which exists.
        // Use 5-bit 30 (mpegSurround) — that exists. Try 4 + 0
        // escape that would produce 32 (layer1) — also exists.
        // Try escape with payload 63 → 32+63 = 95, no enum case.
        let bytes = Data([0xFF, 0xC0, 0x00])  // raw 32+63 = 95
        #expect(throws: BitstreamError.self) {
            _ = try AudioSpecificConfig.parse(bitstream: bytes)
        }
    }
}

@Suite("GASpecificConfig")
struct GASpecificConfigTests {

    @Test
    func defaultGAConfigRoundTrip() throws {
        let ga = GASpecificConfig(
            frameLengthFlag: false,
            dependsOnCoreCoder: false,
            extensionFlag: false
        )
        var writer = BitWriter()
        ga.encode(to: &writer, audioObjectType: .aacLC)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try GASpecificConfig.parse(
            reader: &reader,
            audioObjectType: .aacLC,
            channelConfiguration: .stereo
        )
        #expect(decoded == ga)
    }

    @Test
    func dependsOnCoreCoderRoundTrip() throws {
        let ga = GASpecificConfig(
            frameLengthFlag: false,
            dependsOnCoreCoder: true,
            coreCoderDelay: 1024,
            extensionFlag: false
        )
        var writer = BitWriter()
        ga.encode(to: &writer, audioObjectType: .aacLC)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try GASpecificConfig.parse(
            reader: &reader,
            audioObjectType: .aacLC,
            channelConfiguration: .stereo
        )
        #expect(decoded == ga)
        #expect(decoded.coreCoderDelay == 1024)
    }

    @Test
    func scalableLayerNrRoundTrip() throws {
        let ga = GASpecificConfig(
            frameLengthFlag: false,
            dependsOnCoreCoder: false,
            extensionFlag: false,
            layerNr: 2
        )
        var writer = BitWriter()
        ga.encode(to: &writer, audioObjectType: .aacScalable)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try GASpecificConfig.parse(
            reader: &reader,
            audioObjectType: .aacScalable,
            channelConfiguration: .stereo
        )
        #expect(decoded.layerNr == 2)
    }
}
