// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HDRMetadata
//
// Top-level HDR metadata struct. References types from the Color module,
// which are provided as minimal stubs in `Color/_ModulePlaceholder.swift`
// until the full Color module lands; the stubs preserve the public API
// surface exactly so this file requires no migration when that happens.

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
    public let masteringDisplay: MasteringDisplayMetadata?

    /// HDR10 content light level metadata (`clli`), if available.
    public let contentLightLevel: ContentLightLevelMetadata?

    /// Dolby Vision metadata (`dvcC` / `dvvC`), if available.
    public let dolbyVision: DolbyVisionMetadata?

    public init(
        dynamicRange: DynamicRange,
        colorPrimaries: ColorPrimaries,
        transferCharacteristics: TransferCharacteristics,
        matrixCoefficients: MatrixCoefficients,
        fullRange: Bool,
        masteringDisplay: MasteringDisplayMetadata? = nil,
        contentLightLevel: ContentLightLevelMetadata? = nil,
        dolbyVision: DolbyVisionMetadata? = nil
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
