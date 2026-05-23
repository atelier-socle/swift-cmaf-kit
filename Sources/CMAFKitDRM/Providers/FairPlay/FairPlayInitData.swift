// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FairPlayInitData
//
// Reference: Apple "FairPlay Streaming Programming Guide" + "Offline
// FairPlay Streaming Specification" (public Apple developer
// documentation). The pssh.data field for the FairPlay system
// identifier `94ce86fb-07ff-4f43-adb8-93d2fa968ca2` carries the
// Apple Modular DRM Streaming init-data structure:
//
//   formatVersion        UInt8         1 byte    (0x01 = version 1)
//   kidCount             UInt32 big-endian       (network byte order)
//   KIDs                 16 * kidCount bytes     (each is a UUID per
//                                                 ISO/IEC 23001-7 §8.2)
//
// Classic HLS FairPlay (`EXT-X-KEY METHOD=SAMPLE-AES URI="skd://..."`)
// does NOT carry a pssh box; this typed parser only addresses the
// CMAF Modular DRM variant where the pssh.data is well-defined.

import Foundation

/// Typed Apple FairPlay Streaming (Modular DRM) init-data payload.
public struct FairPlayInitData: Sendable, Hashable, Equatable, Codable {
    /// Format version per Apple's public documentation. Currently
    /// only version 1 is publicly defined.
    public static let currentFormatVersion: UInt8 = 1

    /// Format version byte. Version 1 is the only publicly
    /// documented value; higher values throw
    /// ``DRMSystemError/wireFormatVersionUnsupported(systemID:version:)``
    /// at parse time.
    public let formatVersion: UInt8
    /// Each key ID is the raw 16-byte UUID per ISO/IEC 23001-7 §8.2.
    public let keyIDs: [Data]

    public init(formatVersion: UInt8 = FairPlayInitData.currentFormatVersion, keyIDs: [Data]) {
        for kid in keyIDs {
            precondition(
                kid.count == 16,
                "FairPlay key_id must be exactly 16 bytes per ISO/IEC 23001-7 \u{00A7}8.2"
            )
        }
        self.formatVersion = formatVersion
        self.keyIDs = keyIDs
    }

    public static func parse(_ data: Data) throws -> FairPlayInitData {
        guard data.count >= 5 else {
            throw DRMSystemError.malformedInitData(
                systemID: .fairPlay,
                reason: "FairPlay init data is too short (\(data.count) < 5 bytes)"
            )
        }
        let bytes = [UInt8](data)
        let baseIndex = bytes.startIndex
        let version = bytes[baseIndex]
        guard version == FairPlayInitData.currentFormatVersion else {
            throw DRMSystemError.wireFormatVersionUnsupported(
                systemID: .fairPlay, version: UInt32(version)
            )
        }
        let countBytes = bytes[baseIndex + 1..<baseIndex + 5]
        let count =
            (UInt32(countBytes[baseIndex + 1]) << 24)
            | (UInt32(countBytes[baseIndex + 2]) << 16)
            | (UInt32(countBytes[baseIndex + 3]) << 8)
            | UInt32(countBytes[baseIndex + 4])
        let expected = 5 + Int(count) * 16
        guard data.count >= expected else {
            throw DRMSystemError.malformedInitData(
                systemID: .fairPlay,
                reason:
                    "FairPlay init data declares \(count) KIDs but buffer "
                    + "has \(data.count - 5) trailing bytes"
            )
        }
        if data.count > expected {
            throw DRMSystemError.unexpectedTrailingBytes(
                systemID: .fairPlay,
                byteCount: data.count - expected
            )
        }
        var keyIDs: [Data] = []
        keyIDs.reserveCapacity(Int(count))
        for index in 0..<Int(count) {
            let start = baseIndex + 5 + index * 16
            let end = start + 16
            keyIDs.append(Data(bytes[start..<end]))
        }
        return FairPlayInitData(formatVersion: version, keyIDs: keyIDs)
    }

    public static func encode(_ value: FairPlayInitData) throws -> Data {
        guard value.formatVersion == FairPlayInitData.currentFormatVersion else {
            throw DRMSystemError.wireFormatVersionUnsupported(
                systemID: .fairPlay,
                version: UInt32(value.formatVersion)
            )
        }
        guard value.keyIDs.count <= UInt32.max else {
            throw DRMSystemError.malformedInitData(
                systemID: .fairPlay,
                reason: "FairPlay KID count exceeds UInt32.max on encode"
            )
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(5 + value.keyIDs.count * 16)
        bytes.append(value.formatVersion)
        let count = UInt32(value.keyIDs.count)
        bytes.append(UInt8((count >> 24) & 0xFF))
        bytes.append(UInt8((count >> 16) & 0xFF))
        bytes.append(UInt8((count >> 8) & 0xFF))
        bytes.append(UInt8(count & 0xFF))
        for kid in value.keyIDs {
            guard kid.count == 16 else {
                throw DRMSystemError.malformedInitData(
                    systemID: .fairPlay,
                    reason: "FairPlay key_id must be 16 bytes on encode"
                )
            }
            bytes.append(contentsOf: kid)
        }
        return Data(bytes)
    }
}

extension FairPlayInitData: DRMInitDataParsing {
    public static var systemID: KnownDRMSystemID { .fairPlay }
    public typealias TypedInitData = FairPlayInitData
}
