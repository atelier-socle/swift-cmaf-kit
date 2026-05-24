// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MediaHeaderBox (mdhd)
//
// Reference: ISO/IEC 14496-12 §8.4.2 (media header box).
//
// Per-track media metadata: creation/modification times, timescale,
// duration, ISO 639-2/T language code. Versions 0 and 1 differ in
// timestamp / duration width as in `mvhd` / `tkhd`.

import Foundation

/// Per-track media header.
///
/// The ISO 639-2/T language code is stored as a 16-bit packed value:
/// three 5-bit characters offset by `0x60`, upper bit reserved.
public struct MediaHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "mdhd"

    public let version: UInt8
    public let flags: UInt32
    public let creationTime: UInt64
    public let modificationTime: UInt64
    public let timescale: UInt32
    public let duration: UInt64
    /// ISO 639-2/T 3-letter language code (for example `"eng"`, `"fra"`, `"und"`).
    public let language: String

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        creationTime: UInt64,
        modificationTime: UInt64,
        timescale: UInt32,
        duration: UInt64,
        language: String
    ) {
        self.version = version
        self.flags = flags
        self.creationTime = creationTime
        self.modificationTime = modificationTime
        self.timescale = timescale
        self.duration = duration
        self.language = language
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MediaHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let creationTime: UInt64
        let modificationTime: UInt64
        let timescale: UInt32
        let duration: UInt64

        if version == 1 {
            creationTime = try reader.readUInt64()
            modificationTime = try reader.readUInt64()
            timescale = try reader.readUInt32()
            duration = try reader.readUInt64()
        } else if version == 0 {
            creationTime = UInt64(try reader.readUInt32())
            modificationTime = UInt64(try reader.readUInt32())
            timescale = try reader.readUInt32()
            duration = UInt64(try reader.readUInt32())
        } else {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }

        let language = try reader.readLanguageCode()
        try reader.skip(2)  // pre_defined

        return MediaHeaderBox(
            version: version,
            flags: flags,
            creationTime: creationTime,
            modificationTime: modificationTime,
            timescale: timescale,
            duration: duration,
            language: language
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            if version == 1 {
                body.writeUInt64(creationTime)
                body.writeUInt64(modificationTime)
                body.writeUInt32(timescale)
                body.writeUInt64(duration)
            } else {
                body.writeUInt32(UInt32(min(creationTime, UInt64(UInt32.max))))
                body.writeUInt32(UInt32(min(modificationTime, UInt64(UInt32.max))))
                body.writeUInt32(timescale)
                body.writeUInt32(UInt32(min(duration, UInt64(UInt32.max))))
            }
            body.writeLanguageCode(language)
            body.writeZeros(2)
        }
    }
}

extension MediaHeaderBox {

    /// Decode the 3-byte ISO 639-2/T language packed into the `mdhd`
    /// box as a typed BCP 47 tag.
    ///
    /// The `mdhd` box stores language as 3 × 5-bit packed ISO 639-2/T
    /// per ISO/IEC 14496-12 §8.4.2.3. The existing ``language`` field
    /// decodes the 3-char string; this method bridges it to a typed
    /// ``BCP47LanguageTag`` via ``BCP47LanguageTag/fromISO6392T(_:)``,
    /// including the /B → /T disambiguation if the encoder wrote a
    /// Bibliographic variant.
    ///
    /// - Throws: ``BCP47Error/unknownISO6392Code(_:)`` if the stored
    ///   language string is not a syntactically valid 3-char ISO 639-2
    ///   code (e.g., padded bytes from a malformed encoder).
    ///
    /// References:
    /// - ISO/IEC 14496-12 §8.4.2.3 — Media Header Box `mdhd` language
    /// - IETF RFC 5646 — Tags for Identifying Languages
    public func languageAsBCP47() throws -> BCP47LanguageTag {
        try BCP47LanguageTag.fromISO6392T(language)
    }
}
