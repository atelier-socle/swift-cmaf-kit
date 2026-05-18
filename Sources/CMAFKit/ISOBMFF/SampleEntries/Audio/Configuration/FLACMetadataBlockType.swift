// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FLACMetadataBlockType
//
// Reference: Xiph FLAC format specification, METADATA_BLOCK_HEADER
// `BLOCK_TYPE` field (7 bits).

import Foundation

/// FLAC metadata block type per the FLAC format specification.
public enum FLACMetadataBlockType: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case streamInfo = 0
    case padding = 1
    case application = 2
    case seekTable = 3
    case vorbisComment = 4
    case cueSheet = 5
    case picture = 6
}
