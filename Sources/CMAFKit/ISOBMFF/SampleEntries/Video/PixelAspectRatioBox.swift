// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - PixelAspectRatioBox (pasp)
//
// Reference: ISO/IEC 14496-12 §12.1.4.

import Foundation

/// Pixel aspect ratio of stored video samples.
///
/// Reference: ISO/IEC 14496-12 §12.1.4. The `hSpacing : vSpacing` ratio
/// is applied to the stored pixel dimensions to produce the displayed
/// pixel dimensions.
public struct PixelAspectRatioBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "pasp"

    public let hSpacing: UInt32
    public let vSpacing: UInt32

    public init(hSpacing: UInt32, vSpacing: UInt32) {
        self.hSpacing = hSpacing
        self.vSpacing = vSpacing
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> PixelAspectRatioBox {
        let hSpacing = try reader.readUInt32()
        let vSpacing = try reader.readUInt32()
        return PixelAspectRatioBox(hSpacing: hSpacing, vSpacing: vSpacing)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt32(hSpacing)
            body.writeUInt32(vSpacing)
        }
    }
}
