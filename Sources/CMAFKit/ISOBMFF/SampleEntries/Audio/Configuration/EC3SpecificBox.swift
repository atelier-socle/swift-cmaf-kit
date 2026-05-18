// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EC3SpecificBox (dec3)
//
// Reference: ETSI TS 102 366 Annex F.6.
//
// On-wire layout (after the box header):
//   UInt16 (data_rate: 13 | num_ind_sub: 3)
//   For each independent substream i in 0..num_ind_sub:
//     UInt8 (fscod[i]: 2 | bsid[i]: 5 | reserved: 1 = 0)
//     UInt8 (asvc[i]: 1 | bsmod[i]: 3 | acmod[i]: 3 | lfeon[i]: 1)
//     UInt8 (reserved: 3 = 0 | num_dep_sub[i]: 4 | chan_loc_hi: 1)
//     if num_dep_sub[i] > 0:
//       UInt8 chan_loc_lo
//   Optional trailer (AC-4 extension hint):
//     UInt8 (reserved: 7 = 0 | flag_ec3_extension_type_a: 1)
//     UInt8 ec3_extension_type_a (present iff flag == 1)

import Foundation

/// E-AC-3 specific box (`dec3`).
public struct EC3SpecificBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "dec3"

    /// One independent substream within the E-AC-3 stream.
    public struct IndependentSubstream: Sendable, Equatable, Hashable {
        public let fscod: AC3FrameSizeCode
        public let bsid: UInt8
        public let asvc: Bool
        public let bsmod: AC3BitStreamMode
        public let acmod: AC3AudioCodingMode
        public let lfeon: Bool
        public let dependentSubstreamCount: UInt8
        /// 9-bit channel-location bitmap; present iff
        /// ``dependentSubstreamCount`` is non-zero.
        public let dependentSubstreamChannelLocation: UInt16?

        public init(
            fscod: AC3FrameSizeCode,
            bsid: UInt8,
            asvc: Bool,
            bsmod: AC3BitStreamMode,
            acmod: AC3AudioCodingMode,
            lfeon: Bool,
            dependentSubstreamCount: UInt8,
            dependentSubstreamChannelLocation: UInt16? = nil
        ) {
            precondition(bsid <= 0x1F, "EC3 bsid must fit in 5 bits")
            precondition(
                dependentSubstreamCount <= 0x0F,
                "EC3 dependentSubstreamCount must fit in 4 bits"
            )
            precondition(
                (dependentSubstreamCount > 0)
                    == (dependentSubstreamChannelLocation != nil),
                "EC3 dependentSubstreamChannelLocation presence must match count"
            )
            if let loc = dependentSubstreamChannelLocation {
                precondition(loc <= 0x01FF, "EC3 chan_loc must fit in 9 bits")
            }
            self.fscod = fscod
            self.bsid = bsid
            self.asvc = asvc
            self.bsmod = bsmod
            self.acmod = acmod
            self.lfeon = lfeon
            self.dependentSubstreamCount = dependentSubstreamCount
            self.dependentSubstreamChannelLocation = dependentSubstreamChannelLocation
        }
    }

    /// 13-bit data rate in kbps.
    public let dataRate: UInt16
    public let independentSubstreams: [IndependentSubstream]
    /// AC-4 extension type A signalled in the trailer, when present.
    public let ec3ExtensionTypeA: UInt8?

    public init(
        dataRate: UInt16,
        independentSubstreams: [IndependentSubstream],
        ec3ExtensionTypeA: UInt8? = nil
    ) {
        precondition(dataRate <= 0x1FFF, "EC3 dataRate must fit in 13 bits")
        precondition(
            (1...8).contains(independentSubstreams.count),
            "EC3 must declare 1..8 independent substreams"
        )
        self.dataRate = dataRate
        self.independentSubstreams = independentSubstreams
        self.ec3ExtensionTypeA = ec3ExtensionTypeA
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> EC3SpecificBox {
        let bodyByteCount = Int(header.size) - header.headerSize
        let bodyBytes = try reader.readData(count: bodyByteCount)
        var body = BinaryReader(bodyBytes)

        let word = try body.readUInt16()
        let dataRate = (word >> 3) & 0x1FFF
        let numIndSubMinusOne = UInt8(word & 0x07)
        let numIndSub = Int(numIndSubMinusOne) + 1

        var substreams: [IndependentSubstream] = []
        substreams.reserveCapacity(numIndSub)
        for _ in 0..<numIndSub {
            let b0 = try body.readUInt8()
            let fscodRaw = (b0 >> 6) & 0x03
            guard let fscod = AC3FrameSizeCode(rawValue: fscodRaw) else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "Unknown EC3 fscod \(fscodRaw)"
                )
            }
            let bsid = (b0 >> 1) & 0x1F
            // bit 0 reserved

            let b1 = try body.readUInt8()
            let asvc = ((b1 >> 7) & 0x01) == 1
            let bsmodRaw = (b1 >> 4) & 0x07
            guard let bsmod = AC3BitStreamMode(rawValue: bsmodRaw) else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "Unknown EC3 bsmod \(bsmodRaw)"
                )
            }
            let acmodRaw = (b1 >> 1) & 0x07
            guard let acmod = AC3AudioCodingMode(rawValue: acmodRaw) else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "Unknown EC3 acmod \(acmodRaw)"
                )
            }
            let lfeon = (b1 & 0x01) == 1

            let b2 = try body.readUInt8()
            // bits 7..5 reserved
            let numDepSub = (b2 >> 1) & 0x0F
            let chanLocHi = b2 & 0x01

            var chanLoc: UInt16?
            if numDepSub > 0 {
                let b3 = try body.readUInt8()
                chanLoc = (UInt16(chanLocHi) << 8) | UInt16(b3)
            }

            substreams.append(
                IndependentSubstream(
                    fscod: fscod,
                    bsid: bsid,
                    asvc: asvc,
                    bsmod: bsmod,
                    acmod: acmod,
                    lfeon: lfeon,
                    dependentSubstreamCount: numDepSub,
                    dependentSubstreamChannelLocation: chanLoc
                )
            )
        }

        var ec3ExtensionTypeA: UInt8?
        if body.remaining >= 1 {
            let trailer = try body.readUInt8()
            if (trailer & 0x01) == 1, body.remaining >= 1 {
                ec3ExtensionTypeA = try body.readUInt8()
            }
        }

        return EC3SpecificBox(
            dataRate: dataRate,
            independentSubstreams: substreams,
            ec3ExtensionTypeA: ec3ExtensionTypeA
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            let numIndSubMinusOne = UInt16(independentSubstreams.count - 1) & 0x07
            let word = ((dataRate & 0x1FFF) << 3) | numIndSubMinusOne
            body.writeUInt16(word)

            for substream in independentSubstreams {
                let b0: UInt8 =
                    ((substream.fscod.rawValue & 0x03) << 6)
                    | ((substream.bsid & 0x1F) << 1)
                body.writeUInt8(b0)

                let b1: UInt8 =
                    ((substream.asvc ? UInt8(1) : 0) << 7)
                    | ((substream.bsmod.rawValue & 0x07) << 4)
                    | ((substream.acmod.rawValue & 0x07) << 1)
                    | (substream.lfeon ? UInt8(1) : 0)
                body.writeUInt8(b1)

                let chanLocHi: UInt8
                if let loc = substream.dependentSubstreamChannelLocation {
                    chanLocHi = UInt8((loc >> 8) & 0x01)
                } else {
                    chanLocHi = 0
                }
                let b2: UInt8 =
                    ((substream.dependentSubstreamCount & 0x0F) << 1)
                    | chanLocHi
                body.writeUInt8(b2)

                if let loc = substream.dependentSubstreamChannelLocation {
                    body.writeUInt8(UInt8(loc & 0xFF))
                }
            }

            if let ext = ec3ExtensionTypeA {
                body.writeUInt8(0x01)  // flag_ec3_extension_type_a = 1
                body.writeUInt8(ext)
            }
        }
    }
}
