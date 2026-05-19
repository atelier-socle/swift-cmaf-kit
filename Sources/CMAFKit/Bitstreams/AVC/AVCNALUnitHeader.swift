// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCNALUnitHeader
//
// Reference: ITU-T H.264 §7.3.1 / §7.4.1.
//
// One-byte NAL unit header carried at the start of every AVC NAL unit.
// Bit layout (MSB-first):
//   bit 7   : forbidden_zero_bit (must be 0 in conforming bitstreams)
//   bits 6-5: nal_ref_idc (2 bits)
//   bits 4-0: nal_unit_type (5 bits)

import Foundation

/// AVC NAL unit header per ITU-T H.264 §7.3.1.
public struct AVCNALUnitHeader: Sendable, Hashable, Equatable, Codable {
    /// Forbidden-zero bit. The standard requires this to be `false` in
    /// every conforming bitstream; non-zero values are preserved to
    /// allow round-tripping of malformed-but-recoverable streams.
    public let forbiddenZeroBit: Bool
    /// 2-bit reference indicator. `0` marks a Non-Reference Unit (NRU);
    /// non-zero values mark units used as reference by other coded
    /// pictures.
    public let nalRefIdc: UInt8
    /// 5-bit NAL unit type code.
    public let nalUnitType: AVCNALUnitType

    public init(
        forbiddenZeroBit: Bool = false,
        nalRefIdc: UInt8,
        nalUnitType: AVCNALUnitType
    ) {
        precondition(nalRefIdc <= 0x03, "AVCNALUnitHeader.nalRefIdc must fit 2 bits")
        self.forbiddenZeroBit = forbiddenZeroBit
        self.nalRefIdc = nalRefIdc
        self.nalUnitType = nalUnitType
    }

    /// True iff this NAL unit is used as a reference by other coded
    /// pictures.
    ///
    /// Per ITU-T H.264 §7.4.1: `nal_ref_idc == 0` marks a Non-Reference
    /// Unit (NRU). Transport-aware ABR strategies may drop NRUs to
    /// reduce bandwidth without breaking decode of subsequent frames.
    public var isReference: Bool { nalRefIdc != 0 }

    /// Parse a single header byte into a typed header. Throws on
    /// unknown NAL unit type codes.
    public static func parse(byte: UInt8) throws -> AVCNALUnitHeader {
        let forbidden = (byte & 0x80) != 0
        let refIdc = (byte >> 5) & 0x03
        let typeRaw = byte & 0x1F
        guard let nalUnitType = AVCNALUnitType(rawValue: typeRaw) else {
            throw BitstreamError.unknownNALUnitType(codec: "AVC", rawValue: typeRaw)
        }
        return AVCNALUnitHeader(
            forbiddenZeroBit: forbidden,
            nalRefIdc: refIdc,
            nalUnitType: nalUnitType
        )
    }

    /// Emit the header back to its one-byte on-wire form.
    public func encode() -> UInt8 {
        var byte: UInt8 = 0
        if forbiddenZeroBit { byte |= 0x80 }
        byte |= (nalRefIdc & 0x03) << 5
        byte |= nalUnitType.rawValue & 0x1F
        return byte
    }
}
