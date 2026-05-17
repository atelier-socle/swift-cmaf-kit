// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCPrimaryPlatform
//
// Reference: ICC.1:2022 §7.2.10 (primary platform signature).

import Foundation

/// Primary platform signature per ICC.1:2022 §7.2.10.
///
/// The four standard platforms; an all-zero field indicates an
/// unspecified or platform-independent profile.
public enum ICCPrimaryPlatform: UInt32, Sendable, Hashable, CaseIterable, Codable {
    /// Apple Computer, Inc. ('APPL').
    case apple = 0x4150_504C
    /// Microsoft Corporation ('MSFT').
    case microsoft = 0x4D53_4654
    /// Silicon Graphics, Inc. ('SGI ').
    case silicon = 0x5347_4920
    /// Sun Microsystems, Inc. ('SUNW').
    case sun = 0x5355_4E57
    /// Unspecified platform.
    case unspecified = 0
}
