// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Cross-format round-trip integrity: HLS URI → typed → DASH Role
// value AND DASH Role value → typed → HLS URI(s). Every value of
// `urn:mpeg:dash:role:2011` is asserted by name.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MediaSelectionRole — DASH Role scheme")
struct MediaSelectionRoleDASHSchemeTests {

    @Test func dashSchemeIdUriIsCanonical() {
        #expect(
            MediaSelectionRole.dashRoleSchemeIdUri == "urn:mpeg:dash:role:2011")
    }

    @Test func everyKnownDASHRoleValueRoundTrips() throws {
        // Per urn:mpeg:dash:role:2011, the complete list of role
        // values that this typed enum claims to cover.
        let knownPairs: [(role: MediaSelectionRole, dashValue: String)] = [
            (.main, "main"),
            (.alternate, "alternate"),
            (.supplementary, "supplementary"),
            (.commentary, "commentary"),
            (.dub, "dub"),
            (.description, "description"),
            (.forcedSubtitle, "forced-subtitle"),
            (.captions, "caption"),
            (.subtitle, "subtitle"),
            (.sign, "sign"),
            (.emergency, "emergency"),
            (.karaoke, "karaoke"),
            (.enhancedAudioIntelligibility, "enhanced-audio-intelligibility"),
            (.easyReader, "easyreader")
        ]
        for pair in knownPairs {
            #expect(
                pair.role.dashRoleValue == pair.dashValue,
                "expected dashRoleValue == \(pair.dashValue) for \(pair.role)")
            let back = MediaSelectionRole.fromDASHRoleValue(pair.dashValue)
            #expect(
                back == pair.role,
                "expected fromDASHRoleValue(\(pair.dashValue)) == \(pair.role)")
        }
    }

    @Test func legacyAudioDescriptionSynonymMapsToDescription() {
        #expect(MediaSelectionRole.fromDASHRoleValue("audio-description") == .description)
    }

    @Test func transcriptHasNoDASHRoleValue() {
        #expect(MediaSelectionRole.transcript.dashRoleValue == nil)
    }

    @Test func customHasNoDASHRoleValue() {
        #expect(MediaSelectionRole.custom.dashRoleValue == nil)
    }

    @Test func fromDASHRoleValueReturnsNilForUnknown() {
        #expect(MediaSelectionRole.fromDASHRoleValue("x-vendor-role") == nil)
        #expect(MediaSelectionRole.fromDASHRoleValue("") == nil)
    }

    @Test func fromDASHRoleValueIsCaseInsensitive() {
        #expect(MediaSelectionRole.fromDASHRoleValue("MAIN") == .main)
        #expect(MediaSelectionRole.fromDASHRoleValue("Caption") == .captions)
    }

    @Test func dashValueDoesNotConfuseSubtitleVariants() {
        // The string "subtitle" must NOT map to .forcedSubtitle.
        #expect(MediaSelectionRole.fromDASHRoleValue("subtitle") == .subtitle)
        #expect(MediaSelectionRole.fromDASHRoleValue("forced-subtitle") == .forcedSubtitle)
    }
}

@Suite("MediaSelectionRole — Apple HLS CHARACTERISTICS URIs")
struct MediaSelectionRoleHLSURITests {

    @Test func descriptionMapsToDescribesVideo() {
        let uris = MediaSelectionRole.description.hlsCharacteristicURIs
        #expect(uris == ["public.accessibility.describes-video"])
    }

    @Test func captionsMapsToBothSpeechAndAmbientSound() {
        let uris = MediaSelectionRole.captions.hlsCharacteristicURIs
        #expect(uris.contains("public.accessibility.transcribes-spoken-dialog"))
        #expect(uris.contains("public.accessibility.describes-music-and-sound"))
        #expect(uris.count == 2)
    }

    @Test func enhancedAudioIntelligibilityMapsToAppleURI() {
        let uris = MediaSelectionRole.enhancedAudioIntelligibility
            .hlsCharacteristicURIs
        #expect(uris == ["public.accessibility.enhances-speech-intelligibility"])
    }

    @Test func easyReaderMapsToPublicEasyToReadURI() {
        #expect(MediaSelectionRole.easyReader.hlsCharacteristicURIs == ["public.easy-to-read"])
    }

    @Test func neutralRolesProduceNoCharacteristicURIs() {
        let neutralRoles: [MediaSelectionRole] = [
            .main, .alternate, .supplementary, .commentary, .dub,
            .subtitle, .forcedSubtitle, .sign, .emergency, .karaoke,
            .transcript, .custom
        ]
        for role in neutralRoles {
            #expect(
                role.hlsCharacteristicURIs.isEmpty,
                "expected no HLS URIs for \(role)")
        }
    }
}
