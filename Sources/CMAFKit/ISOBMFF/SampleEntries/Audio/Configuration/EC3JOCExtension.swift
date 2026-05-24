// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EC3JOCExtension
//
// Reference: ETSI TS 102 366 V1.4.1 Annex H — JOC (Joint Object
// Coding) syntax (H.2) and complexity-index semantics (H.3).
//
// E-AC-3 streams may carry a Dolby Atmos bed-and-objects presentation
// through a JOC extension in the dependent substreams. The presence
// and shape of this extension is signalled by the `ec3_extension_type_a`
// byte in the `dec3` (EC3SpecificBox) sample entry trailer per
// Annex F.6 + H.2.
//
// The RFC 6381 codec string remains `"ec-3"` even for JOC streams —
// JOC is signalled OUT-OF-STREAM via HLS `CHANNELS="16/JOC"`
// attribute (Apple HLS Authoring §2.2.4) or DASH
// `<SupplementalProperty>` (DASH-IF Implementation Guidelines v5.0+
// §6.3.4). This enum carries the bitstream-level JOC information for
// downstream consumers (HLSKit / DASHKit).

import Foundation

/// E-AC-3 JOC (Joint Object Coding) extension form per ETSI TS 102 366
/// Annex H.
///
/// Models the four JOC modes plus a forward-compatibility escape
/// hatch. The complexity index per Annex H.3 ranges 0..31; 16 is the
/// canonical Apple value reflected in the HLS `CHANNELS="16/JOC"`
/// attribute (Apple HLS Authoring §2.2.4).
///
/// References:
/// - ETSI TS 102 366 V1.4.1 Annex F.6 — `ec3_extension_type_a` byte
/// - ETSI TS 102 366 V1.4.1 Annex H.2 — JOC syntax
/// - ETSI TS 102 366 V1.4.1 Annex H.3 — `joc_complexity_index` semantics
/// - DASH-IF Implementation Guidelines v5.0+ §6.3.4 — Dolby Atmos DASH
/// - Apple HLS Authoring Specification §2.2.4 — Atmos / EC-3 with JOC
public enum EC3JOCExtension: Sendable, Equatable, Hashable {

    /// No JOC extension — base E-AC-3 stream (5.1, 7.1, etc.) without
    /// Atmos.
    case none

    /// Object-based JOC — the JOC extension carries only object-encoded
    /// data with no channel-based bed. Rare in practice; most Atmos
    /// deliveries are ``bedAndObjects``.
    ///
    /// `complexityIndex` per Annex H.3 indicates the maximum number of
    /// objects (typically 0-15 for streaming-grade configurations).
    case objectBased(complexityIndex: UInt8)

    /// Channel-based JOC — the JOC extension extends a channel-bed via
    /// parametric object coding. Used by some pre-Atmos streaming
    /// encoders.
    case channelBased(complexityIndex: UInt8)

    /// **Bed-and-objects** JOC — the canonical Dolby Atmos
    /// configuration: a channel-bed (typically 5.1 or 7.1) plus
    /// dynamic objects. The configuration consumer streaming services
    /// use (Netflix Atmos, Apple Music Spatial Audio with head
    /// tracking, etc.).
    ///
    /// `complexityIndex` per Annex H.3 — 16 is the canonical Apple HLS
    /// value reflected in `CHANNELS="16/JOC"`.
    case bedAndObjects(complexityIndex: UInt8)

    /// Programmatic / future extension form preserved as opaque raw
    /// bytes for forward compatibility with extensions defined in
    /// future Annex H updates.
    case programmaticExtension(rawBytes: Data)

    /// Whether this extension represents an Atmos / JOC delivery.
    /// `true` for every case except ``none``.
    public var isPresent: Bool {
        if case .none = self { return false }
        return true
    }

    /// The Annex H.3 `joc_complexity_index`, or `nil` for ``none`` /
    /// ``programmaticExtension`` (where complexity is encoded inside
    /// the raw bytes).
    public var complexityIndex: UInt8? {
        switch self {
        case .none, .programmaticExtension: return nil
        case .objectBased(let value),
            .channelBased(let value),
            .bedAndObjects(let value):
            return value
        }
    }
}
