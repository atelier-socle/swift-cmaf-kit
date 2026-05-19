// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackEncryptionBox (tenc)
//
// Reference: ISO/IEC 23001-7 §8.2 (TrackEncryptionBox).
//
// Full box version 0 or 1 carrying per-track default crypto parameters.
// On version 1, the second byte of the body packs two 4-bit pattern
// values (`default_crypt_byte_block`, `default_skip_byte_block`); on
// version 0 those nibbles do not exist (the byte is reserved zero).
// Version 1 is required when the scheme is `cens` or `cbcs`.

import Foundation

/// Track encryption box (`tenc`) per ISO/IEC 23001-7 §8.2.
public struct TrackEncryptionBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "tenc"

    /// Allowed per-sample IV sizes per ISO/IEC 23001-7 §8.2.
    public enum PerSampleIVSize: Sendable, Hashable, Equatable, Codable {
        /// Per-sample IV is absent; a ``ConstantIV`` is signalled instead.
        case zero
        /// 8-byte per-sample IV (typical for AES-CTR schemes `cenc` / `cens`).
        case eight
        /// 16-byte per-sample IV (typical for AES-CBC scheme `cbc1`).
        case sixteen

        public init(rawValue: UInt8) throws {
            switch rawValue {
            case 0: self = .zero
            case 8: self = .eight
            case 16: self = .sixteen
            default:
                throw ISOBoxError.malformedFullBox(
                    type: TrackEncryptionBox.boxType,
                    reason: "default_Per_Sample_IV_Size must be 0, 8, or 16; got \(rawValue)"
                )
            }
        }

        public var rawValue: UInt8 {
            switch self {
            case .zero: return 0
            case .eight: return 8
            case .sixteen: return 16
            }
        }
    }

    public let version: UInt8
    public let flags: UInt32
    /// 4-bit `default_crypt_byte_block`. Always 0 when ``version`` is 0.
    public let defaultCryptByteBlock: UInt8
    /// 4-bit `default_skip_byte_block`. Always 0 when ``version`` is 0.
    public let defaultSkipByteBlock: UInt8
    /// Whether samples are protected by default.
    public let defaultIsProtected: Bool
    /// IV size used by `senc` per-sample IVs.
    public let defaultPerSampleIVSize: PerSampleIVSize
    /// Default key identifier (16 bytes).
    public let defaultKID: KeyIdentifier
    /// Present iff ``defaultIsProtected`` is true and
    /// ``defaultPerSampleIVSize`` is ``PerSampleIVSize/zero``.
    public let defaultConstantIV: ConstantIV?

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        defaultCryptByteBlock: UInt8 = 0,
        defaultSkipByteBlock: UInt8 = 0,
        defaultIsProtected: Bool,
        defaultPerSampleIVSize: PerSampleIVSize,
        defaultKID: KeyIdentifier,
        defaultConstantIV: ConstantIV? = nil
    ) {
        precondition(version <= 1, "TrackEncryptionBox version must be 0 or 1")
        precondition(defaultCryptByteBlock <= 0x0F, "crypt block must fit 4 bits")
        precondition(defaultSkipByteBlock <= 0x0F, "skip block must fit 4 bits")
        precondition(
            version == 1 || (defaultCryptByteBlock == 0 && defaultSkipByteBlock == 0),
            "Pattern block fields require version 1"
        )
        let needsConstantIV = defaultIsProtected && defaultPerSampleIVSize == .zero
        precondition(
            needsConstantIV == (defaultConstantIV != nil),
            "defaultConstantIV presence must match (isProtected && PerSampleIVSize == .zero)"
        )
        self.version = version
        self.flags = flags
        self.defaultCryptByteBlock = defaultCryptByteBlock
        self.defaultSkipByteBlock = defaultSkipByteBlock
        self.defaultIsProtected = defaultIsProtected
        self.defaultPerSampleIVSize = defaultPerSampleIVSize
        self.defaultKID = defaultKID
        self.defaultConstantIV = defaultConstantIV
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TrackEncryptionBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        guard version <= 1 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "tenc version must be 0 or 1; got \(version)"
            )
        }
        let firstByte = try reader.readUInt8()
        guard firstByte == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "tenc first reserved byte must be 0"
            )
        }
        var cryptBlock: UInt8 = 0
        var skipBlock: UInt8 = 0
        let secondByte = try reader.readUInt8()
        if version == 0 {
            guard secondByte == 0 else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "tenc v0 second reserved byte must be 0"
                )
            }
        } else {
            cryptBlock = (secondByte >> 4) & 0x0F
            skipBlock = secondByte & 0x0F
        }
        let isProtected = try reader.readUInt8() != 0
        let ivSize = try PerSampleIVSize(rawValue: try reader.readUInt8())
        let kidBytes = try reader.readData(count: 16)
        let kid = KeyIdentifier(rawBytes: kidBytes)
        var constantIV: ConstantIV?
        if isProtected, ivSize == .zero {
            let constantIVSize = Int(try reader.readUInt8())
            let bytes = try reader.readData(count: constantIVSize)
            constantIV = try ConstantIV(rawBytes: bytes)
        }
        return TrackEncryptionBox(
            version: version,
            flags: flags,
            defaultCryptByteBlock: cryptBlock,
            defaultSkipByteBlock: skipBlock,
            defaultIsProtected: isProtected,
            defaultPerSampleIVSize: ivSize,
            defaultKID: kid,
            defaultConstantIV: constantIV
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt8(0)  // first reserved byte
            if version == 0 {
                body.writeUInt8(0)
            } else {
                let packed =
                    ((defaultCryptByteBlock & 0x0F) << 4)
                    | (defaultSkipByteBlock & 0x0F)
                body.writeUInt8(packed)
            }
            body.writeUInt8(defaultIsProtected ? 1 : 0)
            body.writeUInt8(defaultPerSampleIVSize.rawValue)
            body.writeData(defaultKID.rawBytes)
            if let constantIV = defaultConstantIV {
                body.writeUInt8(UInt8(constantIV.rawBytes.count))
                body.writeData(constantIV.rawBytes)
            }
        }
    }
}
