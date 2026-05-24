// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AccessibilityMetadata
//
// The central aggregate that attaches the cross-format neutral
// accessibility primitives to a CMAF track. HLSKit serialises this to
// `EXT-X-MEDIA` attributes; DASHKit serialises this to MPD `<Role>` +
// `<Accessibility>` descriptors. CMAFKit ships the truth; the
// manifest libraries ship the wire format.
//
// References:
// - Apple HLS Authoring Specification §4.6 — `EXT-X-MEDIA` attributes
// - ISO/IEC 23009-1 §5.8.4.2-§5.8.4.3 — DASH Role + Accessibility
//   descriptors
// - DASH-IF Implementation Guidelines v5.0+ §6.6
// - DVB-DASH (ETSI TS 103 285) §5.2 — Audio purpose signalling
// - ETSI EN 301 549 §7.1 — EU accessibility ICT
// - EU Directive 2019/882 — European Accessibility Act (28 June 2025)
// - W3C Media Accessibility User Requirements
// - FCC §79.4 + CTA-2065 (US closed captioning)

import Foundation

/// Accessibility metadata attached to a CMAF track configuration.
///
/// Aggregates the cross-format neutral accessibility primitives —
/// role, features, characteristics, audio purpose — plus HLS-specific
/// flags (forced / autoselect / default) and language associations
/// (associatedLanguage / signLanguage). The struct carries the
/// **complete semantic** so HLSKit and DASHKit each emit correct
/// wire format from a single source of truth.
///
/// References:
/// - Apple HLS Authoring §4.6 — `EXT-X-MEDIA` accessibility attributes
/// - ISO/IEC 23009-1 §5.8.4.2-§5.8.4.3 — DASH Role + Accessibility
/// - DASH-IF Implementation Guidelines v5.0+ §6.6
/// - DVB-DASH (ETSI TS 103 285) §5.2
/// - ETSI EN 301 549 §7.1 — EU accessibility ICT
/// - EU Directive 2019/882 — European Accessibility Act
/// - W3C Media Accessibility User Requirements
public struct AccessibilityMetadata: Sendable, Equatable, Hashable, Codable {

    // MARK: Cross-format neutral primitives

    /// Role of this track within the presentation. `nil` when no
    /// special role applies.
    public let role: MediaSelectionRole?

    /// Custom DASH Role scheme `value` when ``role`` is
    /// ``MediaSelectionRole/custom``. Ignored when ``role`` is a
    /// typed case.
    public let customRoleValue: String?

    /// Accessibility features provided by this track. Multiple
    /// features may be present (a sign-language interpretation track
    /// that also carries subtitles).
    public let features: Set<AccessibilityFeature>

    /// Apple HLS CHARACTERISTICS URIs explicitly attached to this
    /// track. Implicit URIs from ``role`` and ``features`` are
    /// merged in by ``allHLSCharacteristicURIs``.
    public let characteristics: Set<AccessibilityCharacteristic>

    /// DVB TVA AudioPurpose code (audio tracks only).
    public let audioPurpose: AudioPurpose?

    // MARK: HLS-specific flags

    /// HLS `FORCED=YES` per Apple HLS Authoring §4.6.3 — track is
    /// selected automatically when subtitles are forced.
    public let isForced: Bool

    /// HLS `AUTOSELECT=YES` per Apple HLS Authoring §4.6.2 — track is
    /// selected based on system preferences (language +
    /// accessibility settings).
    public let isAutoSelect: Bool

    /// HLS `DEFAULT=YES` per Apple HLS Authoring §4.6.4 — default
    /// track of its `TYPE` + `GROUP-ID`.
    public let isDefault: Bool

    // MARK: Language associations

    /// HLS `ASSOC-LANGUAGE` per Apple HLS Authoring §4.7 / DASH
    /// `@lang`. Secondary language association distinct from the
    /// parent track's primary language (e.g., an English commentary
    /// track associated with a Japanese film).
    public let associatedLanguage: BCP47LanguageTag?

    /// Sign language of a sign-interpretation track — typically a
    /// regional sign-language BCP 47 tag (`ase` American Sign
    /// Language, `bfi` British Sign Language, `fsl` Langue des Signes
    /// Française, `gsg` Deutsche Gebärdensprache).
    public let signLanguage: BCP47LanguageTag?

    public init(
        role: MediaSelectionRole? = nil,
        customRoleValue: String? = nil,
        features: Set<AccessibilityFeature> = [],
        characteristics: Set<AccessibilityCharacteristic> = [],
        audioPurpose: AudioPurpose? = nil,
        isForced: Bool = false,
        isAutoSelect: Bool = false,
        isDefault: Bool = false,
        associatedLanguage: BCP47LanguageTag? = nil,
        signLanguage: BCP47LanguageTag? = nil
    ) {
        self.role = role
        self.customRoleValue = customRoleValue
        self.features = features
        self.characteristics = characteristics
        self.audioPurpose = audioPurpose
        self.isForced = isForced
        self.isAutoSelect = isAutoSelect
        self.isDefault = isDefault
        self.associatedLanguage = associatedLanguage
        self.signLanguage = signLanguage
    }

    /// Convenience: empty metadata — all fields default. Equivalent
    /// to `AccessibilityMetadata()`.
    public static var empty: AccessibilityMetadata { AccessibilityMetadata() }
}

extension AccessibilityMetadata {

    /// Union of explicit ``characteristics`` and every URI implied by
    /// ``role`` and ``features`` per the cross-format mapping tables.
    /// Used by HLSKit to emit the `EXT-X-MEDIA CHARACTERISTICS`
    /// attribute.
    public var allHLSCharacteristicURIs: Set<String> {
        var result = Set(characteristics.map(\.uri))
        if let role {
            result.formUnion(role.hlsCharacteristicURIs)
        }
        for feature in features {
            result.formUnion(feature.hlsCharacteristicURIs)
        }
        return result
    }

    /// Canonical DASH `<Role value="...">` value: the typed scheme
    /// value when ``role`` is a recognised case, else
    /// ``customRoleValue`` for ``MediaSelectionRole/custom``, else
    /// `nil` for transcript (signalled via the DASH `Accessibility`
    /// descriptor) or absent role.
    public var canonicalDASHRoleValue: String? {
        guard let role else { return nil }
        if role == .custom { return customRoleValue }
        return role.dashRoleValue
    }

    /// True when this metadata signals at least one EU Accessibility
    /// Act-relevant feature. Used by HLSKit / DASHKit validators to
    /// detect compliance gaps in a manifest.
    ///
    /// References:
    /// - EU Directive 2019/882 §I — accessibility requirements for
    ///   audiovisual media services
    /// - ETSI EN 301 549 §7.1 — broadcast accessibility
    public var carriesEUAccessibilityActFeature: Bool {
        if features.contains(.audioDescription)
            || features.contains(.extendedAudioDescription)
            || features.contains(.closedCaptions)
            || features.contains(.signLanguageInterpretation)
        {
            return true
        }
        switch role {
        case .description, .sign, .captions:
            return true
        default:
            return false
        }
    }
}
