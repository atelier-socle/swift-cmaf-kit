// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MPEGHProfileLevelCompatibilitySetBox (mhaP)
//
// Reference: ISO/IEC 23008-3 §20.5.

import Foundation

/// MPEG-H 3D Audio profile-level compatibility set (`mhaP`).
public struct MPEGHProfileLevelCompatibilitySetBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "mhaP"

    /// Profile-level indications the bitstream is also compatible with.
    public let compatibleProfileLevels: [MPEGHProfileLevelIndication]

    public init(compatibleProfileLevels: [MPEGHProfileLevelIndication]) {
        precondition(
            compatibleProfileLevels.count <= Int(UInt8.max),
            "MPEGHProfileLevelCompatibilitySetBox: list must fit in UInt8"
        )
        self.compatibleProfileLevels = compatibleProfileLevels
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MPEGHProfileLevelCompatibilitySetBox {
        let count = Int(try reader.readUInt8())
        var profileLevels: [MPEGHProfileLevelIndication] = []
        profileLevels.reserveCapacity(count)
        for _ in 0..<count {
            let raw = try reader.readUInt8()
            guard let pli = MPEGHProfileLevelIndication(rawValue: raw) else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "Unknown MPEG-H compatibleSetIndication 0x\(String(raw, radix: 16))"
                )
            }
            profileLevels.append(pli)
        }
        return MPEGHProfileLevelCompatibilitySetBox(compatibleProfileLevels: profileLevels)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt8(UInt8(compatibleProfileLevels.count))
            for pli in compatibleProfileLevels {
                body.writeUInt8(pli.rawValue)
            }
        }
    }
}
