// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - WidevineInitData (S12a stub)
//
// Reference: Google Widevine `CencHeader` Protocol Buffer message
// (public schema published by Google as part of the Widevine CDM
// integration documentation).
//
// CMAFKitDRM S12a ships the placeholder shape so the typed
// dispatch surface compiles; the protobuf parser lands in S12b.

import Foundation

/// Typed Widevine `CencHeader` payload — S12a placeholder.
///
/// Carries the raw pssh.data bytes verbatim until the protobuf
/// parser lands in S12b.
public struct WidevineInitData: Sendable, Equatable, Hashable {
    /// Raw pssh.data bytes preserved for round-trip and forward
    /// compatibility.
    public let rawBytes: Data

    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }
}
