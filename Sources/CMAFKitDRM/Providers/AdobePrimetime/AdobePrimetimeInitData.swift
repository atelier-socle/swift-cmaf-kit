// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AdobePrimetimeInitData
//
// Reference: Adobe Primetime DRM public archived documentation;
// DASH-IF "DRM System Identifiers" registry.
//
// **Deprecated service**: Adobe discontinued the Primetime DRM
// service in 2020. The historical wire format carried under
// system identifier `f239e769-efa3-4850-9c16-a903c6932efb` is
// partially documented in Adobe's archived "Primetime DRM Format
// Specification" but the specification is no longer maintained
// and the service no longer operates.
//
// CMAFKitDRM preserves the raw bytes verbatim so legacy content
// using this system identifier still round-trips byte-perfectly
// through the container layer. Typed dispatch is informational
// only — the runtime never decrypts Primetime-protected content
// because the service is offline.

import Foundation

/// Typed wrapper for Adobe Primetime DRM init data (deprecated
/// service).
public struct AdobePrimetimeInitData: Sendable, Hashable, Equatable, Codable {
    /// The pssh.data bytes preserved verbatim.
    public let rawBytes: Data

    public init(rawBytes: Data) {
        self.rawBytes = rawBytes
    }

    public static func parse(_ data: Data) throws -> AdobePrimetimeInitData {
        AdobePrimetimeInitData(rawBytes: data)
    }

    public static func encode(_ value: AdobePrimetimeInitData) throws -> Data {
        value.rawBytes
    }
}

extension AdobePrimetimeInitData: DRMInitDataParsing {
    public static var systemID: KnownDRMSystemID { .adobePrimetime }
    public typealias TypedInitData = AdobePrimetimeInitData
}
