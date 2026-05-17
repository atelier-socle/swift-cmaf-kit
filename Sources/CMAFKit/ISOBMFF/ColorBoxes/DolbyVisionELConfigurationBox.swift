// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DolbyVisionELConfigurationBox (dvvC)
//
// Reference: Dolby Vision public specification — Dolby Vision Streams
// Within the ISO Base Media File Format.

import Foundation

/// Dolby Vision enhancement-layer configuration box (`dvvC`).
public struct DolbyVisionELConfigurationBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "dvvC"

    public let elConfiguration: DolbyVisionELConfiguration

    public init(elConfiguration: DolbyVisionELConfiguration) {
        self.elConfiguration = elConfiguration
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> DolbyVisionELConfigurationBox {
        let el = try DolbyVisionELConfiguration.parse(reader: &reader)
        return DolbyVisionELConfigurationBox(elConfiguration: el)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            elConfiguration.encode(to: &body)
        }
    }
}
