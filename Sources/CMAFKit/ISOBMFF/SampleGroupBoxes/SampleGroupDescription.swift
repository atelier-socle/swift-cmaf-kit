// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleGroupDescription protocol + typed conformers + raw fallback
//
// Reference: ISO/IEC 14496-12 §8.9.3 (sample group description box).
// Reference: ISO/IEC 14496-12 §10.1 (Roll Recovery group).
// Reference: ISO/IEC 23003-3 (Audio Pre-Roll group "prol").
// Reference: ISO/IEC 14496-12 §10.4 (Random Access Point group "rap ").
// Reference: ISO/IEC 23001-7 §6 (CENC Sample Encryption Information Group "seig").
//
// The sgpd box parses each entry into a SampleGroupDescription conformer.
// Typed conformers exist for the four grouping types CMAFKit natively
// supports; all other grouping types parse into the fallback
// `RawSampleGroupDescription` which preserves the entry payload byte-for-byte
// and round-trips losslessly.

import Foundation

/// A typed (or opaque) sample-group description entry.
///
/// Conforming concrete types live in this file. The set of typed conformers
/// covers the most common grouping types (`roll`, `prol`, `rap `, `seig`).
/// Any other grouping type surfaces through ``RawSampleGroupDescription``,
/// the permanent fallback that preserves the entry payload byte-for-byte.
public protocol SampleGroupDescription: Sendable, Hashable {
    /// The grouping type FourCC this description applies to. Used by `sgpd`
    /// to route parsed entries to the right conformer.
    static var groupingType: FourCC { get }

    /// Encode the entry's body (everything after the optional 4-byte
    /// per-entry length prefix that `sgpd` emits when `default_length == 0`).
    func encode(to writer: inout BinaryWriter)
}

// MARK: - RawSampleGroupDescription (permanent fallback)

/// Fallback sample-group description for any grouping type not natively
/// typed by CMAFKit.
///
/// `RawSampleGroupDescription` preserves the entry payload verbatim and is
/// the permanent public API surface for grouping types CMAFKit does not
/// interpret semantically. Typed group descriptions added in future versions
/// are additive; consumers may rely on this fallback as the long-term
/// representation for any unrecognised `grouping_type`.
public struct RawSampleGroupDescription: SampleGroupDescription, Sendable, Hashable {
    /// Sentinel. The actual grouping type lives on the containing `sgpd`
    /// box's `groupingType` field, not on this conformer.
    public static let groupingType: FourCC = FourCC(0)

    /// The verbatim entry bytes.
    public let payload: Data

    public init(payload: Data) {
        self.payload = payload
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeData(payload)
    }
}

// MARK: - roll (Roll Recovery)

/// Roll Recovery group description.
///
/// Per ISO/IEC 14496-12 §10.1, each entry is a single signed 16-bit
/// ``rollDistance`` indicating how many samples the consumer must decode
/// before the marked sample to fully recover its decoded output. A
/// negative value indicates samples before the marked sample; a positive
/// value indicates samples after.
public struct RollSampleGroupDescription: SampleGroupDescription, Sendable, Hashable {
    public static let groupingType: FourCC = "roll"

    public let rollDistance: Int16

    public init(rollDistance: Int16) {
        self.rollDistance = rollDistance
    }

    public static func parse(reader: inout BinaryReader) throws -> RollSampleGroupDescription {
        let rollDistance = try reader.readInt16()
        return RollSampleGroupDescription(rollDistance: rollDistance)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeInt16(rollDistance)
    }
}

// MARK: - prol (Audio Pre-Roll)

/// Audio Pre-Roll group description.
///
/// Per ISO/IEC 23003-3, the layout matches ``RollSampleGroupDescription``
/// (a single `Int16` ``rollDistance``) but the semantic meaning differs:
/// `prol` marks samples whose decoded output is intended to prime the
/// decoder for subsequent samples, particularly for xHE-AAC / USAC content.
public struct AudioPreRollSampleGroupDescription: SampleGroupDescription, Sendable, Hashable {
    public static let groupingType: FourCC = "prol"

    public let rollDistance: Int16

    public init(rollDistance: Int16) {
        self.rollDistance = rollDistance
    }

    public static func parse(reader: inout BinaryReader) throws -> AudioPreRollSampleGroupDescription {
        let rollDistance = try reader.readInt16()
        return AudioPreRollSampleGroupDescription(rollDistance: rollDistance)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeInt16(rollDistance)
    }
}

// MARK: - rap (Random Access Point)

/// Random Access Point group description.
///
/// Per ISO/IEC 14496-12 §10.4, each entry is a single byte packed as:
///   - bit 7: ``numLeadingSamplesKnown``
///   - bits 6..0: ``numLeadingSamples`` (0..127)
public struct RandomAccessPointSampleGroupDescription: SampleGroupDescription, Sendable, Hashable {
    public static let groupingType: FourCC = "rap "

