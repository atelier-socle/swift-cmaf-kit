// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - KnownDRMSystemID
//
// Reference: DASH-IF "DRM System Identifiers" registry
// (https://dashif.org/identifiers/content_protection/), W3C
// Encrypted Media Extensions Initialization Data Format Registry,
// ISO/IEC 23001-7 §8.1.1 (pssh box).
//
// Each named case is a canonical UUID published by the DRM
// vendor's public specification. The `other(UUID)` arm carries
// any system identifier CMAFKit does not yet recognise so the
// caller can still discriminate, route, and round-trip the pssh
// payload byte-for-byte without losing the system identifier.

import Foundation

/// Stable typed identifier for a Common Encryption DRM system.
///
/// Use ``init(uuid:)`` to lift a raw `UUID` to the typed case
/// (the named arms when the UUID is registered, ``other(_:)``
/// otherwise). ``uuid`` returns the canonical UUID for the
/// named cases and the wrapped UUID for ``other(_:)``.
public enum KnownDRMSystemID: Sendable, Hashable, Equatable, Codable {
    /// Google Widevine — `edef8ba9-79d6-4ace-a3c8-27dcd51d21ed`
    /// per DASH-IF and W3C EME registries.
    case widevine
    /// Microsoft PlayReady —
    /// `9a04f079-9840-4286-ab92-e65be0885f95` per Microsoft
    /// public specification, DASH-IF, and W3C EME.
    case playReady
    /// Apple FairPlay Streaming —
    /// `94ce86fb-07ff-4f43-adb8-93d2fa968ca2` per Apple FairPlay
    /// Streaming public documentation.
    case fairPlay
    /// W3C ClearKey reference scheme —
    /// `1077efec-c0b2-4d02-ace3-3c1e52e2fb4b` per the W3C EME
    /// ClearKey specification.
    case clearKey
    /// Marlin / Marlin Broadband —
    /// `5e629af5-38da-4063-8977-97ffbd9902d4` per DASH-IF.
    case marlin
    /// Nagra MediaAccess PRM —
    /// `adb41c24-2dbf-4a6d-958b-4457c0d27b95` per DASH-IF.
    case nagra
    /// Verimatrix VCAS —
    /// `9a27dd82-fde2-4725-8cbc-4234aa06ec09` per DASH-IF.
    case verimatrix
    /// Adobe Primetime —
    /// `f239e769-efa3-4850-9c16-a903c6932efb` per DASH-IF.
    case adobePrimetime
    /// ChinaDRM — `3d5e6d35-9b9a-41e8-b843-dd3c6e72c42c` per
    /// DASH-IF.
    case chinaDRM
    /// Any other system identifier not yet recognised by
    /// CMAFKitDRM. Carries the raw UUID so callers can still
    /// discriminate and round-trip the pssh.
    case other(UUID)

    /// The canonical UUID for this DRM system.
    public var uuid: UUID {
        switch self {
        case .widevine:
            return Self.widevineUUID
        case .playReady:
            return Self.playReadyUUID
        case .fairPlay:
            return Self.fairPlayUUID
        case .clearKey:
            return Self.clearKeyUUID
        case .marlin:
            return Self.marlinUUID
        case .nagra:
            return Self.nagraUUID
        case .verimatrix:
            return Self.verimatrixUUID
        case .adobePrimetime:
            return Self.adobePrimetimeUUID
        case .chinaDRM:
            return Self.chinaDRMUUID
        case .other(let value):
            return value
        }
    }

    /// Construct a typed system identifier from a raw UUID.
    ///
    /// Returns the corresponding named case if the UUID matches a
    /// publicly-registered DRM system, otherwise returns
    /// ``other(_:)`` wrapping the supplied UUID. The initialiser
    /// never returns nil — every UUID maps to one case.
    public init(uuid: UUID) {
        switch uuid {
        case Self.widevineUUID:
            self = .widevine
        case Self.playReadyUUID:
            self = .playReady
        case Self.fairPlayUUID:
            self = .fairPlay
        case Self.clearKeyUUID:
            self = .clearKey
        case Self.marlinUUID:
            self = .marlin
        case Self.nagraUUID:
            self = .nagra
        case Self.verimatrixUUID:
            self = .verimatrix
        case Self.adobePrimetimeUUID:
            self = .adobePrimetime
        case Self.chinaDRMUUID:
            self = .chinaDRM
        default:
            self = .other(uuid)
        }
    }

