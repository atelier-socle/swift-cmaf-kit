// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCProfileClass
//
// Reference: ICC.1:2022 §7.2.5 (profile class).

import Foundation

/// Profile class signature per ICC.1:2022 §7.2.5.
public enum ICCProfileClass: UInt32, Sendable, Hashable, CaseIterable, Codable {
    /// Input device profile ('scnr').
    case inputDevice = 0x7363_6E72
    /// Display device profile ('mntr').
    case displayDevice = 0x6D6E_7472
    /// Output device profile ('prtr').
    case outputDevice = 0x7072_7472
    /// DeviceLink profile ('link').
    case deviceLink = 0x6C69_6E6B
    /// ColorSpace conversion profile ('spac').
    case colorSpace = 0x7370_6163
    /// Abstract profile ('abst').
    case abstract = 0x6162_7374
    /// NamedColor profile ('nmcl').
    case namedColor = 0x6E6D_636C
}
