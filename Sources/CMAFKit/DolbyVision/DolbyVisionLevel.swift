// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DolbyVisionLevel
//
// Reference: Dolby Vision Streams Within the ISO Base Media File Format
// (Dolby public specification), level table.
//
// Levels 1..13 are documented as of the latest published Dolby spec.
// Higher levels are reserved for future Dolby additions.

import Foundation

/// Dolby Vision performance level identifier.
///
/// Reference: Dolby Vision public specification. Each level corresponds
/// to maximum spatial resolution and frame-rate constraints (e.g.,
/// level 4 = up to 1280×720 at 60 fps or 1920×1080 at 24 fps).
public enum DolbyVisionLevel: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Up to 720x480 at 30 fps.
    case level01 = 1
    /// Up to 720x576 at 30 fps.
    case level02 = 2
    /// Up to 1280x720 at 30 fps.
    case level03 = 3
    /// Up to 1280x720 at 60 fps, or 1920x1080 at 24 fps.
    case level04 = 4
    /// Up to 1920x1080 at 30 fps.
    case level05 = 5
    /// Up to 1920x1080 at 60 fps, or 3840x2160 at 24 fps.
    case level06 = 6
    /// Up to 3840x2160 at 30 / 48 fps.
    case level07 = 7
    /// Up to 3840x2160 at 60 fps.
    case level08 = 8
    /// Up to 3840x2160 at 120 fps, or 7680x4320 at 24 fps.
    case level09 = 9
    /// Up to 7680x4320 at 30 fps.
    case level10 = 10
    /// Up to 7680x4320 at 60 fps.
    case level11 = 11
    /// Up to 7680x4320 at 120 fps.
    case level12 = 12
    /// Up to 7680x4320 at 120 fps (HFR variant).
    case level13 = 13
}
