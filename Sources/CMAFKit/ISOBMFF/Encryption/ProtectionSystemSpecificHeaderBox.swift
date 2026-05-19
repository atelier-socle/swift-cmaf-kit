// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProtectionSystemSpecificHeaderBox (pssh)
//
// Reference: ISO/IEC 23001-7 §8.1 (ProtectionSystemSpecificHeaderBox).
//
// Full box version 0 or 1. Carries the 16-byte DRM SystemID, an
// optional list of key identifiers (version 1 only), and a DRM-system-
// specific payload. Per ISO/IEC 23001-7 §8.1.1, the payload is
// explicitly defined as opaque to the ISO standard — its internal
// format is owned by each DRM provider (Widevine, PlayReady, FairPlay,
// W3C ClearKey, Marlin, etc.). Typing per provider is delivered by a
// future optional target.

import Foundation

/// Protection System Specific Header box (`pssh`).
public struct ProtectionSystemSpecificHeaderBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "pssh"

    public let version: UInt8
    public let flags: UInt32
    /// 16-byte DRM system identifier (UUID).
    public let systemID: UUID
    /// Present iff `version == 1`. Per ISO/IEC 23001-7 §8.1.1 the
    /// standard recommends but does not require uniqueness; CMAFKit
    /// preserves duplicates verbatim.
    public let keyIdentifiers: [KeyIdentifier]?
    /// DRM-system-specific payload. Defined as opaque by the ISO
    /// standard itself (§8.1.1); typing per provider is out of scope
    /// for the base library.
    public let data: Data

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        systemID: UUID,
        keyIdentifiers: [KeyIdentifier]? = nil,
        data: Data
    ) {
        precondition(version <= 1, "pssh version must be 0 or 1")
        precondition(
            (version == 1) == (keyIdentifiers != nil),
            "keyIdentifiers presence must match version 1"
        )
        self.version = version
        self.flags = flags
        self.systemID = systemID
        self.keyIdentifiers = keyIdentifiers
        self.data = data
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ProtectionSystemSpecificHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        guard version <= 1 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "pssh version must be 0 or 1; got \(version)"
            )
        }
        let systemIDBytes = try reader.readData(count: 16)
        let systemID = uuid(from: systemIDBytes)
        var keyIdentifiers: [KeyIdentifier]?
        if version == 1 {
            let kidCount = try reader.readUInt32()
            var ids: [KeyIdentifier] = []
            ids.reserveCapacity(Int(kidCount))
            for _ in 0..<kidCount {
                let bytes = try reader.readData(count: 16)
                ids.append(KeyIdentifier(rawBytes: bytes))
            }
            keyIdentifiers = ids
        }
        let dataSize = try reader.readUInt32()
        let payload = try reader.readData(count: Int(dataSize))
        return ProtectionSystemSpecificHeaderBox(
            version: version,
            flags: flags,
            systemID: systemID,
            keyIdentifiers: keyIdentifiers,
            data: payload
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeData(Self.systemIDBytes(systemID))
            if let keyIDs = keyIdentifiers {
                body.writeUInt32(UInt32(keyIDs.count))
                for kid in keyIDs {
                    body.writeData(kid.rawBytes)
                }
            }
            body.writeUInt32(UInt32(data.count))
            body.writeData(data)
        }
    }

    private static func systemIDBytes(_ uuid: UUID) -> Data {
        let u = uuid.uuid
        return Data([
            u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
            u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15
        ])
    }
}

private func uuid(from data: Data) -> UUID {
    let b = [UInt8](data)
    return UUID(
        uuid: (
            b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
            b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
        )
    )
}
