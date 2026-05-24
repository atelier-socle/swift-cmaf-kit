// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// AccessibilityMetadata — construction, derived getters, EU
// Accessibility Act helper, and real-world fixtures anchored to
// typical streaming services (Netflix, BBC iPlayer, Disney+,
// ARD/ZDF, Apple HLS Spatial Video).

import Foundation
import Testing

@testable import CMAFKit

@Suite("AccessibilityMetadata — construction + defaults")
struct AccessibilityMetadataConstructionTests {

    @Test func emptyIsAllDefaults() {
        let empty = AccessibilityMetadata.empty
        #expect(empty.role == nil)
        #expect(empty.customRoleValue == nil)
        #expect(empty.features.isEmpty)
        #expect(empty.characteristics.isEmpty)
        #expect(empty.audioPurpose == nil)
        #expect(!empty.isForced)
        #expect(!empty.isAutoSelect)
        #expect(!empty.isDefault)
        #expect(empty.associatedLanguage == nil)
        #expect(empty.signLanguage == nil)
    }

    @Test func emptyEqualsDefaultInit() {
        #expect(AccessibilityMetadata.empty == AccessibilityMetadata())
    }

    @Test func fullFieldsRoundTripViaEquatable() throws {
        let bcp47 = try BCP47LanguageTag("en-US")
        let sign = try BCP47LanguageTag("ase")
        let lhs = AccessibilityMetadata(
            role: .description,
            customRoleValue: nil,
            features: [.audioDescription],
            characteristics: [.describesVideo],
            audioPurpose: .audioDescription,
            isForced: false,
            isAutoSelect: true,
            isDefault: false,
            associatedLanguage: bcp47,
            signLanguage: sign)
        let rhs = AccessibilityMetadata(
            role: .description,
            customRoleValue: nil,
            features: [.audioDescription],
            characteristics: [.describesVideo],
            audioPurpose: .audioDescription,
            isForced: false,
            isAutoSelect: true,
            isDefault: false,
            associatedLanguage: bcp47,
            signLanguage: sign)
        #expect(lhs == rhs)
    }
}

@Suite("AccessibilityMetadata — allHLSCharacteristicURIs")
struct AccessibilityMetadataDerivedURITests {

    @Test func roleDescriptionAddsDescribesVideoURI() {
        let metadata = AccessibilityMetadata(role: .description)
        #expect(metadata.allHLSCharacteristicURIs == ["public.accessibility.describes-video"])
    }

    @Test func roleCaptionsAddsBothSpeechAndAmbientURIs() {
        let metadata = AccessibilityMetadata(role: .captions)
        let uris = metadata.allHLSCharacteristicURIs
        #expect(uris.contains("public.accessibility.transcribes-spoken-dialog"))
        #expect(uris.contains("public.accessibility.describes-music-and-sound"))
    }

    @Test func featuresAndRoleUnionExplicitCharacteristics() {
        let metadata = AccessibilityMetadata(
            role: .description,
            features: [.enhancedAudioIntelligibility],
            characteristics: [.easyToRead])
        let uris = metadata.allHLSCharacteristicURIs
        #expect(uris.contains("public.accessibility.describes-video"))
        #expect(uris.contains("public.accessibility.enhances-speech-intelligibility"))
        #expect(uris.contains("public.easy-to-read"))
    }

    @Test func emptyMetadataReturnsEmptyURISet() {
        #expect(AccessibilityMetadata.empty.allHLSCharacteristicURIs.isEmpty)
    }

    @Test func customRoleDoesNotAddImplicitURIs() {
        let metadata = AccessibilityMetadata(role: .custom)
        #expect(metadata.allHLSCharacteristicURIs.isEmpty)
    }
}

@Suite("AccessibilityMetadata — canonicalDASHRoleValue")
struct AccessibilityMetadataCanonicalDASHTests {

    @Test func typedRoleProducesSchemeValue() {
        let metadata = AccessibilityMetadata(role: .captions)
        #expect(metadata.canonicalDASHRoleValue == "caption")
    }

    @Test func customRoleProducesCustomRoleValue() {
        let metadata = AccessibilityMetadata(
            role: .custom, customRoleValue: "my-vendor-role")
        #expect(metadata.canonicalDASHRoleValue == "my-vendor-role")
    }

