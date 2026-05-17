// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - RestrictedICCProfile (rICC)
//
// Reference: ISO/IEC 14496-12 §12.1.5 (colour information box, restricted
// ICC profile sub-type).
//
// Wraps an ``ICCProfile`` and validates the restrictions specified by
// the ISO base-media file format. The validation requires the profile
// class to be 'mntr' (display device).

import Foundation

/// ICC profile constrained per ISO/IEC 14496-12 §12.1.5.
public struct RestrictedICCProfile: Sendable, Hashable, Equatable {
    public let profile: ICCProfile

    public init(profile: ICCProfile) throws {
        try Self.validate(profile: profile)
        self.profile = profile
    }

    /// Validate the ISO/IEC 14496-12 §12.1.5 constraints.
    public static func validate(profile: ICCProfile) throws {
        guard profile.header.profileClass == .displayDevice else {
            throw ISOBoxError.malformedFullBox(
                type: ColorInformationBox.boxType,
                reason: "Restricted ICC profile class must be 'mntr' (display device), got \(profile.header.profileClass)"
            )
        }
    }

    public static func parse(reader: inout BinaryReader) throws -> RestrictedICCProfile {
        let profile = try ICCProfile.parse(reader: &reader)
        return try RestrictedICCProfile(profile: profile)
    }

    public func encode(to writer: inout BinaryWriter) {
        profile.encode(to: &writer)
    }
}
