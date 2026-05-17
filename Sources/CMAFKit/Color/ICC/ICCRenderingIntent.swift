// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCRenderingIntent
//
// Reference: ICC.1:2022 §7.2.15 (rendering intent).

import Foundation

/// Rendering intent per ICC.1:2022 §7.2.15.
public enum ICCRenderingIntent: UInt32, Sendable, Hashable, CaseIterable, Codable {
    case perceptual = 0
    case mediaRelativeColorimetric = 1
    case saturation = 2
    case iccAbsoluteColorimetric = 3
}
