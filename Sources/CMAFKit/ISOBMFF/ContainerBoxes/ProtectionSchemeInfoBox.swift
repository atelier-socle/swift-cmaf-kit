// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Protection Scheme Info container + children
//
// This file defines four related box types, grouped together because they
// form one logical unit per ISO/IEC 14496-12 §8.12 and ISO/IEC 23001-7 §8.1:
//
//   - sinf  (ProtectionSchemeInfoBox)   — container
//   - frma  (OriginalFormatBox)         — child of sinf, names the unprotected format
//   - schm  (SchemeTypeBox)             — child of sinf, names the protection scheme
//   - schi  (SchemeInformationBox)      — child of sinf, contains scheme-specific data
//
// schm IS NOT a top-level encryption box despite its semantic relationship
// to Common Encryption. It is a structural child of sinf and lives here for
// that reason.

import Foundation

// MARK: - sinf

/// Protection scheme info container.
///
/// Per ISO/IEC 14496-12 §8.12.1, this container's children describe how
/// a track is protected. The presence of this box signals that the
/// associated track is encrypted; ``OriginalFormatBox`` (`frma`) records
/// the original sample-entry FourCC so the decoder can re-establish
/// codec semantics after decryption.
public struct ProtectionSchemeInfoBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "sinf"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    /// Original format child (`frma`), if present.
    public var originalFormat: OriginalFormatBox? {
        findChild(OriginalFormatBox.self)
    }

    /// Scheme type child (`schm`), if present.
    public var schemeType: SchemeTypeBox? {
        findChild(SchemeTypeBox.self)
    }

    /// Scheme information child (`schi`), if present.
    public var schemeInformation: SchemeInformationBox? {
        findChild(SchemeInformationBox.self)
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ProtectionSchemeInfoBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return ProtectionSchemeInfoBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}

// MARK: - frma

/// Original format box — names the unprotected sample-entry FourCC.
///
/// Per ISO/IEC 14496-12 §8.12.2, this box records the sample-entry
/// FourCC that would apply if the protection were removed (for example
/// `avc1` or `hvc1`). Used by decoders to re-establish codec semantics
/// after decryption.
public struct OriginalFormatBox: ISOBox, Sendable, Equatable {
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

// MARK: - schm

/// Scheme type full box — names the protection scheme.
///
/// Per ISO/IEC 14496-12 §8.12.5, this full box declares the protection
/// scheme in use (for example `cenc`, `cbcs`) plus a 32-bit scheme
/// version. An optional URI may be present and points at a
/// scheme-specification document; its presence is signalled by flags bit 0.
///
/// The initialiser enforces consistency between ``schemeURI`` and bit 0
/// of ``flags``: passing a non-nil URI sets the bit, and passing `nil`
/// clears it. Callers therefore cannot create an inconsistent instance.
public struct SchemeTypeBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "schm"

    /// Flags bit 0: presence of the optional scheme URI.
    public static let flagURIPresent: UInt32 = 0x0000_0001

    public let version: UInt8
    public let flags: UInt32
    /// FourCC identifying the protection scheme (for example `cenc`, `cbcs`).
    public let schemeType: FourCC
    /// Version number of the protection scheme.
    public let schemeVersion: UInt32
    /// Optional URI pointing at the scheme specification document.
    public let schemeURI: String?

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        schemeType: FourCC,
        schemeVersion: UInt32,
        schemeURI: String? = nil
    ) {
        self.version = version
        // Enforce consistency: bit 0 of flags signals URI presence.
        if schemeURI != nil {
            self.flags = flags | Self.flagURIPresent
        } else {
            self.flags = flags & ~Self.flagURIPresent
        }
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
        let schemeType = try reader.readFourCC()
        let schemeVersion = try reader.readUInt32()
        var schemeURI: String?
        if flags & Self.flagURIPresent != 0 {
            schemeURI = try reader.readNullTerminatedString()
        }
        return SchemeTypeBox(
            version: version,
            flags: flags,
            schemeType: schemeType,
            schemeVersion: schemeVersion,
            schemeURI: schemeURI
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeFourCC(schemeType)
            body.writeUInt32(schemeVersion)
            if let uri = schemeURI {
                body.writeNullTerminatedString(uri)
            }
        }
    }
}

// MARK: - schi

/// Scheme information box — container for scheme-specific data.
///
/// Per ISO/IEC 14496-12 §8.12.6, the children of this box are specific
/// to the scheme declared in the sibling ``SchemeTypeBox``. For Common
/// Encryption, `schi` carries a `tenc` child describing default
/// encryption parameters; the typed `tenc` arrives in a later session
/// (until then it round-trips via ``UnknownBox``).
public struct SchemeInformationBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "schi"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SchemeInformationBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return SchemeInformationBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
