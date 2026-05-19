// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCHRDParameters
//
// Reference: ITU-T H.264 §E.1.2 (hrd_parameters).

import Foundation

/// AVC Hypothetical Reference Decoder parameters per ITU-T H.264 §E.1.2.
public struct AVCHRDParameters: Sendable, Hashable, Equatable, Codable {

    /// One Coded Picture Buffer (CPB) schedule entry.
    public struct CPBEntry: Sendable, Hashable, Equatable, Codable {
        public let bitRateValueMinus1: UInt32
        public let cpbSizeValueMinus1: UInt32
        public let cbrFlag: Bool

        public init(
            bitRateValueMinus1: UInt32,
            cpbSizeValueMinus1: UInt32,
            cbrFlag: Bool
        ) {
            self.bitRateValueMinus1 = bitRateValueMinus1
            self.cpbSizeValueMinus1 = cpbSizeValueMinus1
            self.cbrFlag = cbrFlag
        }
    }

    public let cpbCountMinus1: UInt32
    public let bitRateScale: UInt8
    public let cpbSizeScale: UInt8
    public let cpbEntries: [CPBEntry]
    public let initialCPBRemovalDelayLengthMinus1: UInt8
    public let cpbRemovalDelayLengthMinus1: UInt8
    public let dpbOutputDelayLengthMinus1: UInt8
    public let timeOffsetLength: UInt8

    public init(
        cpbCountMinus1: UInt32,
        bitRateScale: UInt8,
        cpbSizeScale: UInt8,
        cpbEntries: [CPBEntry],
        initialCPBRemovalDelayLengthMinus1: UInt8,
        cpbRemovalDelayLengthMinus1: UInt8,
        dpbOutputDelayLengthMinus1: UInt8,
        timeOffsetLength: UInt8
    ) {
        precondition(
            cpbEntries.count == Int(cpbCountMinus1) + 1,
            "AVCHRDParameters: cpbEntries.count must equal cpbCountMinus1 + 1"
        )
        precondition(bitRateScale <= 0x0F, "bitRateScale must fit 4 bits")
        precondition(cpbSizeScale <= 0x0F, "cpbSizeScale must fit 4 bits")
        self.cpbCountMinus1 = cpbCountMinus1
        self.bitRateScale = bitRateScale
        self.cpbSizeScale = cpbSizeScale
        self.cpbEntries = cpbEntries
        self.initialCPBRemovalDelayLengthMinus1 = initialCPBRemovalDelayLengthMinus1
        self.cpbRemovalDelayLengthMinus1 = cpbRemovalDelayLengthMinus1
        self.dpbOutputDelayLengthMinus1 = dpbOutputDelayLengthMinus1
        self.timeOffsetLength = timeOffsetLength
    }

    public static func parse(reader: inout BitReader) throws -> AVCHRDParameters {
        let cpbCountMinus1 = try reader.readUnsignedExpGolomb()
        let bitRateScale = UInt8(try reader.readBits(4))
        let cpbSizeScale = UInt8(try reader.readBits(4))
        var entries: [CPBEntry] = []
        entries.reserveCapacity(Int(cpbCountMinus1) + 1)
        for _ in 0...cpbCountMinus1 {
            let bitRateValueMinus1 = try reader.readUnsignedExpGolomb()
            let cpbSizeValueMinus1 = try reader.readUnsignedExpGolomb()
            let cbrFlag = try reader.readBool()
            entries.append(
                CPBEntry(
                    bitRateValueMinus1: bitRateValueMinus1,
                    cpbSizeValueMinus1: cpbSizeValueMinus1,
                    cbrFlag: cbrFlag
                )
            )
        }
        let initialCPB = UInt8(try reader.readBits(5))
        let cpbRemoval = UInt8(try reader.readBits(5))
        let dpbOutput = UInt8(try reader.readBits(5))
        let timeOffsetLength = UInt8(try reader.readBits(5))
        return AVCHRDParameters(
            cpbCountMinus1: cpbCountMinus1,
            bitRateScale: bitRateScale,
            cpbSizeScale: cpbSizeScale,
            cpbEntries: entries,
            initialCPBRemovalDelayLengthMinus1: initialCPB,
            cpbRemovalDelayLengthMinus1: cpbRemoval,
            dpbOutputDelayLengthMinus1: dpbOutput,
            timeOffsetLength: timeOffsetLength
        )
    }

    public func encode(to writer: inout BitWriter) {
        writer.writeUnsignedExpGolomb(cpbCountMinus1)
        writer.writeBits(UInt64(bitRateScale & 0x0F), count: 4)
        writer.writeBits(UInt64(cpbSizeScale & 0x0F), count: 4)
        for entry in cpbEntries {
            writer.writeUnsignedExpGolomb(entry.bitRateValueMinus1)
            writer.writeUnsignedExpGolomb(entry.cpbSizeValueMinus1)
            writer.writeBool(entry.cbrFlag)
        }
        writer.writeBits(UInt64(initialCPBRemovalDelayLengthMinus1 & 0x1F), count: 5)
        writer.writeBits(UInt64(cpbRemovalDelayLengthMinus1 & 0x1F), count: 5)
        writer.writeBits(UInt64(dpbOutputDelayLengthMinus1 & 0x1F), count: 5)
        writer.writeBits(UInt64(timeOffsetLength & 0x1F), count: 5)
    }
}
