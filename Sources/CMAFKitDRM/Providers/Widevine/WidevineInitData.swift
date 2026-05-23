// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - WidevineInitData
//
// Reference: Google "Widevine DRM Architecture Overview" public
// documentation + DASH-IF reference content. The pssh.data field
// for the Widevine system identifier
// `edef8ba9-79d6-4ace-a3c8-27dcd51d21ed` carries a Protocol Buffer
// proto2 message named `WidevineCencHeader` with the following ten
// optional fields:
//
//   1: algorithm                 (enum: UNENCRYPTED=0, AESCTR=1)
//   2: key_id                    (repeated bytes; each is a 16-byte UUID)
//   3: provider                  (string)
//   4: content_id                (bytes)
//   5: track_type                (string; deprecated)
//   6: policy                    (string)
//   7: crypto_period_index       (uint32)
//   8: grouped_license           (bytes)
//   9: protection_scheme         (uint32; FourCC big-endian)
//  10: crypto_period_seconds     (uint32)
//
// The encoder emits fields in ascending field-number order; this
// yields byte-perfect round-trip for any value produced by the
// CMAFKitDRM decoder. Inputs from other encoders that use a
// different field order parse correctly but re-encode to canonical
// order; semantic equivalence holds in both directions.

import CMAFKit
import Foundation

/// Typed Widevine `WidevineCencHeader` payload.
public struct WidevineInitData: Sendable, Hashable, Equatable, Codable {

    /// Content encryption algorithm declared by the `algorithm`
    /// field of `WidevineCencHeader`.
    public enum Algorithm: Int32, Sendable, Hashable, CaseIterable, Codable {
        /// `UNENCRYPTED` per the public proto schema.
        case unencrypted = 0
        /// `AESCTR` per the public proto schema.
        case aesCTR = 1
    }

    public let algorithm: Algorithm?
    /// Each key ID is the raw 16-byte UUID per ISO/IEC 23001-7 §8.2.
    public let keyIDs: [Data]
    public let provider: String?
    public let contentID: Data?
    /// Deprecated per the public proto schema; kept for parse / round-
    /// trip compatibility with legacy content.
    public let trackType: String?
    public let policy: String?
    public let cryptoPeriodIndex: UInt32?
    public let groupedLicense: Data?
    /// Maps to CMAFKit's `CommonEncryptionScheme` whose raw value is
    /// the big-endian FourCC bit pattern. Unknown FourCCs are
    /// preserved as ``protectionSchemeRaw``.
    public let protectionScheme: CommonEncryptionScheme?
    /// Raw 32-bit value of the `protection_scheme` field when it does
    /// not match a registered Common Encryption scheme.
    public let protectionSchemeRaw: UInt32?
    public let cryptoPeriodSeconds: UInt32?

    public init(
        algorithm: Algorithm? = nil,
        keyIDs: [Data] = [],
        provider: String? = nil,
        contentID: Data? = nil,
        trackType: String? = nil,
        policy: String? = nil,
        cryptoPeriodIndex: UInt32? = nil,
        groupedLicense: Data? = nil,
        protectionScheme: CommonEncryptionScheme? = nil,
        protectionSchemeRaw: UInt32? = nil,
        cryptoPeriodSeconds: UInt32? = nil
    ) {
        for kid in keyIDs {
            precondition(
                kid.count == 16,
                "Widevine key_id must be exactly 16 bytes per ISO/IEC 23001-7 \u{00A7}8.2"
            )
        }
        precondition(
            !(protectionScheme != nil && protectionSchemeRaw != nil),
            "Widevine protectionScheme and protectionSchemeRaw are mutually exclusive"
        )
        self.algorithm = algorithm
        self.keyIDs = keyIDs
        self.provider = provider
        self.contentID = contentID
        self.trackType = trackType
        self.policy = policy
        self.cryptoPeriodIndex = cryptoPeriodIndex
        self.groupedLicense = groupedLicense
        self.protectionScheme = protectionScheme
        self.protectionSchemeRaw = protectionSchemeRaw
        self.cryptoPeriodSeconds = cryptoPeriodSeconds
    }

