// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DolbyVisionConfigurationBox (dvcC)
//
// Reference: Dolby Vision public specification — Dolby Vision Streams
// Within the ISO Base Media File Format.

import Foundation

/// Dolby Vision configuration box (`dvcC`).
public struct DolbyVisionConfigurationBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "dvcC"

    public let configuration: DolbyVisionConfiguration

    public init(configuration: DolbyVisionConfiguration) {
        self.configuration = configuration
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> DolbyVisionConfigurationBox {
        let config = try DolbyVisionConfiguration.parse(reader: &reader)
        return DolbyVisionConfigurationBox(configuration: config)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            configuration.encode(to: &body)
        }
    }
}
