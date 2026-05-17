// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ContentLightLevelBox (clli)
//
// Reference: ISO/IEC 14496-12 §12.1.7 + CTA-861.3.

import Foundation

/// Content light level box.
public struct ContentLightLevelBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "clli"

    public let metadata: ContentLightLevel

    public init(metadata: ContentLightLevel) {
        self.metadata = metadata
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ContentLightLevelBox {
        let maxCLL = try reader.readUInt16()
        let maxFALL = try reader.readUInt16()
        let metadata = ContentLightLevel(
            maxContentLightLevel: maxCLL,
            maxPicAverageLightLevel: maxFALL
        )
        return ContentLightLevelBox(metadata: metadata)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt16(metadata.maxContentLightLevel)
            body.writeUInt16(metadata.maxPicAverageLightLevel)
        }
    }
}