    /// Whether the number of leading samples is known. When `false`,
    /// ``numLeadingSamples`` is unspecified and consumers should treat it
    /// as unknown.
    public let numLeadingSamplesKnown: Bool
    /// Number of leading samples (0..127). Meaningful only when
    /// ``numLeadingSamplesKnown`` is `true`.
    public let numLeadingSamples: UInt8

    public init(numLeadingSamplesKnown: Bool, numLeadingSamples: UInt8) {
        precondition(
            numLeadingSamples <= 127,
            "RandomAccessPointSampleGroupDescription: numLeadingSamples must be in 0..127"
        )
        self.numLeadingSamplesKnown = numLeadingSamplesKnown
        self.numLeadingSamples = numLeadingSamples
    }

    public static func parse(reader: inout BinaryReader) throws -> RandomAccessPointSampleGroupDescription {
        let byte = try reader.readUInt8()
        let known = (byte & 0x80) != 0
        let count = byte & 0x7F
        return RandomAccessPointSampleGroupDescription(
            numLeadingSamplesKnown: known,
            numLeadingSamples: count
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        let byte = (numLeadingSamplesKnown ? UInt8(0x80) : 0) | (numLeadingSamples & 0x7F)
        writer.writeUInt8(byte)
    }
}

// MARK: - seig (CENC Sample Encryption Information Group)

/// CENC Sample Encryption Information Group description.
///
/// Per ISO/IEC 23001-7 §6, the layout is:
///   - 1 byte: reserved (must be 0)
///   - 1 byte: high 4 bits = ``cryptByteBlock``, low 4 bits = ``skipByteBlock``
///   - 1 byte: ``isProtected``
///   - 1 byte: ``perSampleIVSize``
///   - 16 bytes: ``kid`` (key identifier UUID)
///   - if `isProtected == 1` AND `perSampleIVSize == 0`: 1 byte constant-IV
///     length + N bytes constant IV
///
/// `cryptByteBlock` / `skipByteBlock` encode pattern encryption for `cbcs`
/// (for example 1 byte encrypted, 9 bytes skipped — the CMAF-recommended
/// video pattern).
public struct CENCSampleGroupDescription: SampleGroupDescription, Sendable, Hashable {
    public static let groupingType: FourCC = "seig"

    /// Encryption pattern, encrypted block count (high nibble of byte 1).
    public let cryptByteBlock: UInt8
    /// Encryption pattern, skipped block count (low nibble of byte 1).
    public let skipByteBlock: UInt8
    /// `0` = unencrypted, `1` = encrypted.
    public let isProtected: UInt8
    /// Per-sample IV size in bytes (0, 8, or 16). When 0 and
    /// ``isProtected`` is 1, ``constantIV`` carries the constant IV used
    /// for every sample.
    public let perSampleIVSize: UInt8
    /// Key identifier.
    public let kid: UUID
    /// Constant IV used when ``perSampleIVSize`` is 0 and ``isProtected``
    /// is 1; otherwise empty.
    public let constantIV: Data

    public init(
        cryptByteBlock: UInt8,
        skipByteBlock: UInt8,
        isProtected: UInt8,
        perSampleIVSize: UInt8,
        kid: UUID,
        constantIV: Data
    ) {
        precondition(
            cryptByteBlock <= 0x0F,
            "CENCSampleGroupDescription: cryptByteBlock must fit in 4 bits"
        )
        precondition(
            skipByteBlock <= 0x0F,
            "CENCSampleGroupDescription: skipByteBlock must fit in 4 bits"
        )
        self.cryptByteBlock = cryptByteBlock
        self.skipByteBlock = skipByteBlock
        self.isProtected = isProtected
        self.perSampleIVSize = perSampleIVSize
        self.kid = kid
        self.constantIV = constantIV
    }

    public static func parse(reader: inout BinaryReader) throws -> CENCSampleGroupDescription {
        try reader.skip(1)  // reserved
        let patternByte = try reader.readUInt8()
        let cryptByteBlock = (patternByte >> 4) & 0x0F
        let skipByteBlock = patternByte & 0x0F
        let isProtected = try reader.readUInt8()
        let perSampleIVSize = try reader.readUInt8()
        let kid = try reader.readUUID()

        var constantIV = Data()
        if isProtected == 1 && perSampleIVSize == 0 {
            let constantIVSize = try reader.readUInt8()
            constantIV = try reader.readData(count: Int(constantIVSize))
        }

        return CENCSampleGroupDescription(
            cryptByteBlock: cryptByteBlock,
            skipByteBlock: skipByteBlock,
            isProtected: isProtected,
            perSampleIVSize: perSampleIVSize,
            kid: kid,
            constantIV: constantIV
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeZeros(1)
        let patternByte = ((cryptByteBlock & 0x0F) << 4) | (skipByteBlock & 0x0F)
        writer.writeUInt8(patternByte)
        writer.writeUInt8(isProtected)
        writer.writeUInt8(perSampleIVSize)
        writer.writeUUID(kid)
        if isProtected == 1 && perSampleIVSize == 0 {
            writer.writeUInt8(UInt8(constantIV.count))
            writer.writeData(constantIV)
        }
    }
}
