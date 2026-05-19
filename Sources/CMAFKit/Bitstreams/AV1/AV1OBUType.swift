// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AV1OBUType
//
// Reference: AOMedia AV1 Bitstream §5.3.2 + §6.2.1 (Table 6.2.1).

import Foundation

/// AV1 OBU type per AOMedia AV1 Bitstream §6.2.1.
public enum AV1OBUType: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case reserved0 = 0
    case sequenceHeader = 1
    case temporalDelimiter = 2
    case frameHeader = 3
    case tileGroup = 4
    case metadata = 5
    case frame = 6
    case redundantFrameHeader = 7
    case tileList = 8
    case padding = 15
}
