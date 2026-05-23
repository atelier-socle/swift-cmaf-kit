// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - NagraInitData
//
// Reference: DASH-IF "DRM System Identifiers" registry; Nagra
// Connect DRM integration documentation status as of 2026-05.
//
// **Closed-spec provider**: Nagra has not published a public
// wire-format specification for the pssh.data carried under the
// system identifier `adb41c24-2dbf-4a6d-958b-4457c0d27b95`. The
// Nagra Connect DRM internal format is distributed only under NDA
// to certified Nagra licensees.
//
// This type therefore preserves the raw bytes verbatim so the
// container layer of CMAFKitDRM round-trips byte-perfectly without
// corrupting the operator's protected payload. Typed field-level
// decoding is intentionally not attempted because no public
// specification exists to validate against.
//
// If Nagra publishes a public specification in a future release,
// this type can be extended with typed accessors without breaking
// source compatibility — ``rawBytes`` remains the canonical wire
// representation.

import Foundation

/// Typed wrapper for Nagra Connect DRM init data (closed-spec).
public struct NagraInitData: Sendable, Hashable, Equatable, Codable {
    /// The pssh.data bytes preserved verbatim.
    public let rawBytes: Data

    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }

    public static func parse(_ data: Data) throws -> NagraInitData {
        NagraInitData(rawBytes: data)
    }

    public static func encode(_ value: NagraInitData) throws -> Data {
        value.rawBytes
    }
}

extension NagraInitData: DRMInitDataParsing {
    public static var systemID: KnownDRMSystemID { .nagra }
    public typealias TypedInitData = NagraInitData
}
