// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CEA608SampleEntry (c608)
//
// Reference: ISO/IEC 14496-30 §11.2 (CEA-608 caption sample entry).
//
// Carries one or more CEA-608 caption fields as a dedicated track.
// Layout: VisualSampleEntry preamble (8 bytes) + the standard
// 70-byte visual fields tail + a 2-byte field-mask describing
// which CEA-608 channels (cc1..cc4) the track carries, followed
// by the optional `btrt` (BitRateBox) child.

import Foundation

/// CEA-608 caption sample entry (`c608`) per ISO/IEC 14496-30 §11.2.
public struct CEA608SampleEntry: SampleEntry, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "c608"

    public let visualFields: VisualSampleEntryFields
    /// CEA-608 channels carried by this entry.
    public let channels: [CCService]
    /// Optional bit rate hint.
    public let bitRate: BitRateBox?

    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }

    public init(
        visualFields: VisualSampleEntryFields = VisualSampleEntryFields(
            width: 0,
            height: 0
        ),
        channels: [CCService],
        bitRate: BitRateBox? = nil
    ) {
        self.visualFields = visualFields
        self.channels = channels
        self.bitRate = bitRate
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> CEA608SampleEntry {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        let mask = try reader.readUInt16()
        var channels: [CCService] = []
        if mask & 0x0001 != 0 { channels.append(.cc1) }
        if mask & 0x0002 != 0 { channels.append(.cc2) }
        if mask & 0x0004 != 0 { channels.append(.cc3) }
        if mask & 0x0008 != 0 { channels.append(.cc4) }

        var bitRate: BitRateBox?
        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            let childHeader = try isoBoxReader.parseBoxHeader(&reader)
            switch childHeader.type {
            case BitRateBox.boxType:
                bitRate = try await BitRateBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            default:
                _ = try ISOBoxOpaque.parse(reader: &reader)
            }
        }
        return CEA608SampleEntry(
            visualFields: fields,
            channels: channels,
            bitRate: bitRate
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            visualFields.encode(to: &body)
            var mask: UInt16 = 0
            for channel in channels {
                switch channel {
                case .cc1: mask |= 0x0001
                case .cc2: mask |= 0x0002
                case .cc3: mask |= 0x0004
                case .cc4: mask |= 0x0008
                default: break
                }
            }
            body.writeUInt16(mask)
            bitRate?.encode(to: &body)
        }
    }
}
