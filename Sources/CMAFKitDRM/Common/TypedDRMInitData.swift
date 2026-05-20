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

    /// The raw pssh.data bytes underlying this payload. For S12a
    /// every typed arm wraps the raw bytes; S12b replaces those
    /// wrappers with structured shapes (and this accessor remains
    /// available for round-trip).
    public var rawBytes: Data {
        switch self {
        case .widevine(let data): return data.rawBytes
        case .playReady(let data): return data.rawBytes
        case .fairPlay(let data): return data.rawBytes
        case .clearKey(let data): return data.rawBytes
        case .marlin(let data): return data.rawBytes
        case .nagra(let data): return data.rawBytes
        case .verimatrix(let data): return data.rawBytes
        case .adobePrimetime(let data): return data.rawBytes
        case .chinaDRM(let data): return data.rawBytes
        case .unknown(_, let bytes): return bytes
        }
    }
}
