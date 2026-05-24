// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AccessibilityFeature — raw + conformance")
struct AccessibilityFeatureTests {

    @Test func allCasesCountIsStable() {
        #expect(AccessibilityFeature.allCases.count == 16)
    }

    @Test func everyCaseRoundTripsRawString() throws {
        for feature in AccessibilityFeature.allCases {
            let raw = feature.rawValue
            let back = try #require(AccessibilityFeature(rawValue: raw))
            #expect(back == feature)
        }
    }

    @Test func codableJSONRoundTripCommonFeatures() throws {
        let cases: [AccessibilityFeature] = [
            .closedCaptions, .audioDescription, .signLanguageInterpretation,
            .easyToRead, .custom
        ]
        for feature in cases {
            let data = try JSONEncoder().encode(feature)
            let decoded = try JSONDecoder().decode(AccessibilityFeature.self, from: data)
            #expect(decoded == feature)
        }
    }

    @Test func hashableSetSupportsCommonFeatureCombinations() {
        let set: Set<AccessibilityFeature> = [
            .closedCaptions, .audioDescription, .signLanguageInterpretation
        ]
        #expect(set.count == 3)
        #expect(set.contains(.closedCaptions))
        #expect(!set.contains(.openCaptions))
    }
}

@Suite("AccessibilityFeature — cross-format mappings")
struct AccessibilityFeatureCrossFormatTests {

    // MARK: dashAccessibilityValue

    @Test func closedCaptionsMapsToDASHCaption() {
        #expect(AccessibilityFeature.closedCaptions.dashAccessibilityValue == "caption")
    }

    @Test func audioDescriptionVariantsMapToDASHDescription() {
        #expect(AccessibilityFeature.audioDescription.dashAccessibilityValue == "description")
        #expect(
            AccessibilityFeature.extendedAudioDescription
                .dashAccessibilityValue == "description")
    }

    @Test func signLanguageInterpretationMapsToDASHSign() {
        #expect(
            AccessibilityFeature.signLanguageInterpretation
                .dashAccessibilityValue == "sign")
    }

    @Test func enhancedAudioIntelligibilityMapsToDASHValue() {
        #expect(
            AccessibilityFeature.enhancedAudioIntelligibility
                .dashAccessibilityValue == "enhanced-audio-intelligibility")
    }

    @Test func easyToReadMapsToDASHEasyReader() {
        #expect(AccessibilityFeature.easyToRead.dashAccessibilityValue == "easyreader")
    }

    @Test func forcedSubtitlesMapsToDASHForcedSubtitle() {
        #expect(
            AccessibilityFeature.forcedSubtitles.dashAccessibilityValue == "forced-subtitle"
        )
    }

    @Test func neutralFeaturesReturnNilDASHValue() {
        let neutrals: [AccessibilityFeature] = [
            .openCaptions, .subtitles, .spokenSubtitles, .reducedFlashing,
            .highContrast, .largePrint, .transcript, .unmuted, .custom
        ]
        for feature in neutrals {
            #expect(
                feature.dashAccessibilityValue == nil,
                "expected no DASH scheme value for \(feature)")
        }
    }

    // MARK: hlsCharacteristicURIs

    @Test func closedCaptionsMapsToBothSpeechAndAmbientHLSURIs() {
        let uris = AccessibilityFeature.closedCaptions.hlsCharacteristicURIs
        #expect(uris.contains("public.accessibility.transcribes-spoken-dialog"))
        #expect(uris.contains("public.accessibility.describes-music-and-sound"))
    }

    @Test func audioDescriptionMapsToDescribesVideoURI() {
        #expect(
            AccessibilityFeature.audioDescription.hlsCharacteristicURIs
                == ["public.accessibility.describes-video"])
        #expect(
            AccessibilityFeature.extendedAudioDescription.hlsCharacteristicURIs
                == ["public.accessibility.describes-video"])
    }

    @Test func enhancedAudioIntelligibilityMapsToCorrectHLSURI() {
        #expect(
            AccessibilityFeature.enhancedAudioIntelligibility.hlsCharacteristicURIs
                == ["public.accessibility.enhances-speech-intelligibility"])
    }

    @Test func easyToReadMapsToPublicEasyToReadHLSURI() {
        #expect(
            AccessibilityFeature.easyToRead.hlsCharacteristicURIs
                == ["public.easy-to-read"])
    }

    @Test func transcriptMapsToTranscribesSpokenDialog() {
        #expect(
            AccessibilityFeature.transcript.hlsCharacteristicURIs
                == ["public.accessibility.transcribes-spoken-dialog"])
    }

    @Test func neutralFeaturesReturnEmptyHLSURIs() {
        let neutrals: [AccessibilityFeature] = [
            .openCaptions, .subtitles, .forcedSubtitles, .spokenSubtitles,
            .signLanguageInterpretation, .reducedFlashing, .highContrast,
            .largePrint, .unmuted, .custom
        ]
        for feature in neutrals {
            #expect(
                feature.hlsCharacteristicURIs.isEmpty,
                "expected no HLS URIs for \(feature)")
        }
    }

    // MARK: audioPurpose

    @Test func audioDescriptionFeaturesMapToTVAAudioDescription() {
        #expect(AccessibilityFeature.audioDescription.audioPurpose == .audioDescription)
        #expect(
            AccessibilityFeature.extendedAudioDescription.audioPurpose
                == .audioDescription)
    }

    @Test func enhancedAudioIntelligibilityMapsToHearingImpaired() {
        #expect(
            AccessibilityFeature.enhancedAudioIntelligibility.audioPurpose
                == .hearingImpaired)
    }

    @Test func spokenSubtitlesMapsToTVASpokenSubtitle() {
        #expect(AccessibilityFeature.spokenSubtitles.audioPurpose == .spokenSubtitle)
    }

    @Test func nonAudioFeaturesReturnNilAudioPurpose() {
        let nonAudio: [AccessibilityFeature] = [
            .closedCaptions, .openCaptions, .subtitles, .forcedSubtitles,
            .signLanguageInterpretation, .reducedFlashing, .highContrast,
            .largePrint, .transcript, .easyToRead, .unmuted, .custom
        ]
        for feature in nonAudio {
            #expect(
                feature.audioPurpose == nil,
                "expected nil audioPurpose for \(feature)")
        }
    }
}
