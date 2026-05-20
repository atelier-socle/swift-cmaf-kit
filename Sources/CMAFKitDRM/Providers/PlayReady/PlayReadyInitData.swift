// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - PlayReadyInitData (S12a stub)
//
// Reference: Microsoft PlayReady Header Object specification (public
// `mspr:pro` / WRMHEADER XML format). CMAFKitDRM S12a ships the
// placeholder shape; the WRMHEADER XML parser lands in S12b.

import Foundation

/// Typed PlayReady Header Object payload — S12a placeholder.
///
/// Carries the raw pssh.data bytes verbatim until the WRMHEADER
/// XML parser lands in S12b.
public struct PlayReadyInitData: Sendable, Equatable, Hashable {
    public let rawBytes: Data

    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }
}
