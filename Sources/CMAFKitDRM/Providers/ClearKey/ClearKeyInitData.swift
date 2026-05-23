// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ClearKeyInitData
//
// Reference: W3C "Encrypted Media Extensions" §9 (Common Key
// Systems / ClearKey). The pssh.data for the W3C ClearKey system
// identifier `1077efec-c0b2-4d02-ace3-3c1e52e2fb4b` is a UTF-8
// JSON document whose schema is:
//
//   {
//     "kids": ["<base64url(KID-1)>", "<base64url(KID-2)>", ...],
//     "type": "temporary" | "persistent-license"
//   }
//
// `kids` is a JSON array of base64url-encoded (RFC 4648 §5; no
// padding) 16-byte key identifiers. `type` is `"temporary"` or
// `"persistent-license"` per W3C EME §9.

import Foundation

/// Typed W3C ClearKey init-data payload.
public struct ClearKeyInitData: Sendable, Hashable, Equatable, Codable {

    /// `type` field per W3C EME §9.
    public enum KeyType: String, Sendable, Hashable, CaseIterable, Codable {
        case temporary
        case persistentLicense = "persistent-license"
    }

    /// Each decoded key ID is the raw 16-byte UUID per ISO/IEC
    /// 23001-7 §8.2 (parsed from base64url on the wire).
    public let kids: [Data]
    /// `type` field value.
    public let type: KeyType

    public init(kids: [Data], type: KeyType) {
        for kid in kids {
            precondition(
                kid.count == 16,
                "ClearKey decoded kid must be exactly 16 bytes per ISO/IEC 23001-7 \u{00A7}8.2"
            )
        }
        self.kids = kids
        self.type = type
    }

    /// On-wire JSON shape per W3C EME §9.
    private struct WireFormat: Codable {
        let kids: [String]
        let type: String
    }

    public static func parse(_ data: Data) throws -> ClearKeyInitData {
        guard !data.isEmpty else {
            throw DRMSystemError.malformedInitData(
                systemID: .clearKey, reason: "ClearKey JSON is empty"
            )
        }
        let decoder = JSONDecoder()
        let wire: WireFormat
        do {
            wire = try decoder.decode(WireFormat.self, from: data)
        } catch {
            throw DRMSystemError.malformedInitData(
                systemID: .clearKey,
                reason: "ClearKey JSON parse failed: \(error)"
            )
        }
        guard let keyType = KeyType(rawValue: wire.type) else {
            throw DRMSystemError.malformedInitData(
                systemID: .clearKey,
                reason: "ClearKey type must be 'temporary' or 'persistent-license', got '\(wire.type)'"
            )
        }
        var kids: [Data] = []
        kids.reserveCapacity(wire.kids.count)
        for encoded in wire.kids {
            guard let bytes = Base64URL.decode(encoded) else {
                throw DRMSystemError.malformedInitData(
                    systemID: .clearKey,
                    reason: "ClearKey kid base64url decode failed for '\(encoded)'"
                )
            }
            guard bytes.count == 16 else {
                throw DRMSystemError.malformedInitData(
                    systemID: .clearKey,
                    reason: "ClearKey decoded kid must be 16 bytes, got \(bytes.count)"
                )
            }
            kids.append(bytes)
        }
        return ClearKeyInitData(kids: kids, type: keyType)
    }

    public static func encode(_ value: ClearKeyInitData) throws -> Data {
        // Canonical encoder: `kids` first, then `type`, no
        // whitespace, no escaped slashes. This yields byte-perfect
        // round-trip for fixtures the CMAFKitDRM encoder produces;
        // in-the-wild inputs that differ in whitespace re-encode
        // to canonical form (semantic equivalence retained).
        let wire = WireFormat(
            kids: value.kids.map { Base64URL.encode($0) },
            type: value.type.rawValue
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(wire)
        } catch {
            throw DRMSystemError.roundTripFailure(
                systemID: .clearKey,
                reason: "ClearKey JSON encode failed: \(error)"
            )
        }
    }
}

extension ClearKeyInitData: DRMInitDataParsing {
    public static var systemID: KnownDRMSystemID { .clearKey }
    public typealias TypedInitData = ClearKeyInitData
}
