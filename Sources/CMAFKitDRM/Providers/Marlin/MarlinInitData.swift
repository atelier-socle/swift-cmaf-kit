// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MarlinInitData (S12a stub)
//
// Reference: Marlin Developer Community public specifications.
// CMAFKitDRM S12a ships the placeholder shape; the typed parser
// lands in S12b.

import Foundation

/// Typed Marlin init data payload — S12a placeholder.
public struct MarlinInitData: Sendable, Equatable, Hashable {
    public let rawBytes: Data

    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }
}
