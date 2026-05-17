// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HDRMetadata
//
// Reference: ISO/IEC 23001-8 + SMPTE ST 2086 + CTA-861.3 + Dolby Vision
// public specification. Aggregates the typed colour-and-HDR metadata
// surfaces a Media client may want to observe.

import Foundation

/// HDR metadata for a video track or frame.
public struct HDRMetadata: Sendable, Hashable {
    /// Dynamic-range classification (SDR, HDR10, HDR10+, Dolby Vision, HLG).
    public let dynamicRange: DynamicRange

    /// Colour primaries per ISO/IEC 23001-8 §7.
    public let colorPrimaries: ColorPrimaries

    /// Transfer characteristics per ISO/IEC 23001-8 §7.
    public let transferCharacteristics: TransferCharacteristics

    /// Matrix coefficients per ISO/IEC 23001-8 §7.
    public let matrixCoefficients: MatrixCoefficients

    /// `true` if the video uses the full quantisation range (0–255 for 8-bit),
    /// `false` for the studio range (16–235 luma / 16–240 chroma).
    public let fullRange: Bool

    /// HDR10 mastering display metadata (`mdcv`), if available.
    public let masteringDisplay: MasteringDisplayColourVolume?

    /// HDR10 content light level metadata (`clli`), if available.
    public let contentLightLevel: ContentLightLevel?

    /// Dolby Vision configuration (`dvcC` / `dvvC`), if available.
    public let dolbyVision: DolbyVisionConfiguration?

    public init(
        dynamicRange: DynamicRange,
        colorPrimaries: ColorPrimaries,
        transferCharacteristics: TransferCharacteristics,
        matrixCoefficients: MatrixCoefficients,
        fullRange: Bool,
        masteringDisplay: MasteringDisplayColourVolume? = nil,
        contentLightLevel: ContentLightLevel? = nil,
        dolbyVision: DolbyVisionConfiguration? = nil
    ) {
        self.dynamicRange = dynamicRange
        self.colorPrimaries = colorPrimaries
        self.transferCharacteristics = transferCharacteristics
        self.matrixCoefficients = matrixCoefficients
        self.fullRange = fullRange
        self.masteringDisplay = masteringDisplay
        self.contentLightLevel = contentLightLevel
        self.dolbyVision = dolbyVision
    }
}
