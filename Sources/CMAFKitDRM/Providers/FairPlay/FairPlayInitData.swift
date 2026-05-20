// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FairPlayInitData (S12a stub)
//
// Reference: Apple FairPlay Streaming Programming Guide. CMAFKitDRM
// S12a ships the placeholder shape; the FairPlay binary init-data
// parser lands in S12b.

import Foundation

/// Typed FairPlay Streaming init data payload — S12a placeholder.
public struct FairPlayInitData: Sendable, Equatable, Hashable {
    public let rawBytes: Data

    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }
}
