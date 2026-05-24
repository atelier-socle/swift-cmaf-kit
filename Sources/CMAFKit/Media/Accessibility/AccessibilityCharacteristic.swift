// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AccessibilityCharacteristic
//
// Apple HLS CHARACTERISTICS URI — typed enum over the documented
// `public.accessibility.*` and related URIs from Apple Media
// Accessibility documentation, plus an escape hatch for custom URIs
// (forward compatibility).
//
// References:
// - Apple HLS Authoring Specification §4.6.1 — `CHARACTERISTICS`
// - Apple Media Accessibility Documentation
//   (developer.apple.com/documentation/avfoundation/)

import Foundation

/// Apple HLS CHARACTERISTICS URI — typed enum over the documented
/// `public.accessibility.*` URIs from Apple Media Accessibility
/// documentation, plus a `.custom(uri:)` escape hatch for URIs added
/// after the 2026-05 snapshot.
///
/// The HLS `EXT-X-MEDIA CHARACTERISTICS` attribute carries a
/// comma-separated list of URIs — one `AccessibilityCharacteristic`
/// per URI.
///
/// **Equality semantics**: `.custom("public.accessibility.describes-video")`
/// and ``describesVideo`` are NOT equal even though they share the
/// same URI — they are different enum cases. Callers that need
/// case-insensitive URI matching should compare via ``uri``.
///
/// References:
/// - Apple HLS Authoring Specification §4.6.1
/// - Apple Media Accessibility Documentation
public enum AccessibilityCharacteristic: Sendable, Hashable, Codable {

    /// `public.accessibility.describes-video` — audio description of
    /// visual content. EU Accessibility Act §I-relevant signal.
    case describesVideo

    /// `public.accessibility.describes-music-and-sound` — captions
    /// including music descriptions and sound effects (typical for
    /// closed captions for the HoH).
    case describesMusicAndSound

    /// `public.accessibility.transcribes-spoken-dialog` — captions
    /// including all spoken dialogue plus speaker identification
    /// (typical for closed captions for the HoH).
    case transcribesSpokenDialog

    /// `public.accessibility.enhances-speech-intelligibility` —
    /// dialog-enhanced audio mix for HoH viewers.
    case enhancesSpeechIntelligibility

    /// `public.easy-to-read` — simplified language / cognitive
    /// accessibility variant.
    case easyToRead

    /// `public.accessibility.supplementary-content-for-user-consumption`
    /// — supplementary content (bonus, commentary, behind-the-scenes).
    case supplementaryContent

    /// `public.auxiliary-content` — auxiliary content (out-of-band
    /// metadata, alternative-angle camera feed, etc.).
    case auxiliaryContent

    /// Custom URI — forward compatibility for URIs added after the
    /// 2026-05 spec snapshot. The associated value carries the URI
    /// verbatim.
    case custom(uri: String)

    /// The URI string used in HLS `EXT-X-MEDIA CHARACTERISTICS`
    /// attribute.
    public var uri: String {
        switch self {
        case .describesVideo:
            return "public.accessibility.describes-video"
        case .describesMusicAndSound:
            return "public.accessibility.describes-music-and-sound"
        case .transcribesSpokenDialog:
            return "public.accessibility.transcribes-spoken-dialog"
        case .enhancesSpeechIntelligibility:
            return "public.accessibility.enhances-speech-intelligibility"
        case .easyToRead:
            return "public.easy-to-read"
        case .supplementaryContent:
            return "public.accessibility.supplementary-content-for-user-consumption"
        case .auxiliaryContent:
            return "public.auxiliary-content"
        case .custom(let uri):
            return uri
        }
    }

    /// Reverse parser: typed case from a URI string. Always returns a
    /// value — unrecognised URIs become ``custom(uri:)`` with the URI
    /// preserved verbatim. This is permissive by design — HLS parsers
    /// should never fail on an unknown URI.
    public static func fromURI(_ uri: String) -> AccessibilityCharacteristic {
        switch uri {
        case "public.accessibility.describes-video":
            return .describesVideo
        case "public.accessibility.describes-music-and-sound":
            return .describesMusicAndSound
        case "public.accessibility.transcribes-spoken-dialog":
            return .transcribesSpokenDialog
        case "public.accessibility.enhances-speech-intelligibility":
            return .enhancesSpeechIntelligibility
        case "public.easy-to-read":
            return .easyToRead
        case "public.accessibility.supplementary-content-for-user-consumption":
            return .supplementaryContent
        case "public.auxiliary-content":
            return .auxiliaryContent
        default:
            return .custom(uri: uri)
        }
    }

    /// All the typed (non-`.custom`) cases. Mirrors what
    /// `CaseIterable` would produce for an enum without associated
    /// values — exposed for HLS validators that need to enumerate
    /// the documented URI set.
    public static let documentedCases: [AccessibilityCharacteristic] = [
        .describesVideo,
        .describesMusicAndSound,
        .transcribesSpokenDialog,
        .enhancesSpeechIntelligibility,
        .easyToRead,
        .supplementaryContent,
        .auxiliaryContent
    ]
}
