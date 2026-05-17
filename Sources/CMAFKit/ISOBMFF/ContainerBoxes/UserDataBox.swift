// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - UserDataBox (udta)
//
// Reference: ISO/IEC 14496-12 §8.10.1 (user data box).
//
// Container for arbitrary user data. Common children include `cprt`
// (copyright), `meta`, and vendor-specific tags. CMAFKit preserves the
// children as-is.

import Foundation

/// Per-track or movie-level user-data container.
///
/// Children are arbitrary and CMAFKit makes no assumption about their
/// content. Round-trip is byte-perfect through ``UnknownBox`` fallback.
public struct UserDataBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "udta"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> UserDataBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return UserDataBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
