// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AccessibilityFeature — HLS / DASH cross-format mappings
//
// References:
// - ISO/IEC 23009-1 §5.8.4.3 — DASH `Accessibility` descriptor
// - DASH-IF Implementation Guidelines v5.0+ §6.6 — Accessibility
// - Apple HLS Authoring Specification §4.6
// - Apple Media Accessibility Documentation
// - DVB-DASH (ETSI TS 103 285) §5.2 — TVA AudioPurpose

import Foundation

extension AccessibilityFeature {

    /// DASH Role / Accessibility scheme `value` per
    /// `urn:mpeg:dash:role:2011` (ISO/IEC 23009-1 §5.8.5.5) for
    /// features that have a stable scheme value. Returns `nil` for
    /// features that are not signalled via this scheme.
    ///
    /// DASH-IF §6.6 notes that several accessibility concepts are
    /// shared between `Role` and `Accessibility` descriptors;
    /// emitters typically pair this value with the
    /// ``MediaSelectionRole/dashRoleSchemeIdUri`` scheme.
    public var dashAccessibilityValue: String? {
        switch self {
        case .closedCaptions: return "caption"
        case .audioDescription, .extendedAudioDescription:
            return "description"
        case .signLanguageInterpretation: return "sign"
        case .enhancedAudioIntelligibility:
            return "enhanced-audio-intelligibility"
        case .easyToRead: return "easyreader"
        case .forcedSubtitles: return "forced-subtitle"
        default: return nil
        }
    }

    /// Apple HLS CHARACTERISTICS URIs implied by this feature per
    /// Apple HLS Authoring §4.6.1 + Apple Media Accessibility
    /// Documentation. Multiple URIs may be returned (e.g.,
    /// ``closedCaptions`` covers both spoken-dialog transcription and
    /// music-and-sound description).
    public var hlsCharacteristicURIs: [String] {
        switch self {
        case .closedCaptions:
            return [
                "public.accessibility.transcribes-spoken-dialog",
                "public.accessibility.describes-music-and-sound"
            ]
        case .audioDescription, .extendedAudioDescription:
            return ["public.accessibility.describes-video"]
        case .enhancedAudioIntelligibility:
            return ["public.accessibility.enhances-speech-intelligibility"]
        case .easyToRead:
            return ["public.easy-to-read"]
        case .transcript:
            return ["public.accessibility.transcribes-spoken-dialog"]
        default:
            return []
        }
    }

    /// DVB TVA AudioPurpose code per
    /// `urn:tva:metadata:cs:AudioPurposeCS:2007` (DVB-DASH §5.2) for
    /// features that are audio-purpose-related. Returns `nil` for
    /// features that are not audio-purpose-related.
    public var audioPurpose: AudioPurpose? {
        switch self {
        case .audioDescription, .extendedAudioDescription:
            return .audioDescription
        case .enhancedAudioIntelligibility:
            return .hearingImpaired
        case .spokenSubtitles:
            return .spokenSubtitle
        default:
            return nil
        }
    }
}
