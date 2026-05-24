// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ALACSpecificBox
//
// Reference: Apple ALAC public specification (open-sourced 2011 —
// `ALACMagicCookieDescription.txt` archived at macosforge.github.io/
// alac/). ISO/IEC 14496-12 §4.2 — Box structure.
//
// 36-byte body following the box header carrying the ALAC
// "magic cookie": codec parameters required to instantiate an ALAC
// decoder. fourCC `alac` collides with the parent `ALACSampleEntry`;
// the collision is resolved by NOT registering `ALACSpecificBox` at
// the global `BoxRegistry` level — `ALACSampleEntry.parse` reads the
// inner `alac` config box manually, mirroring the FLACSampleEntry /
// dfLa pattern (where the child has its own fourCC) but adapted for
// the same-fourCC ALAC case.

import Foundation

/// Apple Lossless Audio Codec specific configuration box (`alac` —
/// child box of ``ALACSampleEntry``).
///
/// Carries the ALAC "magic cookie" — `ALACSpecificConfig`, a 24-byte
/// structure describing the codec parameters required to instantiate
/// an ALAC decoder. Despite sharing the `alac` fourCC with the parent
/// sample entry, this is a distinct ISOBox dispatched by parser
/// context (the parser is only invoked from inside
/// `ALACSampleEntry.parse`).
///
/// On-wire layout of the box body (28 bytes total: 4-byte FullBox
/// version/flags leader + 24-byte ALACSpecificConfig, all multi-byte
/// fields big-endian):
/// - `frameLength: UInt32` — max samples per frame (typically 4096)
/// - `compatibleVersion: UInt8` — always 0
/// - `bitDepth: UInt8` — 16 / 20 / 24 / 32
/// - `pb: UInt8` — rice parameter limit (typically 40)
/// - `mb: UInt8` — rice modifier (typically 10)
/// - `kb: UInt8` — rice initial history (typically 14)
/// - `numChannels: UInt8` — 1..8
/// - `maxRun: UInt16` — maximum run-length
/// - `maxFrameBytes: UInt32` — maximum compressed frame size
/// - `avgBitRate: UInt32` — average bit rate
/// - `sampleRate: UInt32` — Hz (e.g., 44100, 48000, 96000, 192000)
///
/// References:
/// - Apple ALAC public specification (2011 open-source release)
/// - ISO/IEC 14496-12 §4.2 — Box structure
public struct ALACSpecificBox: ISOBox, Sendable, Equatable, Hashable {

    public static let boxType: FourCC = "alac"

    /// Maximum samples per frame. Apple reference encoder default is
    /// `4096`.
    public let frameLength: UInt32
    /// Always `0` per the Apple ALAC specification.
    public let compatibleVersion: UInt8
    /// Bit depth — one of `{16, 20, 24, 32}`.
    public let bitDepth: UInt8
    /// Rice parameter limit. Apple reference encoder default is `40`.
    public let pb: UInt8
    /// Rice modifier. Apple reference encoder default is `10`.
    public let mb: UInt8
    /// Rice initial history. Apple reference encoder default is `14`.
    public let kb: UInt8
    /// Channel count — `1..8`.
    public let numChannels: UInt8
    /// Maximum run-length.
    public let maxRun: UInt16
    /// Maximum compressed frame size in bytes.
    public let maxFrameBytes: UInt32
    /// Average bit rate in bits/second.
    public let avgBitRate: UInt32
    /// Sample rate in Hz.
    public let sampleRate: UInt32

