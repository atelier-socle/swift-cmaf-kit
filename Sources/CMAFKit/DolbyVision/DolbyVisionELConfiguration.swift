// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DolbyVisionELConfiguration
//
// Reference: Dolby Vision Streams Within the ISO Base Media File Format
// (Dolby public specification), section "Dolby Vision EL Configuration Box".
//
// The `dvvC` box uses the same layout as `dvcC` and signals an
// enhancement-layer configuration. CMAFKit reuses the configuration
// fields of `DolbyVisionConfiguration`.

import Foundation

/// Dolby Vision enhancement-layer configuration carried by
/// ``DolbyVisionELConfigurationBox`` (`dvvC`).
public struct DolbyVisionELConfiguration: Sendable, Hashable, Equatable, Codable {
    public let configuration: DolbyVisionConfiguration

    public init(configuration: DolbyVisionConfiguration) {
        self.configuration = configuration
    }

    public static func parse(reader: inout BinaryReader) throws -> DolbyVisionELConfiguration {
        let config = try DolbyVisionConfiguration.parse(reader: &reader)
        return DolbyVisionELConfiguration(configuration: config)
    }

    public func encode(to writer: inout BinaryWriter) {
        configuration.encode(to: &writer)
    }
}
