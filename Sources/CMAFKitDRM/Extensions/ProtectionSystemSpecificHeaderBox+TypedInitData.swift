// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProtectionSystemSpecificHeaderBox + TypedDRMInitData
//
// Reference: ISO/IEC 23001-7 §8.1.1 (pssh box; data is opaque and
// scheme-defined).
//
// Bridges the typed CMAFKit `pssh` value into the typed
// CMAFKitDRM init-data union. Each named arm dispatches to the
// per-provider typed parser; unrecognised system identifiers
// surface as ``TypedDRMInitData/unknown(systemID:rawBytes:)`` and
// preserve the raw bytes verbatim.
//
// Callers that want graceful degradation when a recognised
// provider's parser throws can catch the error and fall back to
// ``TypedDRMInitData/unknown(systemID:rawBytes:)`` themselves —
// the library never silently swallows parse errors.

import CMAFKit
import Foundation

extension ProtectionSystemSpecificHeaderBox {
    /// Dispatch the opaque `pssh.data` field to the matching typed
    /// DRM provider init-data arm.
    ///
    /// - Throws: ``DRMSystemError`` propagated from the matching
    ///   provider parser when `pssh.data` is malformed for that
    ///   provider.
    /// - Returns: ``TypedDRMInitData/unknown(systemID:rawBytes:)``
    ///   when the `pssh.systemID` is not a registered Common
    ///   Encryption DRM system identifier.
    public func typedInitData() throws -> TypedDRMInitData {
        let known = KnownDRMSystemID(uuid: self.systemID)
        switch known {
        case .widevine:
            return .widevine(try WidevineInitData.parse(self.data))
        case .playReady:
            return .playReady(try PlayReadyInitData.parse(self.data))
        case .fairPlay:
            return .fairPlay(try FairPlayInitData.parse(self.data))
        case .clearKey:
            return .clearKey(try ClearKeyInitData.parse(self.data))
        case .marlin:
            return .marlin(try MarlinInitData.parse(self.data))
        case .nagra:
            return .nagra(try NagraInitData.parse(self.data))
        case .verimatrix:
            return .verimatrix(try VerimatrixInitData.parse(self.data))
        case .adobePrimetime:
            return .adobePrimetime(try AdobePrimetimeInitData.parse(self.data))
        case .chinaDRM:
            return .chinaDRM(try ChinaDRMInitData.parse(self.data))
        case .other(let uuid):
            return .unknown(systemID: uuid, rawBytes: self.data)
        }
    }
}
