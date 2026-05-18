// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - OpusSpecificBox (dOps)
//
// Reference: IETF "Encapsulation of Opus in ISO Base Media File Format"
// v1.0.0 §4.3.2.
//
// On-wire layout (after the 8-byte box header):
//   UInt8  version (always 0)
//   UInt8  outputChannelCount
//   UInt16 preSkip
//   UInt32 inputSampleRate
//   Int16  outputGain (Q7.8 fixed point dB)
//   UInt8  channelMappingFamily
//   If channelMappingFamily != 0:
//     UInt8 streamCount
//     UInt8 coupledCount
//     outputChannelCount × UInt8 channelMapping

import Foundation

/// Opus specific box (`dOps`).
public struct OpusSpecificBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "dOps"

    /// Channel mapping table; present iff
    /// ``channelMappingFamily`` is not ``OpusChannelMappingFamily/rtpMonoStereo``.
    public struct ChannelMappingTable: Sendable, Equatable, Hashable {
        public let streamCount: UInt8
        public let coupledCount: UInt8
        public let channelMapping: [UInt8]

        public init(streamCount: UInt8, coupledCount: UInt8, channelMapping: [UInt8]) {
            self.streamCount = streamCount
            self.coupledCount = coupledCount
            self.channelMapping = channelMapping
        }
    }

    /// Box version; always 0 per IETF spec.
    public let version: UInt8
    public let outputChannelCount: UInt8
    public let preSkip: UInt16
    public let inputSampleRate: UInt32
    /// Output gain in Q7.8 fixed-point dB.
    public let outputGainQ78: Int16
    public let channelMappingFamily: OpusChannelMappingFamily
    public let channelMappingTable: ChannelMappingTable?

    public init(
        version: UInt8 = 0,
        outputChannelCount: UInt8,
        preSkip: UInt16,
        inputSampleRate: UInt32,
        outputGainQ78: Int16 = 0,
        channelMappingFamily: OpusChannelMappingFamily,
        channelMappingTable: ChannelMappingTable? = nil
    ) {
        precondition(version == 0, "OpusSpecificBox version must be 0 per IETF spec")
        precondition(
            (channelMappingFamily == .rtpMonoStereo)
                == (channelMappingTable == nil),
            "OpusSpecificBox: channelMappingTable presence must match channelMappingFamily"
        )
        if let table = channelMappingTable {
            precondition(
                table.channelMapping.count == Int(outputChannelCount),
                "OpusSpecificBox: channelMapping.count must equal outputChannelCount"
            )
        }
        self.version = version
        self.outputChannelCount = outputChannelCount
        self.preSkip = preSkip
        self.inputSampleRate = inputSampleRate
        self.outputGainQ78 = outputGainQ78
        self.channelMappingFamily = channelMappingFamily
        self.channelMappingTable = channelMappingTable
    }

    /// Decoded output gain in dB.
    public var outputGainDB: Double {
        Double(outputGainQ78) / 256.0
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> OpusSpecificBox {
        let version = try reader.readUInt8()
        guard version == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "OpusSpecificBox version must be 0, got \(version)"
            )
        }
        let outputChannelCount = try reader.readUInt8()
        let preSkip = try reader.readUInt16()
        let inputSampleRate = try reader.readUInt32()
        let outputGainRaw = try reader.readUInt16()
        let outputGain = Int16(bitPattern: outputGainRaw)
        let familyRaw = try reader.readUInt8()
        guard let family = OpusChannelMappingFamily(rawValue: familyRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown Opus channelMappingFamily \(familyRaw)"
            )
        }

        var table: ChannelMappingTable?
        if family != .rtpMonoStereo {
            let streamCount = try reader.readUInt8()
            let coupledCount = try reader.readUInt8()
            var mapping: [UInt8] = []
            mapping.reserveCapacity(Int(outputChannelCount))
            for _ in 0..<outputChannelCount {
                mapping.append(try reader.readUInt8())
            }
            table = ChannelMappingTable(
                streamCount: streamCount,
                coupledCount: coupledCount,
                channelMapping: mapping
            )
        }

        return OpusSpecificBox(
            version: version,
            outputChannelCount: outputChannelCount,
            preSkip: preSkip,
            inputSampleRate: inputSampleRate,
            outputGainQ78: outputGain,
            channelMappingFamily: family,
            channelMappingTable: table
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt8(version)
            body.writeUInt8(outputChannelCount)
            body.writeUInt16(preSkip)
            body.writeUInt32(inputSampleRate)
            body.writeUInt16(UInt16(bitPattern: outputGainQ78))
            body.writeUInt8(channelMappingFamily.rawValue)
            if let table = channelMappingTable {
                body.writeUInt8(table.streamCount)
                body.writeUInt8(table.coupledCount)
                for byte in table.channelMapping {
                    body.writeUInt8(byte)
                }
            }
        }
    }
}
