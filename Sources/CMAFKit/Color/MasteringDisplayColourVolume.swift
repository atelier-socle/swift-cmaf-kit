// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MasteringDisplayColourVolume
//
// Reference: SMPTE ST 2086:2018 (mastering display colour volume metadata).
//
// Encoded in ISO base-media files as the body of the `mdcv` box.

import Foundation

/// Mastering-display colour volume metadata, per SMPTE ST 2086.
///
/// Chromaticity coordinates are stored as integer values where 1 unit
/// equals 0.00002 (so the full unit range is 0..50000 representing
/// 0.0..1.0). Luminance values are stored as integer values where 1
/// unit equals 0.0001 cd/m² (so the value range covers 0.0001..429496.7295
/// cd/m²).
public struct MasteringDisplayColourVolume: Sendable, Hashable, Codable {
    /// Display primary R chromaticity x (units of 0.00002).
    public let displayPrimaryRedX: UInt16
    /// Display primary R chromaticity y (units of 0.00002).
    public let displayPrimaryRedY: UInt16
    /// Display primary G chromaticity x.
    public let displayPrimaryGreenX: UInt16
    /// Display primary G chromaticity y.
    public let displayPrimaryGreenY: UInt16
    /// Display primary B chromaticity x.
    public let displayPrimaryBlueX: UInt16
    /// Display primary B chromaticity y.
    public let displayPrimaryBlueY: UInt16
    /// White point chromaticity x.
    public let whitePointX: UInt16
    /// White point chromaticity y.
    public let whitePointY: UInt16
    /// Max display mastering luminance (units of 0.0001 cd/m²).
    public let maxDisplayMasteringLuminance: UInt32
    /// Min display mastering luminance (units of 0.0001 cd/m²).
    public let minDisplayMasteringLuminance: UInt32

    public init(
        displayPrimaryRedX: UInt16,
        displayPrimaryRedY: UInt16,
        displayPrimaryGreenX: UInt16,
        displayPrimaryGreenY: UInt16,
        displayPrimaryBlueX: UInt16,
        displayPrimaryBlueY: UInt16,
        whitePointX: UInt16,
        whitePointY: UInt16,
        maxDisplayMasteringLuminance: UInt32,
        minDisplayMasteringLuminance: UInt32
    ) {
        self.displayPrimaryRedX = displayPrimaryRedX
        self.displayPrimaryRedY = displayPrimaryRedY
        self.displayPrimaryGreenX = displayPrimaryGreenX
        self.displayPrimaryGreenY = displayPrimaryGreenY
        self.displayPrimaryBlueX = displayPrimaryBlueX
        self.displayPrimaryBlueY = displayPrimaryBlueY
        self.whitePointX = whitePointX
        self.whitePointY = whitePointY
        self.maxDisplayMasteringLuminance = maxDisplayMasteringLuminance
        self.minDisplayMasteringLuminance = minDisplayMasteringLuminance
    }

    /// Red chromaticity x as a normalised value in 0.0..1.0.
    public var redXNormalised: Double { Double(displayPrimaryRedX) * 0.00002 }
    /// Red chromaticity y as a normalised value in 0.0..1.0.
    public var redYNormalised: Double { Double(displayPrimaryRedY) * 0.00002 }
    /// Green chromaticity x as a normalised value.
    public var greenXNormalised: Double { Double(displayPrimaryGreenX) * 0.00002 }
    public var greenYNormalised: Double { Double(displayPrimaryGreenY) * 0.00002 }
    public var blueXNormalised: Double { Double(displayPrimaryBlueX) * 0.00002 }
    public var blueYNormalised: Double { Double(displayPrimaryBlueY) * 0.00002 }
    public var whitePointXNormalised: Double { Double(whitePointX) * 0.00002 }
    public var whitePointYNormalised: Double { Double(whitePointY) * 0.00002 }
    /// Max display mastering luminance in cd/m².
    public var maxLuminanceCdM2: Double { Double(maxDisplayMasteringLuminance) * 0.0001 }
    /// Min display mastering luminance in cd/m².
    public var minLuminanceCdM2: Double { Double(minDisplayMasteringLuminance) * 0.0001 }
}
