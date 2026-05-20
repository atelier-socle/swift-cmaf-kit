// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SEI message types
//
// Reference: ITU-T H.264 §7.3.2.3 (SEI RBSP) and ITU-T H.265
// §7.3.2.4 (Prefix / suffix SEI RBSP). One SEI NAL unit carries
// zero or more SEI messages; each message has a `payloadType`,
// a `payloadSize`, and a payload byte run.
//
// CMAFKit Session 8 introduced NAL unit type helpers. Session 11
// completes the SEI surface with the message-level value type
// plus the typed closed-caption upgrade for the registered ATSC
// A/72 user_data payload.

import Foundation

/// One SEI message extracted from an AVC SEI RBSP.
public struct AVCSEIMessage: Sendable, Hashable, Equatable, Codable {
    /// `payload_type` field as defined by ITU-T H.264 Annex D.
    public let payloadType: UInt32
    /// `payload_size` in bytes.
    public let payloadSize: UInt32
    /// Raw payload bytes. Length equals `payloadSize`.
    public let payload: Data

    public init(payloadType: UInt32, payloadSize: UInt32, payload: Data) {
        self.payloadType = payloadType
        self.payloadSize = payloadSize
        self.payload = payload
    }
}

/// One SEI message extracted from an HEVC SEI RBSP.
public struct HEVCSEIMessage: Sendable, Hashable, Equatable, Codable {
    public let payloadType: UInt32
    public let payloadSize: UInt32
    public let payload: Data

    public init(payloadType: UInt32, payloadSize: UInt32, payload: Data) {
        self.payloadType = payloadType
        self.payloadSize = payloadSize
        self.payload = payload
    }
}

/// Tagged union of AVC / HEVC SEI messages, used by
/// ``ClosedCaptionExtractor`` so consumers can feed mixed streams.
public enum SEIMessage: Sendable, Hashable, Equatable {
    case avc(AVCSEIMessage)
    case hevc(HEVCSEIMessage)

    /// The unified payload bytes.
    public var payload: Data {
        switch self {
        case .avc(let m): return m.payload
        case .hevc(let m): return m.payload
        }
    }

    /// The unified payload type.
    public var payloadType: UInt32 {
        switch self {
        case .avc(let m): return m.payloadType
        case .hevc(let m): return m.payloadType
        }
    }
}
