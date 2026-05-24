// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HeroEyeInformationBox (hero)
//
// Reference: Apple HEVC Stereo Video Profile §3.3 (public Apple specification).
//
// Identifies which view is the primary ("hero") view for monoscopic
// fallback rendering — for example, when a stereoscopic display is
// unavailable, when the user has disabled 3D, or when generating a
// 2D thumbnail.
//
// Body layout:
//
//   ┌───────────────────────────────────────────────────────────────┐
//   │ heroEye               :  UInt8                       (1 byte)  │
//   │ reserved              :  3 bytes (zero on encode, ignored on   │
//   │                          parse — round-trip preserves bytes)  │
//   └───────────────────────────────────────────────────────────────┘
//
// Total body size is 4 bytes for canonical 32-bit alignment.

import Foundation

/// Hero Eye Information Box (`hero`) — Apple HEVC Stereo Video Profile.
///
/// Identifies which view is the primary ("hero") view for monoscopic
/// fallback rendering.
///
/// Reference: Apple HEVC Stereo Video Profile §3.3 (public Apple specification).
public struct HeroEyeInformationBox: ISOBox, Sendable, Equatable, Hashable {

    public static let boxType: FourCC = "hero"

    /// Hero eye values per Apple HEVC Stereo Video Profile §3.3.
    public enum HeroEye: UInt8, Sendable, Hashable, Codable, CaseIterable {
        /// No hero — the stream is truly stereoscopic and neither eye is
        /// preferred. Monoscopic-fallback consumers may pick either view
        /// or apply a vendor-specific heuristic.
        case none = 0x00
        /// Left eye is the hero view for monoscopic fallback.
        case leftEye = 0x01
        /// Right eye is the hero view for monoscopic fallback.
        case rightEye = 0x02
    }

    /// The hero eye choice.
    public let heroEye: HeroEye

    public init(heroEye: HeroEye) {
        self.heroEye = heroEye
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> HeroEyeInformationBox {
        let bodySize = Int(header.size) - header.headerSize
        guard bodySize >= 4 else {
            throw ISOBoxError.sizeSmallerThanHeader(
                declared: header.size,
                headerSize: header.headerSize + 4,
                type: Self.boxType
            )
        }
        let raw = try reader.readUInt8()
        guard let heroEye = HeroEye(rawValue: raw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "unknown hero eye value \(raw)"
            )
        }
        // Skip the 3 reserved bytes.
        _ = try reader.readData(count: 3)
        return HeroEyeInformationBox(heroEye: heroEye)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt8(heroEye.rawValue)
            body.writeZeros(3)
        }
    }
}
