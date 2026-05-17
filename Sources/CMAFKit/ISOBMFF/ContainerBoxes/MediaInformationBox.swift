// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MediaInformationBox (minf)
//
// Reference: ISO/IEC 14496-12 §8.4.4 (media information box).
//
// Container for the codec-specific media header (`vmhd` / `smhd` / `nmhd`
// / `sthd`), the data information (`dinf`), and the sample table (`stbl`).

import Foundation

/// Per-track media information container.
public struct MediaInformationBox: ISOContainerBox, Sendable {
    public static let boxType: FourCC = "minf"

    public let header: ISOBoxHeader
    public let children: [any ISOBox]

    public init(header: ISOBoxHeader, children: [any ISOBox]) {
        self.header = header
        self.children = children
    }

    public var dataInformation: DataInformationBox? {
        findChild(DataInformationBox.self)
    }

    public var sampleTable: SampleTableBox? {
        findChild(SampleTableBox.self)
    }

    /// The codec-specific media header child (`vmhd`, `smhd`, `nmhd`, or
    /// `sthd`). Returns the first child whose FourCC matches one of those
    /// values. Typed accessors for each variant arrive in a later session.
    public var mediaHeaderChild: (any ISOBox)? {
        let mediaHeaderTypes: Set<FourCC> = ["vmhd", "smhd", "nmhd", "sthd"]
        for child in children where mediaHeaderTypes.contains(wireType(of: child)) {
            return child
        }
        return nil
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MediaInformationBox {
        let isoBoxReader = ISOBoxReader()
        let children = try await isoBoxReader.readChildren(from: &reader, registry: registry)
        return MediaInformationBox(header: header, children: children)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            for child in children {
                child.encode(to: &body)
            }
        }
    }
}
