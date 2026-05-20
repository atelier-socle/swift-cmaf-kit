// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ClearKeyInitData (S12a stub)
//
// Reference: W3C Encrypted Media Extensions, ClearKey scheme JSON
// init data format (https://www.w3.org/TR/encrypted-media/).
// CMAFKitDRM S12a ships the placeholder shape; the JSON parser
// lands in S12b.

import Foundation

/// Typed W3C ClearKey init data payload — S12a placeholder.
public struct ClearKeyInitData: Sendable, Equatable, Hashable {
    public let rawBytes: Data

    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }
}
