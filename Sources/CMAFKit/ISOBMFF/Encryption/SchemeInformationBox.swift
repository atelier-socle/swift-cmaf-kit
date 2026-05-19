// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SchemeInformationBox (schi)
//
// Reference: ISO/IEC 14496-12 §8.12.6.
//
// Container child of `sinf`. For Common Encryption schemes the only
// documented child is `tenc`; non-CENC DRM schemes may add their own
// scheme-specific boxes which CMAFKit preserves opaquely for
// byte-perfect round-trip.

import Foundation

/// Scheme information box (`schi`) per ISO/IEC 14496-12 §8.12.6.
public struct SchemeInformationBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "schi"

    /// Typed `tenc` child. Mandatory inside a CENC `sinf`; nil for
    /// non-CENC schemes (where the scheme's own boxes carry the
    /// equivalent metadata).
    public let trackEncryption: TrackEncryptionBox?
    /// Any other children present, preserved verbatim for forward
    /// compatibility with non-CENC DRM schemes that nest their own
    /// boxes here.
    public let unknownChildren: [ISOBoxOpaque]

    public init(
        trackEncryption: TrackEncryptionBox? = nil,
        unknownChildren: [ISOBoxOpaque] = []
    ) {
        self.trackEncryption = trackEncryption
        self.unknownChildren = unknownChildren
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SchemeInformationBox {
        let bodySize = Int(header.size) - header.headerSize
        let bodyData = try reader.readData(count: bodySize)
        var bodyReader = BinaryReader(bodyData)
        var trackEncryption: TrackEncryptionBox?
        var unknownChildren: [ISOBoxOpaque] = []
        let isoBoxReader = ISOBoxReader()
        while bodyReader.remaining >= 8 {
            var peek = bodyReader
            let childHeader = try isoBoxReader.parseBoxHeader(&peek)
            switch childHeader.type {
            case TrackEncryptionBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&bodyReader)
                trackEncryption = try await TrackEncryptionBox.parse(
                    reader: &bodyReader, header: childHeader, registry: registry
                )
            default:
                unknownChildren.append(try ISOBoxOpaque.parse(reader: &bodyReader))
            }
        }
        return SchemeInformationBox(
            trackEncryption: trackEncryption,
            unknownChildren: unknownChildren
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            trackEncryption?.encode(to: &body)
            for child in unknownChildren {
                child.writeRaw(to: &body)
            }
        }
    }
}
