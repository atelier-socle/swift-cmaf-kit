// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ClosedCaptionData and component types
//
// Reference: ATSC A/72 Part 3 (cea_708 user_data_registered SEI
// payload), CTA-608-E (CEA-608 byte pairs), CTA-708-E §6.2 (DTVCC
// caption channel packet) and SCTE-128 §8 (carriage of CEA-608 /
// CEA-708 via SEI).
//
// CMAFKit ships in-band caption typing: when an AVC or HEVC SEI
// `user_data_registered_itu_t_t35` message carries the recognised
// ATSC A/72 signature, the payload bytes are upgraded to the typed
// enum below for downstream consumers (HLS, DASH manifest
// generators, accessibility pipelines).

import Foundation

/// CEA-608 field identifier per ATSC A/72 Part 3 §6.2.
public enum CEA608Field: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case field1 = 0
    case field2 = 1
}

/// One CEA-608 byte pair carried in a `cea_708` user_data SEI.
public struct CEA608ByteData: Sendable, Hashable, Equatable, Codable {
    /// Which NTSC field the byte pair belongs to.
    public let field: CEA608Field
    public let byte1: UInt8
    public let byte2: UInt8
    /// `cc_valid` flag per ATSC A/72 Part 3 §6.2.
    public let validFlag: Bool

    public init(field: CEA608Field, byte1: UInt8, byte2: UInt8, validFlag: Bool) {
        self.field = field
        self.byte1 = byte1
        self.byte2 = byte2
        self.validFlag = validFlag
    }
}

/// One DTVCC caption channel packet per CTA-708-E §6.2.
public struct DTVCCPacket: Sendable, Hashable, Equatable, Codable {
    /// 2-bit sequence number (0..3).
    public let sequenceNumber: UInt8
    /// 6-bit `packet_size_code` field.
    public let packetSizeCode: UInt8
    public let services: [DTVCCServiceBlock]

    public init(
        sequenceNumber: UInt8,
        packetSizeCode: UInt8,
        services: [DTVCCServiceBlock]
    ) {
        precondition(sequenceNumber <= 3, "sequenceNumber must fit in 2 bits")
        precondition(packetSizeCode <= 0x3F, "packetSizeCode must fit in 6 bits")
        self.sequenceNumber = sequenceNumber
        self.packetSizeCode = packetSizeCode
        self.services = services
    }
}

/// One DTVCC service block per CTA-708-E §6.2.2.
public struct DTVCCServiceBlock: Sendable, Hashable, Equatable, Codable {
    public let serviceNumber: CCService
    public let blockSize: UInt8
    public let serviceData: Data

    public init(serviceNumber: CCService, blockSize: UInt8, serviceData: Data) {
        self.serviceNumber = serviceNumber
        self.blockSize = blockSize
        self.serviceData = serviceData
    }
}

/// Typed closed caption payload extracted from an SEI message.
public enum ClosedCaptionData: Sendable, Hashable, Equatable {
    case cea608(bytes: [CEA608ByteData])
    case cea708(packet: DTVCCPacket)
}
