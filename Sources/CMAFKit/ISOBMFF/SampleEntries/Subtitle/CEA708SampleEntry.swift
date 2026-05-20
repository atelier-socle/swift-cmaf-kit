// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CEA708SampleEntry (c708)
//
// Reference: ISO/IEC 14496-30 §11.3 (CEA-708 caption sample
// entry).
//
// Carries one or more CEA-708 caption services as a dedicated
// track. Layout: VisualSampleEntry preamble + visual fields tail +
// 8-byte service-mask (1 bit per service 1..63 plus reserved
// bit) + optional `btrt` child.

import Foundation

/// CEA-708 caption sample entry (`c708`) per ISO/IEC 14496-30
/// §11.3.
public struct CEA708SampleEntry: SampleEntry, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "c708"

    public let visualFields: VisualSampleEntryFields
    /// CEA-708 services carried by this entry.
    public let services: [CCService]
    /// Optional bit rate hint.
    public let bitRate: BitRateBox?

    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }

    public init(
        visualFields: VisualSampleEntryFields = VisualSampleEntryFields(
            width: 0,
            height: 0
        ),
        services: [CCService],
        bitRate: BitRateBox? = nil
    ) {
        self.visualFields = visualFields
        self.services = services
        self.bitRate = bitRate
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> CEA708SampleEntry {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        let high = try reader.readUInt32()
        let low = try reader.readUInt32()
        let mask: UInt64 = (UInt64(high) << 32) | UInt64(low)
        var services: [CCService] = []
        // bit `i` (1..63) signals service number `i`.
        for serviceNumber in 1...63 {
            let bit = UInt64(1) << serviceNumber
            if mask & bit != 0,
                let service = CCService.cea708Service(forWireNumber: UInt8(serviceNumber))
            {
                services.append(service)
            }
        }

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
        return CEA708SampleEntry(
            visualFields: fields,
            services: services,
            bitRate: bitRate
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            visualFields.encode(to: &body)
            var mask: UInt64 = 0
            for service in services {
                let number = UInt64(service.wireNumber)
                guard number >= 1, number <= 63 else { continue }
                mask |= UInt64(1) << number
            }
            body.writeUInt32(UInt32(truncatingIfNeeded: mask >> 32))
            body.writeUInt32(UInt32(truncatingIfNeeded: mask & 0xFFFF_FFFF))
            bitRate?.encode(to: &body)
        }
    }
}
