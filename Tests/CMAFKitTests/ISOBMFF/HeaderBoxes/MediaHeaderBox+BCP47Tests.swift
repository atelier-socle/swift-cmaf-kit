// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MediaHeaderBox.languageAsBCP47() — typed bridge from mdhd packed
// ISO 639-2 to BCP 47, including /B → /T disambiguation.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MediaHeaderBox — languageAsBCP47 bridge")
struct MediaHeaderBoxBCP47Tests {

    private func makeBox(language: String) -> MediaHeaderBox {
        MediaHeaderBox(
            version: 1,
            flags: 0,
            creationTime: 0,
            modificationTime: 0,
            timescale: 48_000,
            duration: 0,
            language: language)
    }

    @Test func happyPathFrenchTerminologic() throws {
        let bcp47 = try makeBox(language: "fra").languageAsBCP47()
        #expect(bcp47.primaryLanguage == .iso639_1("fr"))
    }

    @Test func happyPathFrenchBibliographicDisambiguates() throws {
        let bcp47 = try makeBox(language: "fre").languageAsBCP47()
        #expect(bcp47.primaryLanguage == .iso639_1("fr"))
    }

    @Test func happyPathCantonesePreserves3Char() throws {
        let bcp47 = try makeBox(language: "yue").languageAsBCP47()
        #expect(bcp47.primaryLanguage == .iso639_3("yue"))
    }

    @Test func undeterminedProducesUndTag() throws {
        let bcp47 = try makeBox(language: "und").languageAsBCP47()
        #expect(bcp47.primaryLanguage == .iso639_3("und"))
    }

    @Test func malformedStorageThrows() throws {
        // mdhd was somehow written with a non-3-letter value
        // (encoder bug); must throw, not crash.
        #expect(throws: BCP47Error.self) {
            _ = try makeBox(language: "x1").languageAsBCP47()
        }
    }
}
