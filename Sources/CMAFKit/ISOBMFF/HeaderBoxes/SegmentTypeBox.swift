// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SegmentTypeBox (styp)
//
// Reference: ISO/IEC 14496-12 §8.16.2 (segment type box).
//
// Functionally identical to `ftyp` but introduces a CMAF / DASH media
// segment. Carries the same major brand / minor version / compatible
// brands tuple as `ftyp`.

import Foundation

/// Segment type box — identifies the brand of a CMAF or DASH media segment.
///
/// Per ISO/IEC 14496-12 §8.16.2, the on-wire layout is identical to
/// ``FileTypeBox`` (`ftyp`). The distinction is positional: `styp`
/// precedes a media segment (`moof + mdat`), where `ftyp` precedes a
/// standalone file (`moov + ...`).
public struct SegmentTypeBox: ISOBox, Sendable, Equatable {
    public static let boxType: FourCC = "styp"

    public let majorBrand: FourCC
    public let minorVersion: UInt32
    public let compatibleBrands: [FourCC]

    public init(majorBrand: FourCC, minorVersion: UInt32, compatibleBrands: [FourCC]) {
        self.majorBrand = majorBrand
        self.minorVersion = minorVersion
        self.compatibleBrands = compatibleBrands
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SegmentTypeBox {
        let majorBrand = try reader.readFourCC()
        let minorVersion = try reader.readUInt32()
        var compatibleBrands: [FourCC] = []
        while reader.remaining >= 4 {
            compatibleBrands.append(try reader.readFourCC())
        }
        return SegmentTypeBox(
            majorBrand: majorBrand,
            minorVersion: minorVersion,
            compatibleBrands: compatibleBrands
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeFourCC(majorBrand)
            body.writeUInt32(minorVersion)
            for brand in compatibleBrands {
                body.writeFourCC(brand)
            }
        }
    }
}
