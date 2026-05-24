// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Region
//
// Reference: IETF RFC 5646 §2.2.4 (Region Subtag) + ISO 3166-1 (Codes
// for the representation of names of countries) + UN M.49 (Standard
// Country or Area Codes for Statistical Use).
//
// Region subtag of a BCP 47 language tag — either ISO 3166-1 alpha-2
// for country-level regions, or UN M.49 numeric for supra-national /
// continental regions.

import Foundation

/// Region subtag of a BCP 47 language tag.
///
/// Per RFC 5646 §2.2.4 the region subtag identifies a specific
/// geographic / political area. Two sources:
/// - **ISO 3166-1 alpha-2** (2-character uppercase, e.g., `"US"`,
///   `"BR"`, `"FR"`, `"CN"`) for country-level regions.
/// - **UN M.49** (3-digit numeric, e.g., `419` for Latin America,
///   `002` for Africa) for supra-national / continental regions.
///
/// References:
/// - IETF RFC 5646 §2.2.4 — Region Subtag
/// - ISO 3166-1 — Codes for the representation of names of countries (alpha-2)
/// - UN M.49 — Standard Country or Area Codes for Statistical Use
public enum Region: Sendable, Equatable, Hashable, Codable,
    CustomStringConvertible
{

    /// ISO 3166-1 alpha-2 region code (2 characters, uppercase canonical).
    case iso3166_1(String)

    /// UN M.49 numeric region code (3 digits, range `0..<1000`).
    /// Common values: `419` (Latin America and the Caribbean), `002`
    /// (Africa), `005` (South America), `009` (Oceania), `142` (Asia),
    /// `150` (Europe).
    case unM49(UInt16)

    /// Canonical string form per RFC 5646 §4.5: uppercase alpha-2 OR
    /// zero-padded 3-digit decimal.
    public var canonicalForm: String {
        switch self {
        case .iso3166_1(let value):
            return value.uppercased()
        case .unM49(let value):
            return String(format: "%03d", value)
        }
    }

    public var description: String { canonicalForm }
}
