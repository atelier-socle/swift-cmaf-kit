// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AudioChannelLayout
//
// Reference: ISO/IEC 23001-8 §8 (channel layout / CICP).

import Foundation

/// Audio channel layout per ISO/IEC 23001-8 §8.
public struct AudioChannelLayout: Sendable, Hashable {
    /// Number of channels.
    public let channelCount: UInt32

    /// ISO/IEC 23001-8 channel position mask.
    public let mask: UInt32

    /// Logical channel labels, in stream order.
    public let description: [AudioChannel]

    public init(channelCount: UInt32, mask: UInt32, description: [AudioChannel] = []) {
        self.channelCount = channelCount
        self.mask = mask
        self.description = description
    }

    /// Mono.
    public static let mono = AudioChannelLayout(
        channelCount: 1,
        mask: 0x4,  // FC
        description: [.frontCenter]
    )

    /// Stereo (L, R).
    public static let stereo = AudioChannelLayout(
        channelCount: 2,
        mask: 0x3,  // FL | FR
        description: [.frontLeft, .frontRight]
    )

    /// 5.1 surround (FL, FR, FC, LFE, BL, BR).
    public static let surround5_1 = AudioChannelLayout(
        channelCount: 6,
        mask: 0x3F,
        description: [.frontLeft, .frontRight, .frontCenter, .lfe, .backLeft, .backRight]
    )

    /// 7.1 surround (FL, FR, FC, LFE, BL, BR, SL, SR).
    public static let surround7_1 = AudioChannelLayout(
        channelCount: 8,
        mask: 0xFF,
        description: [.frontLeft, .frontRight, .frontCenter, .lfe, .backLeft, .backRight, .sideLeft, .sideRight]
    )

    /// Atmos 7.1.4 (7.1 + 4 height channels).
    public static let atmos7_1_4 = AudioChannelLayout(
        channelCount: 12,
        mask: 0xFFF,
        description: [
            .frontLeft, .frontRight, .frontCenter, .lfe,
            .backLeft, .backRight, .sideLeft, .sideRight,
            .topFrontLeft, .topFrontRight, .topBackLeft, .topBackRight
        ]
    )
}
