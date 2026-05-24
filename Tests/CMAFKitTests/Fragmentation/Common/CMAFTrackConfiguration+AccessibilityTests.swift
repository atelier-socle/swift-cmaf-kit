// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// CMAFTrackConfiguration.accessibility + SubtitleFields.accessibility
// — Option A storage, back-compat with v0.1.0 (default nil).

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFTrackConfiguration — accessibility storage")
struct CMAFTrackConfigurationAccessibilityTests {

    @Test func defaultConfigurationHasNilAccessibility() {
        let config = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .hls,
            timescale: 48_000,
            language: "eng")
        #expect(config.accessibility == nil)
    }

    @Test func configurationWithEmptyAccessibilityRoundTrips() {
        let config = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .hls,
            timescale: 48_000,
            language: "eng",
            accessibility: .empty)
        #expect(config.accessibility == .empty)
    }

    @Test func configurationWithAudioDescriptionRoundTrips() throws {
        let metadata = AccessibilityMetadata(
            role: .description,
            features: [.audioDescription],
            audioPurpose: .audioDescription,
            associatedLanguage: try BCP47LanguageTag("en-US"))
        let config = CMAFTrackConfiguration(
            trackID: 2,
            kind: .audio,
            profile: .hls,
            timescale: 48_000,
            language: "eng",
            accessibility: metadata)
        let recovered = try #require(config.accessibility)
        #expect(recovered.role == .description)
        #expect(recovered.audioPurpose == .audioDescription)
        #expect(recovered.carriesEUAccessibilityActFeature)
    }

    @Test func subtitleConfigurationCarriesAccessibilityOnBothLevels() throws {
        let trackMetadata = AccessibilityMetadata(role: .main)
        let subtitleMetadata = AccessibilityMetadata(
            role: .captions,
            features: [.closedCaptions],
            characteristics: [.transcribesSpokenDialog, .describesMusicAndSound])
        let config = CMAFTrackConfiguration(
            trackID: 3,
            kind: .subtitle,
            profile: .hls,
            timescale: 1_000,
            language: "eng",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: .webVTT,
                language: "eng",
                accessibility: subtitleMetadata),
            accessibility: trackMetadata)
        #expect(config.accessibility?.role == .main)
        #expect(config.subtitleFields?.accessibility?.role == .captions)
        #expect(config.subtitleFields?.accessibility?.features.contains(.closedCaptions) == true)
    }

    @Test func subtitleFieldsDefaultsToNilAccessibility() {
        let fields = CMAFTrackConfiguration.SubtitleFields(
            codec: .webVTT, language: "eng")
        #expect(fields.accessibility == nil)
    }

    @Test func twoEqualConfigsRemainEqualWhenAccessibilityMatches() {
        let metadata = AccessibilityMetadata(role: .captions)
        let lhs = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .hls,
            timescale: 48_000,
            language: "eng",
            accessibility: metadata)
        let rhs = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .hls,
            timescale: 48_000,
            language: "eng",
            accessibility: metadata)
        #expect(lhs == rhs)
    }

    @Test func configsWithDifferentAccessibilityAreNotEqual() {
        let lhs = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .hls,
            timescale: 48_000,
            language: "eng",
            accessibility: AccessibilityMetadata(role: .captions))
        let rhs = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .hls,
            timescale: 48_000,
            language: "eng",
            accessibility: AccessibilityMetadata(role: .description))
        #expect(lhs != rhs)
    }
}
