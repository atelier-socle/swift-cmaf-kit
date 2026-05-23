// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TypedDRMInitData
//
// Reference: ISO/IEC 23001-7 §8.1.1 (pssh.data is opaque to the
// container; the protection scheme defines its layout).
//
// Tagged union surfaced by
// ``ProtectionSystemSpecificHeaderBox/typedInitData()``. Each
// named arm carries the provider-specific typed init data shape;
// the ``unknown(systemID:rawBytes:)`` arm preserves the raw bytes
// for system identifiers CMAFKitDRM does not yet recognise.

import CMAFKit
import Foundation

/// Typed initialisation-data payload extracted from a `pssh` box.
public enum TypedDRMInitData: Sendable, Equatable, Hashable {
    case widevine(WidevineInitData)
    case playReady(PlayReadyInitData)
    case fairPlay(FairPlayInitData)
    case clearKey(ClearKeyInitData)
    case marlin(MarlinInitData)
    case nagra(NagraInitData)
    case verimatrix(VerimatrixInitData)
    case adobePrimetime(AdobePrimetimeInitData)
    case chinaDRM(ChinaDRMInitData)
    /// Unrecognised DRM system. The original `pssh.systemID` and
    /// `pssh.data` are preserved verbatim so the caller can route
    /// or round-trip the box without losing fidelity.
    case unknown(systemID: UUID, rawBytes: Data)

    /// The system identifier this payload was associated with on
    /// the wire.
    public var systemID: UUID {
        switch self {
        case .widevine: return KnownDRMSystemID.widevine.uuid
        case .playReady: return KnownDRMSystemID.playReady.uuid
        case .fairPlay: return KnownDRMSystemID.fairPlay.uuid
        case .clearKey: return KnownDRMSystemID.clearKey.uuid
        case .marlin: return KnownDRMSystemID.marlin.uuid
        case .nagra: return KnownDRMSystemID.nagra.uuid
        case .verimatrix: return KnownDRMSystemID.verimatrix.uuid
        case .adobePrimetime: return KnownDRMSystemID.adobePrimetime.uuid
        case .chinaDRM: return KnownDRMSystemID.chinaDRM.uuid
        case .unknown(let systemID, _): return systemID
        }
    }

    /// Re-encode this typed payload back to the opaque pssh.data
    /// bytes. The result round-trips byte-perfectly with the
    /// canonical encoder for every fully-typed provider; for the
    /// opaque-preserved providers (Nagra, Verimatrix, Adobe
    /// Primetime) the original bytes are returned verbatim.
    public func encoded() throws -> Data {
        switch self {
        case .widevine(let value):
            return try WidevineInitData.encode(value)
        case .playReady(let value):
            return try PlayReadyInitData.encode(value)
        case .fairPlay(let value):
            return try FairPlayInitData.encode(value)
        case .clearKey(let value):
            return try ClearKeyInitData.encode(value)
        case .marlin(let value):
            return try MarlinInitData.encode(value)
        case .nagra(let value):
            return try NagraInitData.encode(value)
        case .verimatrix(let value):
            return try VerimatrixInitData.encode(value)
        case .adobePrimetime(let value):
            return try AdobePrimetimeInitData.encode(value)
        case .chinaDRM(let value):
            return try ChinaDRMInitData.encode(value)
        case .unknown(_, let bytes):
            return bytes
        }
    }
}
