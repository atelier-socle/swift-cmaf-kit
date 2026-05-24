// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MediaSelectionRole — HLS / DASH cross-format mappings
//
// References:
// - ISO/IEC 23009-1 §5.8.5.5 — `urn:mpeg:dash:role:2011` scheme values
// - DASH-IF Implementation Guidelines v5.0+ §6.6
// - Apple HLS Authoring Specification §4.6
// - Apple Media Accessibility Documentation — `public.accessibility.*`
// - W3C Media Accessibility User Requirements

import Foundation

extension MediaSelectionRole {

    /// `schemeIdUri` for the DASH Role descriptor per ISO/IEC 23009-1
    /// §5.8.5.5.
    public static let dashRoleSchemeIdUri = "urn:mpeg:dash:role:2011"

    /// DASH Role `value` attribute per
    /// `urn:mpeg:dash:role:2011`. Returns `nil` when the role has no
    /// stable scheme value (e.g., ``transcript`` is signalled via the
    /// DASH `Accessibility` descriptor, not `Role`) or when the role
    /// is ``custom`` (caller supplies the scheme value via
    /// ``AccessibilityMetadata/customRoleValue``).
    ///
    /// References:
    /// - ISO/IEC 23009-1 §5.8.5.5 — `urn:mpeg:dash:role:2011`
    /// - DASH-IF Implementation Guidelines v5.0+ §6.6
    public var dashRoleValue: String? {
        switch self {
        case .main: return "main"
        case .alternate: return "alternate"
        case .supplementary: return "supplementary"
        case .commentary: return "commentary"
        case .dub: return "dub"
        case .description: return "description"
        case .forcedSubtitle: return "forced-subtitle"
        case .captions: return "caption"
        case .subtitle: return "subtitle"
        case .sign: return "sign"
        case .emergency: return "emergency"
        case .karaoke: return "karaoke"
        case .enhancedAudioIntelligibility: return "enhanced-audio-intelligibility"
        case .easyReader: return "easyreader"
        case .transcript: return nil
        case .custom: return nil
        }
    }

    /// Reverse parser: typed case from a DASH Role `value` string per
    /// `urn:mpeg:dash:role:2011`. Returns `nil` when the value is not
    /// in the embedded scheme snapshot — callers may then fall back to
    /// ``custom`` with the raw value stored on
    /// ``AccessibilityMetadata/customRoleValue``.
    ///
    /// Also accepts the legacy `audio-description` synonym for
    /// ``description`` (DASH-IF §6.6 lists both).
    public static func fromDASHRoleValue(_ value: String) -> MediaSelectionRole? {
        switch value.lowercased() {
        case "main": return .main
        case "alternate": return .alternate
        case "supplementary": return .supplementary
        case "commentary": return .commentary
        case "dub": return .dub
        case "description", "audio-description": return .description
        case "forced-subtitle": return .forcedSubtitle
        case "caption": return .captions
        case "subtitle": return .subtitle
        case "sign": return .sign
        case "emergency": return .emergency
        case "karaoke": return .karaoke
        case "enhanced-audio-intelligibility": return .enhancedAudioIntelligibility
        case "easyreader": return .easyReader
        default: return nil
        }
    }

    /// Apple HLS CHARACTERISTICS URIs implied by this role per Apple
    /// HLS Authoring §4.6.1. Returns an empty array for roles that
    /// are signalled via other attributes (NAME, TYPE, FORCED…) rather
    /// than CHARACTERISTICS.
    ///
    /// Multiple URIs may be returned for a single role (e.g.,
    /// ``captions`` covers both spoken-dialog transcription and
    /// music-and-sound description).
    public var hlsCharacteristicURIs: [String] {
        switch self {
        case .description:
            return ["public.accessibility.describes-video"]
        case .captions:
            return [
                "public.accessibility.transcribes-spoken-dialog",
                "public.accessibility.describes-music-and-sound"
            ]
        case .enhancedAudioIntelligibility:
            return ["public.accessibility.enhances-speech-intelligibility"]
        case .easyReader:
            return ["public.easy-to-read"]
        default:
            return []
        }
    }
}
