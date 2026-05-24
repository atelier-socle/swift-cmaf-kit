// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - StereoInformationBox (stri)
//
// Reference: Apple HEVC Stereo Video Profile §3.2 (public Apple specification).
//
// Declares the stereo arrangement of a multi-layer HEVC stream and,
// optionally, the physical geometry of the capture rig (interaxial /
// convergence / baseline distances in millimeters).
//
// Body layout (network byte order):
//
//   ┌───────────────────────────────────────────────────────────────┐
//   │ stereoArrangement     :  UInt8                       (1 byte)  │
//   │ presenceFlags         :  UInt8                       (1 byte)  │
//   │   bit 0 (0x01)        :  interaxialDistance present            │
//   │   bit 1 (0x02)        :  convergenceDistance present           │
//   │   bit 2 (0x04)        :  baselineDistance present              │
//   │ reserved              :  UInt16 (zero on encode, ignored on    │
//   │                          parse — round-trip preserves bytes)  │
//   │ interaxialDistance_mm :  Float (IEEE 754 binary32) if present  │
//   │ convergenceDistance_mm:  Float                       if present│
//   │ baselineDistance_mm   :  Float                       if present│
//   └───────────────────────────────────────────────────────────────┘
//
// The reserved 2 bytes preserve 32-bit alignment of the floats that
// follow.

import Foundation

/// Stereo Information Box (`stri`) — Apple HEVC Stereo Video Profile.
///
/// Declares the stereo arrangement of a multi-layer HEVC stream and
/// (optionally) the physical geometry of the capture rig.
///
/// Reference: Apple HEVC Stereo Video Profile §3.2 (public Apple specification).
public struct StereoInformationBox: ISOBox, Sendable, Equatable, Hashable {

    public static let boxType: FourCC = "stri"

    /// Stereo arrangement values per Apple HEVC Stereo Video Profile §3.2.
    public enum StereoArrangement: UInt8, Sendable, Hashable, Codable, CaseIterable {
        /// Two views packed side-by-side in a single frame.
        case sideBySide = 0x01
        /// Two views packed top-bottom in a single frame.
        case topBottom = 0x02
        /// Two views interleaved frame-by-frame.
        case frameAlternating = 0x03
        /// Two views carried as separate layers of a multi-layer stream.
        ///
        /// Recommended for Apple Vision Pro Spatial Video (the
        /// `MVHEVCSampleEntry` / `hvc2` carriage path).
        case stereoLayered = 0x04
    }

    /// Stereo packing arrangement.
    public let stereoArrangement: StereoArrangement

    /// Distance between the two camera optical axes in millimeters
    /// (~63 mm for the human inter-pupillary distance).
    public let interaxialDistanceMillimeters: Float?

    /// Distance at which the two view planes converge in millimeters.
    public let convergenceDistanceMillimeters: Float?

    /// Stereo baseline distance in millimeters (often equivalent to the
    /// interaxial distance for parallel-axis rigs).
    public let baselineDistanceMillimeters: Float?

    public init(
        stereoArrangement: StereoArrangement,
        interaxialDistanceMillimeters: Float? = nil,
        convergenceDistanceMillimeters: Float? = nil,
        baselineDistanceMillimeters: Float? = nil
    ) {
        self.stereoArrangement = stereoArrangement
        self.interaxialDistanceMillimeters = interaxialDistanceMillimeters
        self.convergenceDistanceMillimeters = convergenceDistanceMillimeters
        self.baselineDistanceMillimeters = baselineDistanceMillimeters
    }

    /// Bit-flag layout of the `presenceFlags` byte.
    private enum PresenceFlag {
        static let interaxial: UInt8 = 0x01
        static let convergence: UInt8 = 0x02
        static let baseline: UInt8 = 0x04
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> StereoInformationBox {
        let bodySize = Int(header.size) - header.headerSize
        guard bodySize >= 4 else {
            throw ISOBoxError.sizeSmallerThanHeader(
                declared: header.size,
                headerSize: header.headerSize + 4,
                type: Self.boxType
            )
        }
        let arrangementRaw = try reader.readUInt8()
        guard let arrangement = StereoArrangement(rawValue: arrangementRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "unknown stereo arrangement value \(arrangementRaw)"
            )
        }
        let flags = try reader.readUInt8()
        _ = try reader.readUInt16()  // reserved (preserved for alignment)
        var consumed = 4

        var interaxial: Float?
        var convergence: Float?
        var baseline: Float?

        if flags & PresenceFlag.interaxial != 0 {
            guard bodySize >= consumed + 4 else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "presenceFlags declares interaxial but body too short"
                )
            }
            interaxial = Float(bitPattern: try reader.readUInt32())
            consumed += 4
        }
        if flags & PresenceFlag.convergence != 0 {
            guard bodySize >= consumed + 4 else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "presenceFlags declares convergence but body too short"
                )
            }
            convergence = Float(bitPattern: try reader.readUInt32())
            consumed += 4
        }
        if flags & PresenceFlag.baseline != 0 {
            guard bodySize >= consumed + 4 else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "presenceFlags declares baseline but body too short"
                )
            }
            baseline = Float(bitPattern: try reader.readUInt32())
            consumed += 4
        }

        return StereoInformationBox(
            stereoArrangement: arrangement,
            interaxialDistanceMillimeters: interaxial,
            convergenceDistanceMillimeters: convergence,
            baselineDistanceMillimeters: baseline
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt8(stereoArrangement.rawValue)
            var flags: UInt8 = 0
            if interaxialDistanceMillimeters != nil { flags |= PresenceFlag.interaxial }
            if convergenceDistanceMillimeters != nil { flags |= PresenceFlag.convergence }
            if baselineDistanceMillimeters != nil { flags |= PresenceFlag.baseline }
            body.writeUInt8(flags)
            body.writeUInt16(0)  // reserved
            if let value = interaxialDistanceMillimeters {
                body.writeUInt32(value.bitPattern)
            }
            if let value = convergenceDistanceMillimeters {
                body.writeUInt32(value.bitPattern)
            }
            if let value = baselineDistanceMillimeters {
                body.writeUInt32(value.bitPattern)
            }
        }
    }
}
