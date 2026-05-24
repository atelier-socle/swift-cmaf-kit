// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AccessibilityFeature
//
// Cross-format neutral accessibility-feature enum, distinct from
// ``MediaSelectionRole`` (which captures the *purpose* of an
// alternate track) — this captures *what accessibility need* the
// content addresses (low vision, hearing impairment, cognitive
// accessibility, photosensitivity, motor).
//
// References:
// - ISO/IEC 23009-1 §5.8.4.3 — DASH `Accessibility` descriptor
// - DASH-IF Implementation Guidelines v5.0+ §6.6 — Accessibility
// - Apple HLS Authoring Specification §4.6
// - Apple Media Accessibility Documentation — `public.accessibility.*`
// - W3C Media Accessibility User Requirements
// - W3C WCAG 2.2 §2.3.1 — Three Flashes or Below Threshold
// - ETSI EN 301 549 §7.1 — EU accessibility ICT
// - EU Directive 2019/882 — European Accessibility Act
// - FCC §79.4 — US online video closed-captioning
// - CTA-2065 — Closed Captioning Style guide

import Foundation

/// Accessibility feature provided by a track or supplementary content.
///
/// Multiple features can co-occur on a single track (e.g., a
/// sign-language interpretation track that also carries subtitles).
///
/// References:
/// - ISO/IEC 23009-1 §5.8.4.3 — DASH `Accessibility` descriptor
/// - DASH-IF Implementation Guidelines v5.0+ §6.6
/// - Apple HLS Authoring Specification §4.6
/// - Apple Media Accessibility Documentation
/// - W3C Media Accessibility User Requirements
/// - W3C WCAG 2.2 §2.3.1
/// - ETSI EN 301 549 §7.1
/// - EU Directive 2019/882 — European Accessibility Act
/// - FCC §79.4
/// - CTA-2065
public enum AccessibilityFeature: String, Sendable, Hashable, Codable, CaseIterable {

    // MARK: Captions / subtitles family

    /// Closed captions — text overlay for HoH viewers, including
    /// speaker identification and ambient sound description.
    /// FCC §79.4 mandates this for online video in the US.
    /// CTA-2065 Style guide. EU Accessibility Act §I.
    case closedCaptions

    /// Open captions — burned-in (not toggleable). Rare in modern
    /// streaming since they preclude language selection.
    case openCaptions

    /// Subtitles — inter-language translation, dialogue only.
    case subtitles

    /// Forced subtitles — translation of foreign-language sections
    /// only. Pairs with ``MediaSelectionRole/forcedSubtitle``.
    case forcedSubtitles

    // MARK: Audio family

    /// Audio description for visually impaired viewers — narration of
    /// visual scene content. EU Accessibility Act REQUIRES this
    /// signal for VOD streaming services in scope as of 28 June 2025.
    /// EBU Tech 3370.
    case audioDescription

    /// Extended audio description — main audio is paused to allow
    /// longer descriptions to fit. Per W3C Media Accessibility User
    /// Requirements §3.4.
    case extendedAudioDescription

    /// Enhanced audio intelligibility — dialog-boosted mix for HoH
    /// viewers. TVA AudioPurpose code 2.
    case enhancedAudioIntelligibility

    /// Spoken subtitles — TTS reading of subtitle text aloud for
    /// users who cannot read fast enough. TVA AudioPurpose code 7.
    case spokenSubtitles

    // MARK: Sign / visual

    /// Sign-language interpretation video track. Pairs with a
    /// regional sign-language BCP 47 tag (e.g., `ase`, `bfi`, `fsl`,
    /// `gsg`).
    case signLanguageInterpretation

    /// Reduced-flashing variant — photosensitivity accommodation per
    /// W3C WCAG 2.2 §2.3.1 (Three Flashes or Below Threshold).
    case reducedFlashing

    /// High-contrast variant.
    case highContrast

    /// Large-print captions.
    case largePrint

    // MARK: Cognitive / supplementary

    /// Textual transcript of audio content (typically delivered as
    /// out-of-band metadata). W3C Media Accessibility User
    /// Requirements §3.2.
    case transcript

    /// Easy-to-read variant — simplified language for cognitive
    /// accessibility. Maps to Apple HLS CHARACTERISTICS
    /// `public.easy-to-read` and DASH Role `easyreader`.
    case easyToRead

    /// Unmuted variant (where the main track is muted by default —
    /// e.g., social-style autoplay content).
    case unmuted

    /// Custom / vendor-specific feature for forward compatibility
    /// with classifications published after the 2026-05 spec
    /// snapshot.
    case custom
}
