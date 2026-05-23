// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - VerimatrixInitData
//
// Reference: DASH-IF "DRM System Identifiers" registry; Verimatrix
// Multi-DRM / VCAS integration documentation status as of 2026-05.
//
// **Closed-spec provider**: Verimatrix has not published a public
// wire-format specification for the pssh.data carried under the
// system identifier `9a27dd82-fde2-4725-8cbc-4234aa06ec09` beyond
// the DASH-IF system-ID registration. The Multi-DRM / VCAS internal
// format is proprietary and distributed under commercial agreement.
//
// This type therefore preserves the raw bytes verbatim so the
// container layer of CMAFKitDRM round-trips byte-perfectly without
// corrupting the operator's protected payload. Typed field-level
// decoding is intentionally not attempted because no public
// specification exists to validate against.
//
// If Verimatrix publishes a public specification in a future
// release, this type can be extended with typed accessors without
// breaking source compatibility.

import Foundation

/// Typed wrapper for Verimatrix Multi-DRM init data (closed-spec).
public struct VerimatrixInitData: Sendable, Hashable, Equatable, Codable {
    /// The pssh.data bytes preserved verbatim.
    public let rawBytes: Data

    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }

    public static func parse(_ data: Data) throws -> VerimatrixInitData {
        VerimatrixInitData(rawBytes: data)
    }

    public static func encode(_ value: VerimatrixInitData) throws -> Data {
        value.rawBytes
    }
}

extension VerimatrixInitData: DRMInitDataParsing {
    public static var systemID: KnownDRMSystemID { .verimatrix }
    public typealias TypedInitData = VerimatrixInitData
}
