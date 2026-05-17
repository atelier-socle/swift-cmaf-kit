// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ColorInformationBox (colr)
//
// Reference: ISO/IEC 14496-12 §12.1.5 (colour information box).
//
// The box dispatches on a 4-byte sub-type FourCC:
//   `nclx` — 4 bytes of coding-independent code points + full-range flag
//   `rICC` — restricted ICC profile (per §12.1.5 constraints)
//   `prof` — unrestricted ICC profile

import Foundation

/// The colour-information variant carried by ``ColorInformationBox``.
///
/// Reference: ISO/IEC 14496-12 §12.1.5.
public enum ColorInformationVariant: Sendable, Equatable, Hashable {
    /// Coding-independent code points + full-range flag (4 bytes).
    case nclx(NCLXColorInformation)
    /// Restricted ICC profile (the constrained subset per §12.1.5).
    case restrictedICC(RestrictedICCProfile)
    /// Unrestricted ICC profile.
    case unrestrictedICC(UnrestrictedICCProfile)

    /// The 4-byte sub-type FourCC carried on the wire.
    public var wireSubType: FourCC {
        switch self {
        case .nclx: return "nclx"
        case .restrictedICC: return "rICC"
        case .unrestrictedICC: return "prof"
        }
    }
}

/// Colour information box.
public struct ColorInformationBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "colr"

    public let variant: ColorInformationVariant

    public init(variant: ColorInformationVariant) {
        self.variant = variant
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ColorInformationBox {
        let subType = try reader.readFourCC()
        let variant: ColorInformationVariant
        switch subType {
        case "nclx":
            let nclx = try NCLXColorInformation.parse(reader: &reader)
            variant = .nclx(nclx)
        case "rICC":
            let profile = try RestrictedICCProfile.parse(reader: &reader)
            variant = .restrictedICC(profile)
        case "prof":
            let profile = try UnrestrictedICCProfile.parse(reader: &reader)
            variant = .unrestrictedICC(profile)
        default:
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown colour information sub-type \(subType)"
            )
        }
        return ColorInformationBox(variant: variant)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeFourCC(variant.wireSubType)
            switch variant {
            case .nclx(let nclx):
                nclx.encode(to: &body)
            case .restrictedICC(let profile):
                profile.encode(to: &body)
            case .unrestrictedICC(let profile):
                profile.encode(to: &body)
            }
        }
    }
}
