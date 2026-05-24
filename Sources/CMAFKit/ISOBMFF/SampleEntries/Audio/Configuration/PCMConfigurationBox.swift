// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - PCMConfigurationBox (pcmC)
//
// References:
// - ISO/IEC 23003-5 §5 — PCMConfigurationBox syntax
// - ISO/IEC 23003-5 §4 — sample entries ipcm / fpcm
// - CMAF (ISO/IEC 23000-19) §7.5.2 — Uncompressed audio profile
//
// FullBox body (6 bytes after the 4-byte version+flags FullBox header):
//   version: UInt8       — always 0 in 23003-5
//   flags:   UInt24      — reserved (0)
//   format_flags: UInt8  — bit 0: endianness (0=BE, 1=LE)
//   PCM_sample_size: UInt8 — bit depth

import Foundation

/// PCM Configuration Box (`pcmC`) per ISO/IEC 23003-5 §5.
///
/// Carries the endianness + sample size for CMAF uncompressed audio
/// sample entries (`ipcm` integer PCM, `fpcm` floating-point PCM).
///
/// References:
/// - ISO/IEC 23003-5 §5 — PCMConfigurationBox syntax
/// - ISO/IEC 23003-5 §4 — sample entries ipcm / fpcm
/// - CMAF (ISO/IEC 23000-19) §7.5.2 — Uncompressed audio profile
public struct PCMConfigurationBox: ISOFullBox, Sendable, Equatable, Hashable {

    public static let boxType: FourCC = "pcmC"

    /// Endianness of the encoded PCM samples (`format_flags` bit 0).
    public enum Endianness: UInt8, Sendable, Hashable, Codable {
        /// Big-endian samples (`format_flags` bit 0 = 0).
        case bigEndian = 0
        /// Little-endian samples (`format_flags` bit 0 = 1) — the
        /// modern CMAF default (Intel / ARM native).
        case littleEndian = 1
    }

    /// FullBox version — always 0 per ISO/IEC 23003-5 §5.
    public let version: UInt8
    /// FullBox flags — 24-bit reserved (0).
    public let flags: UInt32
    /// Sample endianness.
    public let endianness: Endianness
    /// Bit depth: `{8, 16, 24, 32}` for integer PCM; `{32, 64}` for
    /// floating-point PCM (validated at the sample-entry level via
    /// ``validate(codecKind:)``).
    public let pcmSampleSize: UInt8

    public init(
        endianness: Endianness,
        pcmSampleSize: UInt8,
        version: UInt8 = 0,
        flags: UInt32 = 0
    ) {
        self.version = version
        self.flags = flags
        self.endianness = endianness
        self.pcmSampleSize = pcmSampleSize
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> PCMConfigurationBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        guard version == 0 else {
            throw PCMConfigurationBoxError.invalidVersion(version)
        }
        guard flags == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "pcmC flags must be zero (got 0x\(String(flags, radix: 16)))"
            )
        }
        let formatFlags = try reader.readUInt8()
        let endianness: Endianness =
            (formatFlags & 0x01) == 1 ? .littleEndian : .bigEndian
        let sampleSize = try reader.readUInt8()
        return PCMConfigurationBox(
            endianness: endianness,
            pcmSampleSize: sampleSize,
            version: version,
            flags: flags
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt8(endianness.rawValue)
            body.writeUInt8(pcmSampleSize)
        }
    }

    /// Whether this configuration is valid for the given codec kind:
    /// - ``PCMSampleCodecKind/integer`` accepts `{8, 16, 24, 32}`.
    /// - ``PCMSampleCodecKind/floatingPoint`` accepts `{32, 64}`
    ///   (IEEE 754 binary32 / binary64).
    ///
    /// - Throws: ``PCMConfigurationBoxError/invalidPCMSampleSize(_:codecKind:)``
    ///   when the sample size does not match the codec kind.
    public func validate(codecKind: PCMSampleCodecKind) throws {
        switch codecKind {
        case .integer:
            switch pcmSampleSize {
            case 8, 16, 24, 32: return
            default:
                throw PCMConfigurationBoxError.invalidPCMSampleSize(
                    pcmSampleSize, codecKind: "integer")
            }
        case .floatingPoint:
            switch pcmSampleSize {
            case 32, 64: return
            default:
                throw PCMConfigurationBoxError.invalidPCMSampleSize(
                    pcmSampleSize, codecKind: "floatingPoint")
            }
        }
    }
}

/// PCM codec kind — used to drive per-codec ``PCMConfigurationBox``
/// validation rules.
public enum PCMSampleCodecKind: Sendable, Hashable, Codable {
    /// Integer PCM (`ipcm`). `pcmSampleSize` ∈ `{8, 16, 24, 32}`.
    case integer
    /// Floating-point PCM (`fpcm`). `pcmSampleSize` ∈ `{32, 64}`
    /// (IEEE 754).
    case floatingPoint
}

/// Typed errors for ``PCMConfigurationBox`` validation.
public enum PCMConfigurationBoxError: Error, Equatable {
    /// `version` field is not zero (ISO/IEC 23003-5 §5).
    case invalidVersion(_ version: UInt8)
    /// `pcmSampleSize` is not valid for the codec kind context.
    case invalidPCMSampleSize(_ size: UInt8, codecKind: String)
}
