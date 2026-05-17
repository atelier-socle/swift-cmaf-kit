// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProResFlavor
//
// Apple ProRes profile identifiers. Reference: Apple ProRes White Paper.

import Foundation

/// Apple ProRes profile identifier, expressed as its FourCC raw value.
public enum ProResFlavor: UInt32, Sendable, Hashable, CaseIterable {
    /// ProRes 422 Proxy — `apco`.
    case proxy = 0x6170_636F
    /// ProRes 422 LT — `apcs`.
    case lt = 0x6170_6373
    /// ProRes 422 — `apcn`.
    case standard = 0x6170_636E
    /// ProRes 422 HQ — `apch`.
    case hq = 0x6170_6368
    /// ProRes 4444 — `ap4h`.
    case ap4h = 0x6170_3468
    /// ProRes 4444 XQ — `ap4x`.
    case ap4x = 0x6170_3478

    /// `FourCC` representation of this flavor.
    public var fourCC: FourCC { FourCC(rawValue) }
}
