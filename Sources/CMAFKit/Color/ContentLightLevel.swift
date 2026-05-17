// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ContentLightLevel
//
// Reference: CTA-861.3 (HDR static metadata extensions, content light
// level information).

import Foundation

/// Maximum content light level and maximum frame-average light level.
///
/// Reference: CTA-861.3. Both values are integer cd/m² values.
public struct ContentLightLevel: Sendable, Hashable, Codable {
    /// Maximum content light level (MaxCLL) in cd/m².
    public let maxContentLightLevel: UInt16
    /// Maximum picture average light level (MaxFALL) in cd/m².
    public let maxPicAverageLightLevel: UInt16

    public init(maxContentLightLevel: UInt16, maxPicAverageLightLevel: UInt16) {
        self.maxContentLightLevel = maxContentLightLevel
        self.maxPicAverageLightLevel = maxPicAverageLightLevel
    }
}
