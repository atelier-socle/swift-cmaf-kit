// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProtectionSystemSpecificHeaderBox + TypedDRMInitData
//
// Reference: ISO/IEC 23001-7 §8.1.1 (pssh box; data is opaque and
// scheme-defined).
//
// Bridges the typed CMAFKit `pssh` value into the typed
// CMAFKitDRM init-data union. S12a wraps every recognised system
// identifier in the matching named arm carrying the raw bytes;
// the typed parsers replace those stubs in S12b.

import CMAFKit
import Foundation

extension ProtectionSystemSpecificHeaderBox {
    /// Dispatch the opaque `pssh.data` field to the matching typed
    /// DRM provider init-data arm.
    ///
    /// Returns ``TypedDRMInitData/unknown(systemID:rawBytes:)`` for
    /// system identifiers not yet recognised by
    /// ``KnownDRMSystemID``. For the 9 registered systems the
    /// CMAFKitDRM 0.1.0 (S12a) bootstrap wraps the raw bytes
    /// verbatim; the per-provider typed parsers land in S12b.
    public func typedInitData() -> TypedDRMInitData {
        let known = KnownDRMSystemID(uuid: self.systemID)
        switch known {
        case .widevine:
            return .widevine(WidevineInitData(rawBytes: self.data))
        case .playReady:
            return .playReady(PlayReadyInitData(rawBytes: self.data))
        case .fairPlay:
            return .fairPlay(FairPlayInitData(rawBytes: self.data))
        case .clearKey:
            return .clearKey(ClearKeyInitData(rawBytes: self.data))
        case .marlin:
            return .marlin(MarlinInitData(rawBytes: self.data))
        case .nagra:
            return .nagra(NagraInitData(rawBytes: self.data))
        case .verimatrix:
            return .verimatrix(VerimatrixInitData(rawBytes: self.data))
        case .adobePrimetime:
            return .adobePrimetime(AdobePrimetimeInitData(rawBytes: self.data))
        case .chinaDRM:
            return .chinaDRM(ChinaDRMInitData(rawBytes: self.data))
        case .other(let uuid):
            return .unknown(systemID: uuid, rawBytes: self.data)
        }
    }
}
