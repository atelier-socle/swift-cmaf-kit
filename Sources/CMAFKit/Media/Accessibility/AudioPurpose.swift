// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AudioPurpose
//
// References:
// - DVB-DASH (ETSI TS 103 285) §5.2 — Accessibility signalling for
//   audio tracks via the TVA AudioPurpose classification scheme.
// - TVA Metadata CS `urn:tva:metadata:cs:AudioPurposeCS:2007` — code
//   list 0..7.
// - ISO/IEC 23009-1 §5.8.4.3 — DASH `Accessibility` descriptor
//   (carries the TVA scheme `value` attribute for audio tracks).
// - EBU Tech 3370 — broadcast audio description bindings.

import Foundation

/// DVB / TVA AudioPurpose code per
/// `urn:tva:metadata:cs:AudioPurposeCS:2007` (DVB-DASH §5.2 +
/// ETSI TS 103 285).
///
/// Used in DASH MPD `<Accessibility>` descriptors and DVB broadcast
/// metadata to identify the *purpose* of an audio track in
/// accessibility / multilingual contexts. The raw value is the
/// integer code that MUST appear in the `value=` attribute of a
/// `<Accessibility schemeIdUri="urn:tva:metadata:cs:AudioPurposeCS:2007">`
/// descriptor.
///
/// References:
/// - DVB-DASH (ETSI TS 103 285) §5.2 — Accessibility signalling
/// - TVA Metadata CS `urn:tva:metadata:cs:AudioPurposeCS:2007`
/// - ISO/IEC 23009-1 §5.8.4.3 — DASH Accessibility descriptor
/// - EBU Tech 3370 — Audio description bindings
public enum AudioPurpose: UInt8, Sendable, Hashable, Codable, CaseIterable {

    /// Main audio (default for the presentation). TVA code 0.
    case main = 0

    /// Audio description for visually impaired viewers — narration of
    /// visual scene content. TVA code 1. EU Accessibility Act §I
    /// recommends this signal for VOD services.
    case audioDescription = 1

    /// Audio for hearing impaired viewers — dialog-enhanced mix. TVA
    /// code 2.
    case hearingImpaired = 2

    /// Translation / dubbing of the main audio. TVA code 3.
    case translation = 3

    /// Supplementary audio (commentary, behind-the-scenes, bonus).
    /// TVA code 4.
    case supplementary = 4

    /// Emergency broadcast audio. TVA code 5.
    case emergency = 5

    /// Voice-over narration (typically over silenced or attenuated
    /// programme audio). TVA code 6.
    case voiceover = 6

    /// Spoken subtitles — TTS reading of subtitle text aloud, used as
    /// an alternative to manual reading for users who cannot read
    /// fast enough. TVA code 7.
    case spokenSubtitle = 7

    /// DVB-DASH `value=` attribute string for the
    /// `urn:tva:metadata:cs:AudioPurposeCS:2007` Accessibility
    /// descriptor.
    public var dashSchemeValue: String { String(rawValue) }

    /// `schemeIdUri` for the TVA AudioPurpose Accessibility descriptor
    /// per DVB-DASH §5.2.
    public static let dashAccessibilitySchemeIdUri =
        "urn:tva:metadata:cs:AudioPurposeCS:2007"

    /// Construct from the DVB-DASH `value=` attribute string. Returns
    /// `nil` when the value is not a recognised TVA code 0..7.
    public static func fromDASHSchemeValue(_ value: String) -> AudioPurpose? {
        guard let numeric = UInt8(value), let purpose = AudioPurpose(rawValue: numeric)
        else {
            return nil
        }
        return purpose
    }
}
