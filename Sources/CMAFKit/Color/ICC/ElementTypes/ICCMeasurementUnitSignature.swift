// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCMeasurementUnitSignature
//
// Reference: ICC.1:2022 §10.20 + Annex A.4 (measurement unit signatures).
//
// The set of values is bounded; an unrecognised signature on the wire
// throws a parse error per the project-wide complete-coverage policy.

import Foundation

/// Measurement unit signature carried by ``ICCResponseCurveSet16Type``.
///
/// Reference: ICC.1:2022 §10.20.
public enum ICCMeasurementUnitSignature: UInt32, Sendable, Hashable, CaseIterable, Codable {
    /// Status A measurements ('StaA').
    case statusA = 0x5374_6141
    /// Status E measurements ('StaE').
    case statusE = 0x5374_6145
    /// Status I measurements ('StaI').
    case statusI = 0x5374_6149
    /// Status T measurements ('StaT').
    case statusT = 0x5374_6154
    /// Status M measurements ('StaM').
    case statusM = 0x5374_614D
    /// DIN measurements with no polarising filter ('DN  ').
    case dinNoFilter = 0x444E_2020
    /// DIN measurements with polarising filter ('DN P').
    case dinWithFilter = 0x444E_2050
    /// Narrow-band DIN with no polarising filter ('DNN ').
    case dinNarrowBandNoFilter = 0x444E_4E20
    /// Narrow-band DIN with polarising filter ('DNNP').
    case dinNarrowBandWithFilter = 0x444E_4E50
}
