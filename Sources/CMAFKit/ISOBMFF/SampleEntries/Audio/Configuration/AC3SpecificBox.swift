// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AC3SpecificBox (dac3)
//
// Reference: ETSI TS 102 366 Annex F.4.
//
// 3-byte bit-packed body:
//   byte 0: (fscod: 2 | bsid: 5 | bsmod_hi: 1)
//   byte 1: (bsmod_lo: 2 | acmod: 3 | lfeon: 1 | bit_rate_code_hi: 2)
//   byte 2: (bit_rate_code_lo: 3 | reserved: 5 = 0)

import Foundation

/// AC-3 specific box (`dac3`).
public struct AC3SpecificBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "dac3"

    public let fscod: AC3FrameSizeCode
    /// Bitstream identification; ETSI TS 102 366 documents values 0..16.
    public let bsid: UInt8
    public let bsmod: AC3BitStreamMode
    public let acmod: AC3AudioCodingMode
    public let lfeon: Bool
    /// Bit-rate code; 5-bit value indexing into ETSI TS 102 366
    /// §4.4.2.3 Table 4.4 (0..18 documented; values 32..37 mark
    /// upper-bound encodings).
    public let bitRateCode: UInt8

    public init(
        fscod: AC3FrameSizeCode,
        bsid: UInt8,
        bsmod: AC3BitStreamMode,
        acmod: AC3AudioCodingMode,
        lfeon: Bool,
        bitRateCode: UInt8
    ) {
        precondition(
            bsid <= 0x1F,
            "AC3SpecificBox.bsid must fit in 5 bits"
        )
        precondition(
            bitRateCode <= 0x1F,
            "AC3SpecificBox.bitRateCode must fit in 5 bits"
        )
        self.fscod = fscod
        self.bsid = bsid
        self.bsmod = bsmod
        self.acmod = acmod
        self.lfeon = lfeon
        self.bitRateCode = bitRateCode
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> AC3SpecificBox {
        let b0 = try reader.readUInt8()
        let b1 = try reader.readUInt8()
        let b2 = try reader.readUInt8()

        let fscodRaw = (b0 >> 6) & 0x03
        guard let fscod = AC3FrameSizeCode(rawValue: fscodRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown AC-3 fscod \(fscodRaw)"
            )
        }
        let bsid = (b0 >> 1) & 0x1F
        let bsmodHi = b0 & 0x01
        let bsmodLo = (b1 >> 6) & 0x03
        let bsmodRaw = (bsmodHi << 2) | bsmodLo
        guard let bsmod = AC3BitStreamMode(rawValue: bsmodRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown AC-3 bsmod \(bsmodRaw)"
            )
        }
        let acmodRaw = (b1 >> 3) & 0x07
        guard let acmod = AC3AudioCodingMode(rawValue: acmodRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown AC-3 acmod \(acmodRaw)"
            )
        }
        let lfeon = ((b1 >> 2) & 0x01) == 1
        let bitRateHi = b1 & 0x03
        let bitRateLo = (b2 >> 5) & 0x07
        let bitRateCode = (bitRateHi << 3) | bitRateLo

        return AC3SpecificBox(
            fscod: fscod,
            bsid: bsid,
            bsmod: bsmod,
            acmod: acmod,
            lfeon: lfeon,
            bitRateCode: bitRateCode
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            let bsmodHi = (bsmod.rawValue >> 2) & 0x01
            let b0: UInt8 =
                ((fscod.rawValue & 0x03) << 6)
                | ((bsid & 0x1F) << 1)
                | bsmodHi
            let bsmodLo = bsmod.rawValue & 0x03
            let bitRateHi = (bitRateCode >> 3) & 0x03
            let b1: UInt8 =
                ((bsmodLo & 0x03) << 6)
                | ((acmod.rawValue & 0x07) << 3)
                | ((lfeon ? UInt8(1) : 0) << 2)
                | bitRateHi
            let bitRateLo = bitRateCode & 0x07
            let b2: UInt8 = (bitRateLo & 0x07) << 5
            body.writeUInt8(b0)
            body.writeUInt8(b1)
            body.writeUInt8(b2)
        }
    }
}
