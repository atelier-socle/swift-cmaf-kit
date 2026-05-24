// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ViewExtendedUsageBox (vexu)
//
// Reference: Apple HEVC Stereo Video Profile §3.1 (public Apple specification).
//
// Identifies the view (left / right / mono / depth / auxiliary) and carries
// usage flags for the layer it accompanies in a multi-layer HEVC stream.
//
// Body layout (network byte order):
//
//   ┌───────────────────────────────────────────────────────────────┐
//   │ viewIdentifier        :  UInt32                      (4 bytes) │
//   │ usageFlags            :  UInt32                      (4 bytes) │
//   │ extensionData         :  remaining bytes (opaque, optional)    │
//   └───────────────────────────────────────────────────────────────┘
//
// The `extensionData` tail preserves any unknown / future-defined Apple
// extension bytes byte-for-byte, so this box round-trips losslessly even
// when consumed by an implementation that pre-dates a spec update.

import Foundation

/// View Extended Usage Box (`vexu`) — Apple HEVC Stereo Video Profile.
///
/// Identifies the view (left / right / mono / depth / auxiliary) and carries
/// usage flags for the layer it accompanies in a multi-layer HEVC stream.
///
/// This box is part of Apple's HEVC Stereo Video Profile public
/// specification, used in visionOS Spatial Video and other Apple multi-view
/// delivery pipelines.
///
/// Reference: Apple HEVC Stereo Video Profile §3.1 (public Apple specification).
public struct ViewExtendedUsageBox: ISOBox, Sendable, Equatable, Hashable {

    public static let boxType: FourCC = "vexu"

    /// View identifier per Apple HEVC Stereo Video Profile §3.1.
    ///
    /// Apple-defined values: `0` = left, `1` = right, `2` = mono, `3` = depth.
    /// Stored as an opaque `UInt32` so future / vendor-specific identifiers
    /// round-trip without loss.
    public let viewIdentifier: UInt32

    /// Usage flags per Apple HEVC Stereo Video Profile §3.1.
    ///
    /// Bit-flag set declaring the role of this view (stereo / mono / depth /
    /// auxiliary / hero). Stored as an opaque `UInt32` for the same forward
    /// compatibility reason as ``viewIdentifier``.
    public let usageFlags: UInt32

    /// Future-proof opaque preservation of any unknown / future-defined
    /// extension bytes that follow the typed fields.
    ///
    /// Empty for canonical inputs; non-empty when the box carries
    /// Apple-defined extension fields not yet typed by CMAFKit.
    public let extensionData: Data

    public init(
        viewIdentifier: UInt32,
        usageFlags: UInt32,
        extensionData: Data = .init()
    ) {
        self.viewIdentifier = viewIdentifier
        self.usageFlags = usageFlags
        self.extensionData = extensionData
    }

    /// Box-registry parse hook.
    ///
    /// Reads the two mandatory `UInt32` fields and consumes any remaining
    /// body bytes into ``extensionData``.
    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ViewExtendedUsageBox {
        let bodySize = Int(header.size) - header.headerSize
        guard bodySize >= 8 else {
            throw ISOBoxError.sizeSmallerThanHeader(
                declared: header.size,
                headerSize: header.headerSize + 8,
                type: Self.boxType
            )
        }
        let viewID = try reader.readUInt32()
        let flags = try reader.readUInt32()
        let extraBytes = bodySize - 8
        let extra = extraBytes > 0 ? try reader.readData(count: extraBytes) : Data()
        return ViewExtendedUsageBox(
            viewIdentifier: viewID,
            usageFlags: flags,
            extensionData: extra
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt32(viewIdentifier)
            body.writeUInt32(usageFlags)
            if !extensionData.isEmpty {
                body.writeData(extensionData)
            }
        }
    }
}