    @Test func customRoleWithoutCustomValueReturnsNil() {
        let metadata = AccessibilityMetadata(role: .custom)
        #expect(metadata.canonicalDASHRoleValue == nil)
    }

    @Test func transcriptRoleReturnsNil() {
        // transcript is not in urn:mpeg:dash:role:2011; signalled via
        // Accessibility descriptor instead.
        let metadata = AccessibilityMetadata(role: .transcript)
        #expect(metadata.canonicalDASHRoleValue == nil)
    }

    @Test func absentRoleReturnsNil() {
        #expect(AccessibilityMetadata.empty.canonicalDASHRoleValue == nil)
    }
}

@Suite("AccessibilityMetadata — EU Accessibility Act helper")
struct AccessibilityMetadataEUTests {

    @Test func emptyReturnsFalse() {
        #expect(!AccessibilityMetadata.empty.carriesEUAccessibilityActFeature)
    }

    @Test func audioDescriptionFeatureReturnsTrue() {
        let metadata = AccessibilityMetadata(features: [.audioDescription])
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func extendedAudioDescriptionFeatureReturnsTrue() {
        let metadata = AccessibilityMetadata(features: [.extendedAudioDescription])
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func closedCaptionsFeatureReturnsTrue() {
        let metadata = AccessibilityMetadata(features: [.closedCaptions])
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func signLanguageFeatureReturnsTrue() {
        let metadata = AccessibilityMetadata(
            features: [.signLanguageInterpretation])
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func descriptionRoleReturnsTrue() {
        let metadata = AccessibilityMetadata(role: .description)
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func signRoleReturnsTrue() {
        let metadata = AccessibilityMetadata(role: .sign)
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func captionsRoleReturnsTrue() {
        let metadata = AccessibilityMetadata(role: .captions)
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func subtitleRoleAloneReturnsFalse() {
        // Subtitle != captions in the EU AA sense — subtitle is
        // translation, not accessibility-mandated transcription.
        let metadata = AccessibilityMetadata(role: .subtitle)
        #expect(!metadata.carriesEUAccessibilityActFeature)
    }

    @Test func neutralFeatureOnlyReturnsFalse() {
        let metadata = AccessibilityMetadata(features: [.subtitles, .openCaptions])
        #expect(!metadata.carriesEUAccessibilityActFeature)
    }
}

@Suite("AccessibilityMetadata — real-world fixtures")
struct AccessibilityMetadataFixtureTests {

    // MARK: Netflix-style audio description

    @Test func netflixStyleAudioDescription() throws {
        let metadata = AccessibilityMetadata(
            role: .description,
            features: [.audioDescription],
            characteristics: [.describesVideo],
            audioPurpose: .audioDescription,
            isAutoSelect: true,
            associatedLanguage: try BCP47LanguageTag("en-US"))
        #expect(metadata.canonicalDASHRoleValue == "description")
        #expect(metadata.audioPurpose?.dashSchemeValue == "1")
        #expect(
            metadata.allHLSCharacteristicURIs
                == ["public.accessibility.describes-video"])
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    // MARK: BBC iPlayer closed captions

    @Test func bbcIPlayerClosedCaptions() throws {
        let metadata = AccessibilityMetadata(
            role: .captions,
            features: [.closedCaptions],
            characteristics: [.transcribesSpokenDialog, .describesMusicAndSound],
            isAutoSelect: true,
            associatedLanguage: try BCP47LanguageTag("en-GB"))
        #expect(metadata.canonicalDASHRoleValue == "caption")
        #expect(
            metadata.allHLSCharacteristicURIs.contains(
                "public.accessibility.transcribes-spoken-dialog"))
        #expect(
            metadata.allHLSCharacteristicURIs.contains(
                "public.accessibility.describes-music-and-sound"))
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    // MARK: Disney+ forced subtitles for foreign-language sections

    @Test func disneyPlusForcedSubtitles() throws {
        let metadata = AccessibilityMetadata(
            role: .forcedSubtitle,
            features: [.forcedSubtitles],
            isForced: true,
            associatedLanguage: try BCP47LanguageTag("en"))
        #expect(metadata.canonicalDASHRoleValue == "forced-subtitle")
        #expect(metadata.isForced)
        #expect(!metadata.carriesEUAccessibilityActFeature)  // forced != accessibility
    }

    // MARK: ARD / ZDF German sign-language track

    @Test func ardZdfGermanSignLanguage() throws {
        let metadata = AccessibilityMetadata(
            role: .sign,
            features: [.signLanguageInterpretation],
            isAutoSelect: false,
            signLanguage: try BCP47LanguageTag("gsg"))  // Deutsche Gebärdensprache
        #expect(metadata.canonicalDASHRoleValue == "sign")
        #expect(metadata.signLanguage?.primaryLanguage == .iso639_3("gsg"))
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    // MARK: French Sign Language (LSF) — accessibility on a French broadcaster

    @Test func franceTVSignLanguageLSF() throws {
        let metadata = AccessibilityMetadata(
            role: .sign,
            features: [.signLanguageInterpretation],
            signLanguage: try BCP47LanguageTag("fsl"))
        #expect(metadata.signLanguage?.primaryLanguage == .iso639_3("fsl"))
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    // MARK: American Sign Language (ASE) — US accessibility

    @Test func americanSignLanguageASE() throws {
        let metadata = AccessibilityMetadata(
            role: .sign,
            features: [.signLanguageInterpretation],
            signLanguage: try BCP47LanguageTag("ase"))
        #expect(metadata.signLanguage?.primaryLanguage == .iso639_3("ase"))
    }

    // MARK: Apple HLS Spatial Video stereo audio (no accessibility flags)

    @Test func appleSpatialVideoStereoAudio() {
        // Default Spatial Video audio renditions ship without explicit
        // accessibility signalling.
        let metadata = AccessibilityMetadata.empty
        #expect(metadata.canonicalDASHRoleValue == nil)
        #expect(metadata.allHLSCharacteristicURIs.isEmpty)
        #expect(!metadata.carriesEUAccessibilityActFeature)
    }

    // MARK: Enhanced audio intelligibility — DTV-style dialog-boosted mix

    @Test func enhancedDialogMixHearingImpaired() {
        let metadata = AccessibilityMetadata(
            role: .enhancedAudioIntelligibility,
            features: [.enhancedAudioIntelligibility],
            characteristics: [.enhancesSpeechIntelligibility],
            audioPurpose: .hearingImpaired)
        #expect(metadata.canonicalDASHRoleValue == "enhanced-audio-intelligibility")
        #expect(metadata.audioPurpose?.dashSchemeValue == "2")
        #expect(
            metadata.allHLSCharacteristicURIs == [
                "public.accessibility.enhances-speech-intelligibility"
            ])
    }
}

@Suite("AccessibilityMetadata — Equatable / Hashable / Codable")
struct AccessibilityMetadataConformanceTests {

    @Test func twoEqualConstructionsProduceEqualValues() {
        let lhs = AccessibilityMetadata(role: .captions, isAutoSelect: true)
        let rhs = AccessibilityMetadata(role: .captions, isAutoSelect: true)
        #expect(lhs == rhs)
    }

    @Test func hashableSetDeduplicates() {
        let lhs = AccessibilityMetadata(role: .description)
        let rhs = AccessibilityMetadata(role: .description)
        let set: Set<AccessibilityMetadata> = [lhs, rhs]
        #expect(set.count == 1)
    }

    @Test func codableJSONRoundTripSimple() throws {
        let value = AccessibilityMetadata(
            role: .captions,
            features: [.closedCaptions],
            characteristics: [.transcribesSpokenDialog],
            isAutoSelect: true)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AccessibilityMetadata.self, from: data)
        #expect(decoded == value)
    }

    @Test func codableJSONRoundTripWithCustomCharacteristic() throws {
        let value = AccessibilityMetadata(
            role: .custom,
            customRoleValue: "x-vendor-role",
            characteristics: [.custom(uri: "x-vendor.uri")])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AccessibilityMetadata.self, from: data)
        #expect(decoded == value)
    }

    @Test func codableJSONRoundTripWithSignLanguage() throws {
        let value = AccessibilityMetadata(
            role: .sign,
            features: [.signLanguageInterpretation],
            signLanguage: try BCP47LanguageTag("ase"))
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AccessibilityMetadata.self, from: data)
        #expect(decoded == value)
    }
}
