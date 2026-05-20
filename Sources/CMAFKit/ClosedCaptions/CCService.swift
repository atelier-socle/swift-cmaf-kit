// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CCService
//
// Reference: CTA-708-E §5 (DTVCC service numbers) and CTA-608-E
// (CEA-608 caption channels).
//
// Exhaustive 67-case enum: CEA-608 channels cc1..cc4 plus
// CEA-708 services 1..63.

import Foundation

/// Closed-caption service identifier.
public enum CCService: Sendable, Hashable, Equatable, Codable {
    // CEA-608 channels
    case cc1, cc2, cc3, cc4
    // CEA-708 services
    case service1, service2, service3, service4, service5, service6, service7, service8
    case service9, service10, service11, service12, service13, service14, service15, service16
    case service17, service18, service19, service20, service21, service22, service23, service24
    case service25, service26, service27, service28, service29, service30, service31, service32
    case service33, service34, service35, service36, service37, service38, service39, service40
    case service41, service42, service43, service44, service45, service46, service47, service48
    case service49, service50, service51, service52, service53, service54, service55, service56
    case service57, service58, service59, service60, service61, service62, service63

    /// The raw service number as encoded on the wire.
    ///
    /// CEA-608 channels are encoded with values 1-4 in the CEA-708
    /// service-number field (per ATSC A/72), so they share the
    /// same numeric space as CEA-708 services 1..4 — the
    /// difference is purely contextual (CEA-608 ride inside the
    /// CEA-708 transport stream).
    public var wireNumber: UInt8 {
        switch self {
        case .cc1: return 1
        case .cc2: return 2
        case .cc3: return 3
        case .cc4: return 4
        case .service1: return 1
        case .service2: return 2
        case .service3: return 3
        case .service4: return 4
        case .service5: return 5
        case .service6: return 6
        case .service7: return 7
        case .service8: return 8
        case .service9: return 9
        case .service10: return 10
        case .service11: return 11
        case .service12: return 12
        case .service13: return 13
        case .service14: return 14
        case .service15: return 15
        case .service16: return 16
        case .service17: return 17
        case .service18: return 18
        case .service19: return 19
        case .service20: return 20
        case .service21: return 21
        case .service22: return 22
        case .service23: return 23
        case .service24: return 24
        case .service25: return 25
        case .service26: return 26
        case .service27: return 27
        case .service28: return 28
        case .service29: return 29
        case .service30: return 30
        case .service31: return 31
        case .service32: return 32
        case .service33: return 33
        case .service34: return 34
        case .service35: return 35
        case .service36: return 36
        case .service37: return 37
        case .service38: return 38
        case .service39: return 39
        case .service40: return 40
        case .service41: return 41
        case .service42: return 42
        case .service43: return 43
        case .service44: return 44
        case .service45: return 45
        case .service46: return 46
        case .service47: return 47
        case .service48: return 48
        case .service49: return 49
        case .service50: return 50
        case .service51: return 51
        case .service52: return 52
        case .service53: return 53
        case .service54: return 54
        case .service55: return 55
        case .service56: return 56
        case .service57: return 57
        case .service58: return 58
        case .service59: return 59
        case .service60: return 60
        case .service61: return 61
        case .service62: return 62
        case .service63: return 63
        }
    }

    /// Construct the CEA-708 service for the supplied 6-bit
    /// wire number (1..63). Returns nil when the number is out
    /// of range.
    public static func cea708Service(forWireNumber number: UInt8) -> CCService? {
        guard (1...63).contains(number) else { return nil }
        return Self.servicesByWireNumber[Int(number) - 1]
    }

    /// Pre-built table indexed by `wireNumber - 1`. Drives
    /// ``cea708Service(forWireNumber:)`` so that lookup is O(1)
    /// without exploding cyclomatic complexity.
    private static let servicesByWireNumber: [CCService] = [
        .service1, .service2, .service3, .service4, .service5, .service6,
        .service7, .service8, .service9, .service10, .service11, .service12,
        .service13, .service14, .service15, .service16, .service17, .service18,
        .service19, .service20, .service21, .service22, .service23, .service24,
        .service25, .service26, .service27, .service28, .service29, .service30,
        .service31, .service32, .service33, .service34, .service35, .service36,
        .service37, .service38, .service39, .service40, .service41, .service42,
        .service43, .service44, .service45, .service46, .service47, .service48,
        .service49, .service50, .service51, .service52, .service53, .service54,
        .service55, .service56, .service57, .service58, .service59, .service60,
        .service61, .service62, .service63
    ]

    /// Convenience explicit `allCases` list. (`CaseIterable` is
    /// deliberately not adopted on this 67-case enum to keep
    /// compile times stable on debug builds.)
    public static let allKnownCases: [CCService] = [
        .cc1, .cc2, .cc3, .cc4,
        .service1, .service2, .service3, .service4, .service5, .service6,
        .service7, .service8, .service9, .service10, .service11, .service12,
        .service13, .service14, .service15, .service16, .service17, .service18,
        .service19, .service20, .service21, .service22, .service23, .service24,
        .service25, .service26, .service27, .service28, .service29, .service30,
        .service31, .service32, .service33, .service34, .service35, .service36,
        .service37, .service38, .service39, .service40, .service41, .service42,
        .service43, .service44, .service45, .service46, .service47, .service48,
        .service49, .service50, .service51, .service52, .service53, .service54,
        .service55, .service56, .service57, .service58, .service59, .service60,
        .service61, .service62, .service63
    ]
}
