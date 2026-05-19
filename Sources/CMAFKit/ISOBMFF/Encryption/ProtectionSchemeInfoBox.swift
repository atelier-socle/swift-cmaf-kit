// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProtectionSchemeInfoBox (sinf)
//
// Reference: ISO/IEC 14496-12 §8.12.1 + ISO/IEC 23001-7 §4.1.
//
// Container box whose children describe how the parent track is
// protected. The original (unprotected) FourCC is carried by `frma`;
// the scheme identity is carried by `schm`; scheme-specific data
// (notably the `tenc` defaults) lives inside `schi`.
//
// When the contained `schm` identifies a Common Encryption scheme,
// CMAFKit enforces a set of cross-field rules at parse time per
// ISO/IEC 23001-7 §8.2 / §10.x:
//
//   - Pattern schemes (`cens`, `cbcs`) require `tenc.version == 1` and
//     at least one of (crypt_byte_block, skip_byte_block) non-zero.
//   - Full-sample schemes (`cenc`, `cbc1`) require both block fields
//     to be zero.
//   - `cbcs` with an explicit constant IV must use a 16-byte IV.

import Foundation

/// Protection scheme info container (`sinf`).
public struct ProtectionSchemeInfoBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "sinf"

    /// Mandatory original-format child.
    public let originalFormat: OriginalFormatBox
    /// Scheme identifier. Optional per ISO/IEC 14496-12 §8.12.1, but
    /// mandatory for CENC streams.
    public let schemeType: SchemeTypeBox?
    /// Scheme-specific information. Optional per the base ISO BMFF
    /// definition.
    public let schemeInformation: SchemeInformationBox?

    public init(
        originalFormat: OriginalFormatBox,
        schemeType: SchemeTypeBox? = nil,
        schemeInformation: SchemeInformationBox? = nil
    ) {
        self.originalFormat = originalFormat
        self.schemeType = schemeType
        self.schemeInformation = schemeInformation
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ProtectionSchemeInfoBox {
        let bodySize = Int(header.size) - header.headerSize
        let bodyData = try reader.readData(count: bodySize)
        var bodyReader = BinaryReader(bodyData)
        var originalFormat: OriginalFormatBox?
        var schemeType: SchemeTypeBox?
        var schemeInformation: SchemeInformationBox?
        let isoBoxReader = ISOBoxReader()
        while bodyReader.remaining >= 8 {
            var peek = bodyReader
            let childHeader = try isoBoxReader.parseBoxHeader(&peek)
            switch childHeader.type {
            case OriginalFormatBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&bodyReader)
                originalFormat = try await OriginalFormatBox.parse(
                    reader: &bodyReader, header: childHeader, registry: registry
                )
            case SchemeTypeBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&bodyReader)
                schemeType = try await SchemeTypeBox.parse(
                    reader: &bodyReader, header: childHeader, registry: registry
                )
            case SchemeInformationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&bodyReader)
                schemeInformation = try await SchemeInformationBox.parse(
                    reader: &bodyReader, header: childHeader, registry: registry
                )
            default:
                _ = try ISOBoxOpaque.parse(reader: &bodyReader)
            }
        }
        guard let resolvedOriginalFormat = originalFormat else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "sinf is missing a frma child"
            )
        }
        let box = ProtectionSchemeInfoBox(
            originalFormat: resolvedOriginalFormat,
            schemeType: schemeType,
            schemeInformation: schemeInformation
        )
        try box.validateCommonEncryptionConsistency()
        return box
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            originalFormat.encode(to: &body)
            schemeType?.encode(to: &body)
            schemeInformation?.encode(to: &body)
        }
    }

    /// Enforce the CENC cross-field rules between `schm` and `tenc`.
    /// Throws ``ISOBoxError/malformedFullBox(type:reason:)`` when any
    /// rule is violated.
    public func validateCommonEncryptionConsistency() throws {
        guard let schemeType = schemeType else {
            return  // non-CENC sinf, no rules to enforce
        }
        guard let tenc = schemeInformation?.trackEncryption else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "CENC scheme \(schemeType.schemeType.fourCC) requires a tenc child"
            )
        }
        switch schemeType.schemeType {
        case .cenc, .cbc1:
            if tenc.defaultCryptByteBlock != 0 || tenc.defaultSkipByteBlock != 0 {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason:
                        "Full-sample scheme \(schemeType.schemeType.fourCC) "
                        + "requires crypt_byte_block and skip_byte_block to be zero"
                )
            }
        case .cens, .cbcs:
            guard tenc.version == 1 else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason:
                        "Pattern scheme \(schemeType.schemeType.fourCC) requires tenc version 1"
                )
            }
            if tenc.defaultCryptByteBlock == 0 && tenc.defaultSkipByteBlock == 0 {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason:
                        "Pattern scheme \(schemeType.schemeType.fourCC) requires "
                        + "at least one of crypt_byte_block or skip_byte_block non-zero"
                )
            }
        }
        if schemeType.schemeType == .cbcs, let iv = tenc.defaultConstantIV {
            guard iv.rawBytes.count == 16 else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "cbcs constant IV must be 16 bytes; got \(iv.rawBytes.count)"
                )
            }
        }
    }
}
