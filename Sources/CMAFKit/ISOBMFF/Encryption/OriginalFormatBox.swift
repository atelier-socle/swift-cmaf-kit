// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - OriginalFormatBox (frma)
//
// Reference: ISO/IEC 14496-12 §8.12.2 + ISO/IEC 23001-7 §4.2.
//
// Records the sample-entry FourCC that would apply if the protection
// were removed. The decoder uses this to re-establish codec semantics
// after decryption (e.g., to know the original was `avc1` even though
// the on-wire sample entry FourCC is `encv`).

import Foundation

/// Original format box (`frma`) per ISO/IEC 14496-12 §8.12.2.
public struct OriginalFormatBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "frma"

    /// The unprotected sample-entry FourCC.
    public let dataFormat: FourCC

    public init(dataFormat: FourCC) {
        self.dataFormat = dataFormat
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> OriginalFormatBox {
        let dataFormat = try reader.readFourCC()
        return OriginalFormatBox(dataFormat: dataFormat)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeFourCC(dataFormat)
        }
    }
}
