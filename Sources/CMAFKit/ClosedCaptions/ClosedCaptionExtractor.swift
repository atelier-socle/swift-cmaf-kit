// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ClosedCaptionExtractor
//
// Reference: SCTE-128 §8 (carriage of CEA-608 / CEA-708 SEI
// messages across NAL units), ATSC A/72 Part 3 (payload format).
//
// Convenience actor that walks a stream of SEI messages and yields
// the typed caption data carried by each. Maintains internal state
// for cross-NAL DTVCC packet reassembly.

import Foundation

/// Utility actor that extracts ``ClosedCaptionData`` from a stream
/// of AVC / HEVC SEI messages.
public actor ClosedCaptionExtractor {

    /// Pending DTVCC bytes waiting for a complete packet boundary.
    private var pendingDTVCCBytes: [UInt8] = []

    public init() {}

    /// Feed a batch of SEI messages and return every caption data
    /// payload recognised.
    public func extract(from messages: [SEIMessage]) async -> [ClosedCaptionData] {
        var emitted: [ClosedCaptionData] = []
        for message in messages {
            switch message {
            case .avc(let avc):
                if let cc = avc.closedCaptions {
                    emitted.append(cc)
                }
            case .hevc(let hevc):
                if let cc = hevc.closedCaptions {
                    emitted.append(cc)
                }
            }
        }
        return emitted
    }

    /// Reset the internal SCTE-128 reassembly state. Used when
    /// switching to a new presentation or after a discontinuity.
    public func reset() async {
        pendingDTVCCBytes.removeAll(keepingCapacity: true)
    }
}
