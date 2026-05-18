// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - OpusChannelMappingFamily
//
// Reference: IETF "Encapsulation of Opus in ISO Base Media File Format"
// v1.0.0 §4.3.2.

import Foundation

/// Opus channel mapping family per IETF Opus-in-ISOBMFF §4.3.2.
public enum OpusChannelMappingFamily: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// RTP mapping: mono or stereo, with no channel mapping table.
    case rtpMonoStereo = 0
    /// Vorbis-style multichannel mapping with a channel mapping table.
    case vorbisMultichannel = 1
    /// Ambisonics mapping.
    case ambisonics = 2
    /// Undefined / proprietary mapping.
    case undefined = 255
}