    /// All 9 named cases.
    ///
    /// `CaseIterable` cannot be synthesised on an enum carrying
    /// an associated-value case like ``other(_:)``; this static
    /// list is the conventional substitute. It excludes
    /// ``other(_:)``.
    public static let allKnownCases: [KnownDRMSystemID] = [
        .widevine,
        .playReady,
        .fairPlay,
        .clearKey,
        .marlin,
        .nagra,
        .verimatrix,
        .adobePrimetime,
        .chinaDRM
    ]

    // MARK: - Canonical UUID constants
    //
    // The UUIDs below are constructed from raw byte tuples so the
    // initialiser is total (never fails) and no force-unwrap is
    // required. Each tuple is the canonical 16-byte big-endian
    // encoding of the registered UUID.

    /// `edef8ba9-79d6-4ace-a3c8-27dcd51d21ed`.
    internal static let widevineUUID = UUID(
        uuid: (
            0xED, 0xEF, 0x8B, 0xA9,
            0x79, 0xD6, 0x4A, 0xCE,
            0xA3, 0xC8, 0x27, 0xDC,
            0xD5, 0x1D, 0x21, 0xED
        )
    )
    /// `9a04f079-9840-4286-ab92-e65be0885f95`.
    internal static let playReadyUUID = UUID(
        uuid: (
            0x9A, 0x04, 0xF0, 0x79,
            0x98, 0x40, 0x42, 0x86,
            0xAB, 0x92, 0xE6, 0x5B,
            0xE0, 0x88, 0x5F, 0x95
        )
    )
    /// `94ce86fb-07ff-4f43-adb8-93d2fa968ca2`.
    internal static let fairPlayUUID = UUID(
        uuid: (
            0x94, 0xCE, 0x86, 0xFB,
            0x07, 0xFF, 0x4F, 0x43,
            0xAD, 0xB8, 0x93, 0xD2,
            0xFA, 0x96, 0x8C, 0xA2
        )
    )
    /// `1077efec-c0b2-4d02-ace3-3c1e52e2fb4b`.
    internal static let clearKeyUUID = UUID(
        uuid: (
            0x10, 0x77, 0xEF, 0xEC,
            0xC0, 0xB2, 0x4D, 0x02,
            0xAC, 0xE3, 0x3C, 0x1E,
            0x52, 0xE2, 0xFB, 0x4B
        )
    )
    /// `5e629af5-38da-4063-8977-97ffbd9902d4`.
    internal static let marlinUUID = UUID(
        uuid: (
            0x5E, 0x62, 0x9A, 0xF5,
            0x38, 0xDA, 0x40, 0x63,
            0x89, 0x77, 0x97, 0xFF,
            0xBD, 0x99, 0x02, 0xD4
        )
    )
    /// `adb41c24-2dbf-4a6d-958b-4457c0d27b95`.
    internal static let nagraUUID = UUID(
        uuid: (
            0xAD, 0xB4, 0x1C, 0x24,
            0x2D, 0xBF, 0x4A, 0x6D,
            0x95, 0x8B, 0x44, 0x57,
            0xC0, 0xD2, 0x7B, 0x95
        )
    )
    /// `9a27dd82-fde2-4725-8cbc-4234aa06ec09`.
    internal static let verimatrixUUID = UUID(
        uuid: (
            0x9A, 0x27, 0xDD, 0x82,
            0xFD, 0xE2, 0x47, 0x25,
            0x8C, 0xBC, 0x42, 0x34,
            0xAA, 0x06, 0xEC, 0x09
        )
    )
    /// `f239e769-efa3-4850-9c16-a903c6932efb`.
    internal static let adobePrimetimeUUID = UUID(
        uuid: (
            0xF2, 0x39, 0xE7, 0x69,
            0xEF, 0xA3, 0x48, 0x50,
            0x9C, 0x16, 0xA9, 0x03,
            0xC6, 0x93, 0x2E, 0xFB
        )
    )
    /// `3d5e6d35-9b9a-41e8-b843-dd3c6e72c42c`.
    internal static let chinaDRMUUID = UUID(
        uuid: (
            0x3D, 0x5E, 0x6D, 0x35,
            0x9B, 0x9A, 0x41, 0xE8,
            0xB8, 0x43, 0xDD, 0x3C,
            0x6E, 0x72, 0xC4, 0x2C
        )
    )
}
