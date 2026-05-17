// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FileTypeBox (ftyp)
//
// Reference: ISO/IEC 14496-12 §4.3 (file type box).
//
// Identifies the file's major brand (intended primary format) and any
// compatible brands. Required as the first box in every standalone
// ISOBMFF file.

import Foundation

/// File type box — identifies the major brand and compatible brands.
///
/// Per ISO/IEC 14496-12 §4.3, this box is the first box of any standalone
/// ISOBMFF file. The major brand declares the primary format. Compatible
/// brands enumerate every variant the file conforms to so that readers
/// recognising any of them can process the file.
public struct FileTypeBox: ISOBox, Sendable, Equatable {
    public static let boxType: FourCC = "ftyp"

    /// The primary brand. Examples: `"isom"`, `"mp42"`, `"cmfc"`, `"cmf2"`.
    public let majorBrand: FourCC
    /// An informative version number for the major brand.
    public let minorVersion: UInt32
    /// All brands this file conforms to. The major brand may also appear
    /// here, but is not required to.
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
    ) async throws -> FileTypeBox {
        let majorBrand = try reader.readFourCC()
        let minorVersion = try reader.readUInt32()
        var compatibleBrands: [FourCC] = []
        while reader.remaining >= 4 {
            compatibleBrands.append(try reader.readFourCC())
        }
        return FileTypeBox(
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