    public init(
        frameLength: UInt32 = 4096,
        compatibleVersion: UInt8 = 0,
        bitDepth: UInt8,
        pb: UInt8 = 40,
        mb: UInt8 = 10,
        kb: UInt8 = 14,
        numChannels: UInt8,
        maxRun: UInt16 = 0xFF,
        maxFrameBytes: UInt32,
        avgBitRate: UInt32,
        sampleRate: UInt32
    ) {
        self.frameLength = frameLength
        self.compatibleVersion = compatibleVersion
        self.bitDepth = bitDepth
        self.pb = pb
        self.mb = mb
        self.kb = kb
        self.numChannels = numChannels
        self.maxRun = maxRun
        self.maxFrameBytes = maxFrameBytes
        self.avgBitRate = avgBitRate
        self.sampleRate = sampleRate
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ALACSpecificBox {
        // FullBox `alac` config: 4-byte version/flags leader (must be
        // zero) + 24-byte ALACSpecificConfig. Total body = 28 bytes.
        // Some encoders write the cookie raw with no leading 4 bytes
        // (body = 24); we support both forms.
        let bodyByteCount = Int(header.size) - header.headerSize
        guard bodyByteCount == 24 || bodyByteCount == 28 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason:
                    "ALAC magic cookie body must be 24 or 28 bytes (got \(bodyByteCount))"
            )
        }
        if bodyByteCount == 28 {
            // FullBox-style 4 bytes of version+flags (must be zero).
            let leader = try reader.readUInt32()
            guard leader == 0 else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "ALAC FullBox-style leader must be zero")
            }
        }

        let frameLength = try reader.readUInt32()
        let compatibleVersion = try reader.readUInt8()
        let bitDepth = try reader.readUInt8()
        let pb = try reader.readUInt8()
        let mb = try reader.readUInt8()
        let kb = try reader.readUInt8()
        let numChannels = try reader.readUInt8()
        let maxRun = try reader.readUInt16()
        let maxFrameBytes = try reader.readUInt32()
        let avgBitRate = try reader.readUInt32()
        let sampleRate = try reader.readUInt32()

        let box = ALACSpecificBox(
            frameLength: frameLength,
            compatibleVersion: compatibleVersion,
            bitDepth: bitDepth,
            pb: pb,
            mb: mb,
            kb: kb,
            numChannels: numChannels,
            maxRun: maxRun,
            maxFrameBytes: maxFrameBytes,
            avgBitRate: avgBitRate,
            sampleRate: sampleRate
        )
        try box.validate()
        return box
    }

    public func encode(to writer: inout BinaryWriter) {
        // Emit FullBox-style with zero version/flags to match Apple
        // reference encoder output and round-trip the 40-byte form.
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt32(0)  // version (1) + flags (3) — both zero
            body.writeUInt32(frameLength)
            body.writeUInt8(compatibleVersion)
            body.writeUInt8(bitDepth)
            body.writeUInt8(pb)
            body.writeUInt8(mb)
            body.writeUInt8(kb)
            body.writeUInt8(numChannels)
            body.writeUInt16(maxRun)
            body.writeUInt32(maxFrameBytes)
            body.writeUInt32(avgBitRate)
            body.writeUInt32(sampleRate)
        }
    }

    /// Validate the magic cookie per the Apple ALAC public spec:
    /// `bitDepth ∈ {16, 20, 24, 32}`, `numChannels ∈ 1..8`,
    /// `compatibleVersion == 0`, `sampleRate > 0`.
    public func validate() throws {
        switch bitDepth {
        case 16, 20, 24, 32: break
        default:
            throw ALACSpecificBoxError.invalidBitDepth(bitDepth)
        }
        guard (1...8).contains(numChannels) else {
            throw ALACSpecificBoxError.invalidChannelCount(numChannels)
        }
        guard compatibleVersion == 0 else {
            throw ALACSpecificBoxError.invalidCompatibleVersion(compatibleVersion)
        }
        guard sampleRate > 0 else {
            throw ALACSpecificBoxError.invalidSampleRate(sampleRate)
        }
    }
}

/// Typed errors for ``ALACSpecificBox`` validation.
public enum ALACSpecificBoxError: Error, Equatable {
    /// Bit depth must be one of `{16, 20, 24, 32}`.
    case invalidBitDepth(_ bitDepth: UInt8)
    /// Channel count must be in `1..8`.
    case invalidChannelCount(_ count: UInt8)
    /// Compatible version must be zero per Apple ALAC spec.
    case invalidCompatibleVersion(_ version: UInt8)
    /// Sample rate must be greater than zero.
    case invalidSampleRate(_ rate: UInt32)
}
