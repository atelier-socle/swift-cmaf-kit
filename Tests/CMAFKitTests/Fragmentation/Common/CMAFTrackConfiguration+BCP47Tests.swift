// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// CMAFTrackConfiguration.bcp47Language — silent-degrade typed BCP 47
// view for HLS / DASH manifest emission contexts.

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFTrackConfiguration — bcp47Language")
struct CMAFTrackConfigurationBCP47Tests {

    private func subtitleConfig(language: String) -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: 1,
            kind: .subtitle,
            profile: .hls,
            timescale: 1_000,
            language: language,
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: .webVTT, language: language))
    }

    @Test func happyPathEnglishReturnsISO6391() throws {
        let config = subtitleConfig(language: "eng")
        let bcp47 = try #require(config.bcp47Language)
        #expect(bcp47.primaryLanguage == .iso639_1("en"))
    }

    @Test func bibliographicDisambiguatesSilently() throws {
        let config = subtitleConfig(language: "fre")
        let bcp47 = try #require(config.bcp47Language)
        #expect(bcp47.primaryLanguage == .iso639_1("fr"))
    }

    @Test func emptyStringDegradesToNil() throws {
        let config = subtitleConfig(language: "")
        #expect(config.bcp47Language == nil)
    }

    @Test func undeterminedDegradesToNil() throws {
        let config = subtitleConfig(language: "und")
        #expect(config.bcp47Language == nil)
    }

    @Test func undeterminedUppercaseDegradesToNil() throws {
        let config = subtitleConfig(language: "UND")
        #expect(config.bcp47Language == nil)
    }

    @Test func malformedLanguageDegradesToNil() throws {
        let config = subtitleConfig(language: "x1")
        #expect(config.bcp47Language == nil)
    }

    @Test func subtitleFieldsBCP47ReadsSubtitleStreamLanguage() throws {
        let config = CMAFTrackConfiguration(
            trackID: 1,
            kind: .subtitle,
            profile: .hls,
            timescale: 1_000,
            language: "fra",  // Track-level: French audio
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: .webVTT, language: "eng"))  // Captions: English
        let trackTag = try #require(config.bcp47Language)
        let subtitleTag = try #require(config.subtitleFields?.bcp47Language)
        #expect(trackTag.primaryLanguage == .iso639_1("fr"))
        #expect(subtitleTag.primaryLanguage == .iso639_1("en"))
    }

    @Test func subtitleFieldsBCP47NilWhenUndetermined() throws {
        let config = CMAFTrackConfiguration(
            trackID: 1,
            kind: .subtitle,
            profile: .hls,
            timescale: 1_000,
            language: "eng",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: .webVTT, language: "und"))
        #expect(config.subtitleFields?.bcp47Language == nil)
    }
}
