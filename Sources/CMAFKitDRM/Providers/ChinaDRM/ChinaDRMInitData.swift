// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ChinaDRMInitData (S12a stub)
//
// Reference: ChinaDRM public integration documentation. CMAFKitDRM
// S12a ships the placeholder shape; the typed parser lands in
// S12b.

import Foundation

/// Typed ChinaDRM init data payload — S12a placeholder.
public struct ChinaDRMInitData: Sendable, Equatable, Hashable {
    public let rawBytes: Data

    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }
}
