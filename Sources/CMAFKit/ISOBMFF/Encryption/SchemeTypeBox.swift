// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SchemeTypeBox (schm)
//
// Reference: ISO/IEC 14496-12 §8.12.5.
//
// Full box version 0 declaring the protection scheme in use plus a
// 32-bit version. An optional scheme URI may be present when flags
// bit 0 is set.
//
// The scheme is carried on the wire as a FourCC; CMAFKit projects it
// through the typed ``CommonEncryptionScheme`` enum so consumers can
// pattern-match on the four standardised CENC schemes. Unknown scheme
// FourCCs throw at parse time per the project-wide complete-coverage
// policy.

import Foundation

/// Scheme type box (`schm`) per ISO/IEC 14496-12 §8.12.5.
public struct SchemeTypeBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "schm"

    /// Major + minor projection of the 32-bit `scheme_version` field
    /// per ISO/IEC 23001-7 §4.4.
    public struct SchemeVersion: Sendable, Hashable, Equatable, Codable {
        public let major: UInt16
        public let minor: UInt16

        public init(major: UInt16, minor: UInt16) {
            self.major = major
            self.minor = minor
        }

        public init(rawValue: UInt32) {
            self.major = UInt16((rawValue >> 16) & 0xFFFF)
            self.minor = UInt16(rawValue & 0xFFFF)
        }

        public var rawValue: UInt32 {
            (UInt32(major) << 16) | UInt32(minor)
        }
    }

    /// Flag bit signalling presence of the optional `scheme_uri`.
    public static let flagURIPresent: UInt32 = 0x0000_0001

    public let version: UInt8
    public let flags: UInt32
    /// Typed scheme identifier. Unknown FourCCs are rejected at parse.
    public let schemeType: CommonEncryptionScheme
    public let schemeVersion: SchemeVersion
    /// Optional URI pointing at the scheme-specification document.
    public let schemeURI: String?

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        schemeType: CommonEncryptionScheme,
        schemeVersion: SchemeVersion = SchemeVersion(major: 1, minor: 0),
        schemeURI: String? = nil
    ) {
        self.version = version
        // Bit 0 of flags must mirror the URI presence.
        var resolvedFlags = flags
        if schemeURI != nil {
            resolvedFlags |= Self.flagURIPresent
        } else {
            resolvedFlags &= ~Self.flagURIPresent
        }
        self.flags = resolvedFlags
        self.schemeType = schemeType
        self.schemeVersion = schemeVersion
        self.schemeURI = schemeURI
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SchemeTypeBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let schemeFourCC = try reader.readFourCC()
        guard let scheme = CommonEncryptionScheme(rawValue: schemeFourCC.rawValue) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown scheme_type \(schemeFourCC)"
            )
        }
        let versionRaw = try reader.readUInt32()
        var schemeURI: String?
        if flags & Self.flagURIPresent != 0 {
            schemeURI = try reader.readNullTerminatedString()
        }
        return SchemeTypeBox(
            version: version,
            flags: flags,
            schemeType: scheme,
            schemeVersion: SchemeVersion(rawValue: versionRaw),
            schemeURI: schemeURI
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeFourCC(schemeType.fourCC)
            body.writeUInt32(schemeVersion.rawValue)
            if let uri = schemeURI {
                body.writeNullTerminatedString(uri)
            }
        }
    }
}
