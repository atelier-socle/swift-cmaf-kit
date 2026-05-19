// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFProfile
//
// Reference: ISO/IEC 23000-19 §6 (CMAF Media Profiles and brand
// signalling). The standard defines a family of brands carried in
// `ftyp` / `styp` to signal which CMAF profile a file claims to
// conform to. CMAFKit projects them into a typed enum so consumers
// drive brand emission by profile selection rather than free-form
// FourCC strings.

import Foundation

/// CMAF profile selection per ISO/IEC 23000-19 §6.
///
/// Each case selects the major brand emitted in `ftyp`/`styp` plus
/// the compatible-brands list the writer attaches.
public enum CMAFProfile: Sendable, Hashable, Equatable, Codable, CaseIterable {
    /// Basic CMAF (major brand `cmfc`) per ISO/IEC 23000-19 §6.4.
    /// Suitable for VOD interoperability.
    case basic
    /// Multi-stream CMAF (major brand `cmf2`) per ISO/IEC 23000-19 §6.5.
    case multiStream
    /// Fragmented CMAF (major brand `cmff`) per ISO/IEC 23000-19 §6.6.
    case fragmented
    /// Low-latency CMAF (major brand `cmfl`) per ISO/IEC 23000-19
    /// §6.7. Used in conjunction with chunked encoding for LL-HLS
    /// (IETF RFC 8216bis) and DASH-IF low-latency profiles.
    case lowLatency
    /// Segmented CMAF (major brand `cmfs`) per ISO/IEC 23000-19 §6.8.
    case segmented
    /// CMAF for DASH (major brand `cmfd`). Adds DASH-IF specific
    /// signalling expectations such as mandatory `sidx`.
    case dash
    /// CMAF for HLS (major brand `cmfh`). Aligns brand selection with
    /// HLS-specific consumer expectations.
    case hls

    /// The major brand emitted in `ftyp` and `styp` for this profile.
    public var majorBrand: FourCC {
        switch self {
        case .basic: return "cmfc"
        case .multiStream: return "cmf2"
        case .fragmented: return "cmff"
        case .lowLatency: return "cmfl"
        case .segmented: return "cmfs"
        case .dash: return "cmfd"
        case .hls: return "cmfh"
        }
    }

    /// The compatible-brands list emitted in `ftyp` for this profile.
    ///
    /// Every CMAF file ships with `iso6` (ISO/IEC 14496-12 sixth-edition
    /// compatibility) plus a profile-specific set. `cmfc` is always
    /// included in addition to the major brand because every CMAF
    /// profile is a refinement of basic CMAF.
    public var compatibleBrands: [FourCC] {
        var brands: [FourCC] = ["iso6", "cmfc"]
        switch self {
        case .basic:
            break
        case .multiStream:
            brands.append("cmf2")
        case .fragmented:
            brands.append("cmff")
        case .lowLatency:
            brands.append("cmfl")
        case .segmented:
            brands.append("cmfs")
        case .dash:
            brands.append("cmfd")
            brands.append("dash")
            brands.append("msdh")
        case .hls:
            brands.append("cmfh")
        }
        return brands
    }
}
