// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCProfileCompatibility
//
// Reference: ISO/IEC 14496-10 §A.2 (constraint flags) + ISO/IEC 14496-15
// §5.3.3.1.
//
// The 8 constraint flags packed into a single byte. The bit layout
// places `constraintSet0` at the most-significant bit (0x80) and so on.

import Foundation

/// AVC profile compatibility flags carried by
/// `AVCDecoderConfigurationRecord`.
///
/// Reference: ISO/IEC 14496-10 §A.2.
public struct AVCProfileCompatibility: Sendable, Hashable, Equatable, Codable {
    public let constraintSet0: Bool
    public let constraintSet1: Bool
    public let constraintSet2: Bool
    public let constraintSet3: Bool
    public let constraintSet4: Bool
    public let constraintSet5: Bool
    public let reserved6: Bool
    public let reserved7: Bool

    public init(
        constraintSet0: Bool = false,
        constraintSet1: Bool = false,
        constraintSet2: Bool = false,
        constraintSet3: Bool = false,
        constraintSet4: Bool = false,
        constraintSet5: Bool = false,
        reserved6: Bool = false,
        reserved7: Bool = false
    ) {
        self.constraintSet0 = constraintSet0
        self.constraintSet1 = constraintSet1
        self.constraintSet2 = constraintSet2
        self.constraintSet3 = constraintSet3
        self.constraintSet4 = constraintSet4
        self.constraintSet5 = constraintSet5
        self.reserved6 = reserved6
        self.reserved7 = reserved7
    }

    public init(rawValue: UInt8) {
        self.constraintSet0 = (rawValue & 0x80) != 0
        self.constraintSet1 = (rawValue & 0x40) != 0
        self.constraintSet2 = (rawValue & 0x20) != 0
        self.constraintSet3 = (rawValue & 0x10) != 0
        self.constraintSet4 = (rawValue & 0x08) != 0
        self.constraintSet5 = (rawValue & 0x04) != 0
        self.reserved6 = (rawValue & 0x02) != 0
        self.reserved7 = (rawValue & 0x01) != 0
    }

    public var rawValue: UInt8 {
        var byte: UInt8 = 0
        if constraintSet0 { byte |= 0x80 }
        if constraintSet1 { byte |= 0x40 }
        if constraintSet2 { byte |= 0x20 }
        if constraintSet3 { byte |= 0x10 }
        if constraintSet4 { byte |= 0x08 }
        if constraintSet5 { byte |= 0x04 }
        if reserved6 { byte |= 0x02 }
        if reserved7 { byte |= 0x01 }
        return byte
    }
}
