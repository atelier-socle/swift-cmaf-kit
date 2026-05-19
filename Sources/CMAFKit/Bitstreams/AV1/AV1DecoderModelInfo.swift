// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AV1DecoderModelInfo / AV1OperatingParametersInfo
//
// Reference: AOMedia AV1 Bitstream §5.5.4 (decoder_model_info) +
// §5.5.3 (operating_parameters_info).

import Foundation

/// AV1 decoder model info per AOMedia AV1 Bitstream §5.5.4.
public struct AV1DecoderModelInfo: Sendable, Hashable, Equatable {
    /// 5-bit `buffer_delay_length_minus_1`. The buffer-delay fields in
    /// per-operating-point `operating_parameters_info` are
    /// `bufferDelayLengthMinus1 + 1` bits wide.
    public let bufferDelayLengthMinus1: UInt8
    /// 32-bit `num_units_in_decoding_tick`.
    public let numUnitsInDecodingTick: UInt32
    /// 5-bit `buffer_removal_time_length_minus_1`.
    public let bufferRemovalTimeLengthMinus1: UInt8
    /// 5-bit `frame_presentation_time_length_minus_1`.
    public let framePresentationTimeLengthMinus1: UInt8

    public init(
        bufferDelayLengthMinus1: UInt8,
        numUnitsInDecodingTick: UInt32,
        bufferRemovalTimeLengthMinus1: UInt8,
        framePresentationTimeLengthMinus1: UInt8
    ) {
        precondition(bufferDelayLengthMinus1 <= 0x1F, "bufferDelayLengthMinus1 must fit 5 bits")
        precondition(bufferRemovalTimeLengthMinus1 <= 0x1F, "bufferRemovalTimeLengthMinus1 must fit 5 bits")
        precondition(framePresentationTimeLengthMinus1 <= 0x1F, "framePresentationTimeLengthMinus1 must fit 5 bits")
        self.bufferDelayLengthMinus1 = bufferDelayLengthMinus1
        self.numUnitsInDecodingTick = numUnitsInDecodingTick
        self.bufferRemovalTimeLengthMinus1 = bufferRemovalTimeLengthMinus1
        self.framePresentationTimeLengthMinus1 = framePresentationTimeLengthMinus1
    }

    public static func parse(reader: inout BitReader) throws -> AV1DecoderModelInfo {
        let bufferDelay = UInt8(try reader.readBits(5))
        let numUnits = UInt32(try reader.readBits(32))
        let bufferRemoval = UInt8(try reader.readBits(5))
        let framePresentation = UInt8(try reader.readBits(5))
        return AV1DecoderModelInfo(
            bufferDelayLengthMinus1: bufferDelay,
            numUnitsInDecodingTick: numUnits,
            bufferRemovalTimeLengthMinus1: bufferRemoval,
            framePresentationTimeLengthMinus1: framePresentation
        )
    }

    public func encode(to writer: inout BitWriter) {
        writer.writeBits(UInt64(bufferDelayLengthMinus1 & 0x1F), count: 5)
        writer.writeBits(UInt64(numUnitsInDecodingTick), count: 32)
        writer.writeBits(UInt64(bufferRemovalTimeLengthMinus1 & 0x1F), count: 5)
        writer.writeBits(UInt64(framePresentationTimeLengthMinus1 & 0x1F), count: 5)
    }
}

/// AV1 operating parameters info per AOMedia AV1 Bitstream §5.5.3.
public struct AV1OperatingParametersInfo: Sendable, Hashable, Equatable {
    /// `decoder_buffer_delay[op]` — width is `bufferDelayLengthMinus1 + 1`.
    public let decoderBufferDelay: UInt32
    /// `encoder_buffer_delay[op]` — same width.
    public let encoderBufferDelay: UInt32
    /// `low_delay_mode_flag[op]`.
    public let lowDelayModeFlag: Bool

    public init(
        decoderBufferDelay: UInt32,
        encoderBufferDelay: UInt32,
        lowDelayModeFlag: Bool
    ) {
        self.decoderBufferDelay = decoderBufferDelay
        self.encoderBufferDelay = encoderBufferDelay
        self.lowDelayModeFlag = lowDelayModeFlag
    }

    public static func parse(
        reader: inout BitReader,
        bufferDelayLengthMinus1: UInt8
    ) throws -> AV1OperatingParametersInfo {
        let count = Int(bufferDelayLengthMinus1) + 1
        let decoderDelay = UInt32(try reader.readBits(count))
        let encoderDelay = UInt32(try reader.readBits(count))
        let lowDelay = try reader.readBool()
        return AV1OperatingParametersInfo(
            decoderBufferDelay: decoderDelay,
            encoderBufferDelay: encoderDelay,
            lowDelayModeFlag: lowDelay
        )
    }

    public func encode(
        to writer: inout BitWriter,
        bufferDelayLengthMinus1: UInt8
    ) {
        let count = Int(bufferDelayLengthMinus1) + 1
        writer.writeBits(UInt64(decoderBufferDelay), count: count)
        writer.writeBits(UInt64(encoderBufferDelay), count: count)
        writer.writeBool(lowDelayModeFlag)
    }
}
