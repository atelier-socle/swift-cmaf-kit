// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - UnrestrictedICCProfile (prof)
//
// Reference: ISO/IEC 14496-12 §12.1.5 (colour information box, full ICC
// profile sub-type).
//
// Wraps an ``ICCProfile`` with no additional restriction beyond ICC.1
// validity.

import Foundation

/// ICC profile with no ISO restriction beyond ICC.1 validity.
public struct UnrestrictedICCProfile: Sendable, Hashable, Equatable {
    public let profile: ICCProfile

    public init(profile: ICCProfile) {
        self.profile = profile
    }

    public static func parse(reader: inout BinaryReader) throws -> UnrestrictedICCProfile {
        let profile = try ICCProfile.parse(reader: &reader)
        return UnrestrictedICCProfile(profile: profile)
    }

    public func encode(to writer: inout BinaryWriter) {
        profile.encode(to: &writer)
    }
}
