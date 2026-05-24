// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MediaSelectionRole
//
// Cross-format neutral track-role enum. The Atelier Socle streaming
// ecosystem uses this typed primitive everywhere a track role must be
// signalled: HLSKit serialises to `EXT-X-MEDIA CHARACTERISTICS /
// AUTOSELECT / FORCED / DEFAULT`; DASHKit serialises to MPD `<Role>`
// descriptors per `urn:mpeg:dash:role:2011`.
//
// References:
// - ISO/IEC 23009-1 §5.8.4.2 — DASH `Role` descriptor
// - ISO/IEC 23009-1 §5.8.5.5 — `urn:mpeg:dash:role:2011` scheme
// - DASH-IF Implementation Guidelines v5.0+ §6.6
// - Apple HLS Authoring Specification §4.6 — `EXT-X-MEDIA` attributes
// - RFC 8216bis — HLS specification
// - W3C Media Accessibility User Requirements

import Foundation

/// Cross-format media-selection role for an audio / video / subtitle
/// / caption track.
///
/// Captures the *purpose* of an alternate track within a presentation
/// (main, alternate, commentary, audio description, sign language,
/// closed captions, …). This typed primitive is the neutral form that
/// HLSKit encodes as HLS `EXT-X-MEDIA` attributes and that DASHKit
/// encodes as MPD `<Role>` descriptors.
///
/// References:
/// - ISO/IEC 23009-1 §5.8.4.2, §5.8.5.5 — DASH `Role` +
///   `urn:mpeg:dash:role:2011`
/// - DASH-IF Implementation Guidelines v5.0+ §6.6 — Accessibility
/// - Apple HLS Authoring Specification §4.6
/// - RFC 8216bis — HLS specification
/// - W3C Media Accessibility User Requirements
public enum MediaSelectionRole: String, Sendable, Hashable, Codable, CaseIterable {

    /// Primary track of its group. Maps to DASH Role `main` + HLS
    /// `DEFAULT=YES`.
    case main

    /// Alternate of the main (different angle, mix, language).
    /// Maps to DASH Role `alternate`.
    case alternate

    /// Supplementary content presented alongside the main (bonus,
    /// behind-the-scenes). Maps to DASH Role `supplementary`.
    case supplementary

    /// Commentary track (director / cast / podcast-style).
    /// Maps to DASH Role `commentary`.
    case commentary

    /// Dubbed alternate-language version. Maps to DASH Role `dub`.
    case dub

    /// Audio description for visually impaired viewers — narration of
    /// visual scene content. Maps to DASH Role `description` AND
    /// `audio-description` (DASH-IF §6.6 accepts both). Maps to Apple
    /// HLS CHARACTERISTICS `public.accessibility.describes-video`.
    /// EU Accessibility Act §I-relevant signal.
    case description

    /// Forced subtitles — translation of foreign-language sections of
    /// an otherwise in-language presentation. Maps to DASH Role
    /// `forced-subtitle`. Pairs with HLS `FORCED=YES`.
    case forcedSubtitle

    /// Closed captions — intra-language transcription including
    /// dialogue, speaker identification, music, ambient sound. Maps to
    /// DASH Role `caption`. Maps to Apple HLS CHARACTERISTICS
    /// `public.accessibility.transcribes-spoken-dialog` +
    /// `public.accessibility.describes-music-and-sound`. FCC §79.4 +
    /// CTA-2065 + EU Accessibility Act §I.
    case captions

    /// Subtitles — inter-language translation, dialogue only. Maps to
    /// DASH Role `subtitle`. In HLS, distinguished from
    /// ``captions`` by absence of the
    /// `transcribes-spoken-dialog` CHARACTERISTICS URI.
    case subtitle

    /// Sign-language interpretation video track. Maps to DASH Role
    /// `sign`. Pairs with a regional sign-language BCP 47 tag on
    /// ``AccessibilityMetadata/signLanguage`` (e.g., `ase` American
    /// Sign Language, `bfi` British Sign Language, `fsl` Langue des
    /// Signes Française, `gsg` Deutsche Gebärdensprache).
    case sign

    /// Emergency broadcast track. Maps to DASH Role `emergency`.
    /// Required in regulated broadcast / live contexts (US FCC, EU
    /// emergency broadcasting).
    case emergency

    /// Karaoke text overlay. Maps to DASH Role `karaoke`.
    case karaoke

    /// Enhanced audio intelligibility — dialog-boosted mix for HoH
    /// viewers (typically dialog +6 dB). Maps to DASH Role
    /// `enhanced-audio-intelligibility`. Maps to Apple HLS
    /// CHARACTERISTICS
    /// `public.accessibility.enhances-speech-intelligibility`. TVA
    /// AudioPurpose 2.
    case enhancedAudioIntelligibility

    /// Textual transcript (typically out-of-band metadata stream).
    /// Per W3C Media Accessibility User Requirements §3.2; no
    /// `urn:mpeg:dash:role:2011` value — DASH signalling uses an
    /// `Accessibility` descriptor instead.
    case transcript

    /// Easy-reader variant — simplified language for cognitive
    /// accessibility. Maps to DASH Role `easyreader`.
    case easyReader

    /// Custom / vendor-specific role for forward compatibility with
    /// schemes published after the 2026-05 spec snapshot. The actual
    /// scheme value travels on
    /// ``AccessibilityMetadata/customRoleValue``.
    case custom
}
