// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AV1DecoderModelInfo")
struct AV1DecoderModelInfoTests {

    @Test
    func roundTrip() throws {
        let model = AV1DecoderModelInfo(
            bufferDelayLengthMinus1: 23,
            numUnitsInDecodingTick: 1_001,
            bufferRemovalTimeLengthMinus1: 23,
            framePresentationTimeLengthMinus1: 23
        )
        var writer = BitWriter()
        model.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AV1DecoderModelInfo.parse(reader: &reader)
        #expect(decoded == model)
    }

    @Test
    func bitWidthsPreserved() throws {
        let model = AV1DecoderModelInfo(
            bufferDelayLengthMinus1: 0x1F,
            numUnitsInDecodingTick: UInt32.max,
            bufferRemovalTimeLengthMinus1: 0x1F,
            framePresentationTimeLengthMinus1: 0x1F
        )
        var writer = BitWriter()
        model.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AV1DecoderModelInfo.parse(reader: &reader)
        #expect(decoded.bufferDelayLengthMinus1 == 0x1F)
        #expect(decoded.numUnitsInDecodingTick == UInt32.max)
    }
}

@Suite("AV1OperatingParametersInfo")
struct AV1OperatingParametersInfoTests {

    @Test
    func roundTrip() throws {
        let params = AV1OperatingParametersInfo(
            decoderBufferDelay: 1000,
            encoderBufferDelay: 1000,
            lowDelayModeFlag: false
        )
        var writer = BitWriter()
        params.encode(to: &writer, bufferDelayLengthMinus1: 15)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AV1OperatingParametersInfo.parse(
            reader: &reader, bufferDelayLengthMinus1: 15
        )
        #expect(decoded == params)
    }

    @Test
    func lowDelayModeRoundTrip() throws {
        let params = AV1OperatingParametersInfo(
            decoderBufferDelay: 1,
            encoderBufferDelay: 2,
            lowDelayModeFlag: true
        )
        var writer = BitWriter()
        params.encode(to: &writer, bufferDelayLengthMinus1: 23)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AV1OperatingParametersInfo.parse(
            reader: &reader, bufferDelayLengthMinus1: 23
        )
        #expect(decoded.lowDelayModeFlag == true)
    }
}
