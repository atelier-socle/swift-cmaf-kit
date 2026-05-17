// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BoxRegistry color & HDR builtins
//
// Registers parsers for the colour-information family of boxes:
//   `colr` — ISO/IEC 14496-12 §12.1.5
//   `mdcv` — ISO/IEC 14496-12 §12.1.6 + SMPTE ST 2086
//   `clli` — ISO/IEC 14496-12 §12.1.7 + CTA-861.3
//   `dvcC` — Dolby Vision public specification
//   `dvvC` — Dolby Vision public specification

import Foundation

extension BoxRegistry {
    /// Register the colour-information and HDR-metadata box parsers.
    ///
    /// Called from ``registerBuiltinBoxes`` alongside the other built-in
    /// registration methods.
    internal func registerColorBuiltinBoxes() {
        register(ColorInformationBox.self) { reader, header, registry in
            try await ColorInformationBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MasteringDisplayColourVolumeBox.self) { reader, header, registry in
            try await MasteringDisplayColourVolumeBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(ContentLightLevelBox.self) { reader, header, registry in
            try await ContentLightLevelBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(DolbyVisionConfigurationBox.self) { reader, header, registry in
            try await DolbyVisionConfigurationBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(DolbyVisionELConfigurationBox.self) { reader, header, registry in
            try await DolbyVisionELConfigurationBox.parse(reader: &reader, header: header, registry: registry)
        }
    }
}