    /// Parse the opaque pssh.data Protocol Buffer payload into the
    /// typed `WidevineCencHeader` structure.
    public static func parse(_ data: Data) throws -> WidevineInitData {
        var reader = ProtocolBufferReader(data, systemID: .widevine)
        var algorithm: Algorithm?
        var keyIDs: [Data] = []
        var provider: String?
        var contentID: Data?
        var trackType: String?
        var policy: String?
        var cryptoPeriodIndex: UInt32?
        var groupedLicense: Data?
        var protectionScheme: CommonEncryptionScheme?
        var protectionSchemeRaw: UInt32?
        var cryptoPeriodSeconds: UInt32?

        while reader.hasMore {
            let (fieldNumber, wireType) = try reader.readTag()
            switch fieldNumber {
            case 1:
                let raw = try reader.readVarint()
                guard let value = Algorithm(rawValue: Int32(truncatingIfNeeded: raw))
                else {
                    throw DRMSystemError.malformedInitData(
                        systemID: .widevine,
                        reason: "Unknown Widevine algorithm value \(raw)"
                    )
                }
                algorithm = value
            case 2:
                let kid = try reader.readLengthDelimited()
                guard kid.count == 16 else {
                    throw DRMSystemError.malformedInitData(
                        systemID: .widevine,
                        reason: "Widevine key_id must be 16 bytes, got \(kid.count)"
                    )
                }
                keyIDs.append(kid)
            case 3:
                provider = try Self.readString(&reader)
            case 4:
                contentID = try reader.readLengthDelimited()
            case 5:
                trackType = try Self.readString(&reader)
            case 6:
                policy = try Self.readString(&reader)
            case 7:
                cryptoPeriodIndex = UInt32(truncatingIfNeeded: try reader.readVarint())
            case 8:
                groupedLicense = try reader.readLengthDelimited()
            case 9:
                let raw = UInt32(truncatingIfNeeded: try reader.readVarint())
                if let scheme = CommonEncryptionScheme(rawValue: raw) {
                    protectionScheme = scheme
                } else {
                    protectionSchemeRaw = raw
                }
            case 10:
                cryptoPeriodSeconds = UInt32(truncatingIfNeeded: try reader.readVarint())
            default:
                try reader.skip(wireType: wireType)
            }
        }
        return WidevineInitData(
            algorithm: algorithm,
            keyIDs: keyIDs,
            provider: provider,
            contentID: contentID,
            trackType: trackType,
            policy: policy,
            cryptoPeriodIndex: cryptoPeriodIndex,
            groupedLicense: groupedLicense,
            protectionScheme: protectionScheme,
            protectionSchemeRaw: protectionSchemeRaw,
            cryptoPeriodSeconds: cryptoPeriodSeconds
        )
    }

    /// Encode the typed `WidevineCencHeader` back to opaque pssh.data
    /// bytes. Fields are emitted in ascending field-number order so
    /// any value produced by ``parse(_:)`` followed by ``encode(_:)``
    /// round-trips byte-perfectly.
    public static func encode(_ value: WidevineInitData) throws -> Data {
        var writer = ProtocolBufferWriter()
        if let algorithm = value.algorithm {
            writer.writeVarintField(fieldNumber: 1, value: UInt64(UInt32(bitPattern: algorithm.rawValue)))
        }
        for kid in value.keyIDs {
            guard kid.count == 16 else {
                throw DRMSystemError.malformedInitData(
                    systemID: .widevine,
                    reason: "Widevine key_id must be 16 bytes on encode"
                )
            }
            writer.writeBytesField(fieldNumber: 2, value: kid)
        }
        if let provider = value.provider {
            writer.writeStringField(fieldNumber: 3, value: provider)
        }
        if let contentID = value.contentID {
            writer.writeBytesField(fieldNumber: 4, value: contentID)
        }
        if let trackType = value.trackType {
            writer.writeStringField(fieldNumber: 5, value: trackType)
        }
        if let policy = value.policy {
            writer.writeStringField(fieldNumber: 6, value: policy)
        }
        if let cryptoPeriodIndex = value.cryptoPeriodIndex {
            writer.writeVarintField(fieldNumber: 7, value: UInt64(cryptoPeriodIndex))
        }
        if let groupedLicense = value.groupedLicense {
            writer.writeBytesField(fieldNumber: 8, value: groupedLicense)
        }
        if let scheme = value.protectionScheme {
            writer.writeVarintField(fieldNumber: 9, value: UInt64(scheme.rawValue))
        } else if let rawScheme = value.protectionSchemeRaw {
            writer.writeVarintField(fieldNumber: 9, value: UInt64(rawScheme))
        }
        if let cryptoPeriodSeconds = value.cryptoPeriodSeconds {
            writer.writeVarintField(fieldNumber: 10, value: UInt64(cryptoPeriodSeconds))
        }
        return writer.data
    }

    private static func readString(_ reader: inout ProtocolBufferReader) throws -> String {
        let bytes = try reader.readLengthDelimited()
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw DRMSystemError.malformedInitData(
                systemID: .widevine,
                reason: "Widevine field string is not valid UTF-8"
            )
        }
        return string
    }
}

extension WidevineInitData: DRMInitDataParsing {
    public static var systemID: KnownDRMSystemID { .widevine }
    public typealias TypedInitData = WidevineInitData
}
