// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Every documented Apple URI round-trips, .custom preserves verbatim,
// Codable + Hashable conformance verified.

import Foundation
import Testing

@testable import CMAFKit

@Suite("AccessibilityCharacteristic — URI round-trip")
struct AccessibilityCharacteristicURITests {

    @Test func documentedCasesHaveStableURIs() {
        let expected: [(AccessibilityCharacteristic, String)] = [
            (.describesVideo, "public.accessibility.describes-video"),
            (.describesMusicAndSound, "public.accessibility.describes-music-and-sound"),
            (.transcribesSpokenDialog, "public.accessibility.transcribes-spoken-dialog"),
            (
                .enhancesSpeechIntelligibility,
                "public.accessibility.enhances-speech-intelligibility"
            ),
            (.easyToRead, "public.easy-to-read"),
            (
                .supplementaryContent,
                "public.accessibility.supplementary-content-for-user-consumption"
            ),
            (.auxiliaryContent, "public.auxiliary-content")
        ]
        for (characteristic, uri) in expected {
            #expect(characteristic.uri == uri)
        }
    }

    @Test func fromURIReturnsTypedCaseForKnownURIs() {
        let pairs: [(String, AccessibilityCharacteristic)] = [
            ("public.accessibility.describes-video", .describesVideo),
            ("public.accessibility.describes-music-and-sound", .describesMusicAndSound),
            ("public.accessibility.transcribes-spoken-dialog", .transcribesSpokenDialog),
            (
                "public.accessibility.enhances-speech-intelligibility",
                .enhancesSpeechIntelligibility
            ),
            ("public.easy-to-read", .easyToRead),
            (
                "public.accessibility.supplementary-content-for-user-consumption",
                .supplementaryContent
            ),
            ("public.auxiliary-content", .auxiliaryContent)
        ]
        for (uri, expected) in pairs {
            #expect(AccessibilityCharacteristic.fromURI(uri) == expected)
        }
    }

    @Test func fromURIPreservesUnknownURIVerbatim() {
        let custom = AccessibilityCharacteristic.fromURI("x-vendor.something")
        #expect(custom == .custom(uri: "x-vendor.something"))
        #expect(custom.uri == "x-vendor.something")
    }

    @Test func roundTripThroughURIIsIdempotent() {
        // For every documented case + a few custom URIs, fromURI(case.uri) == case.
        for documented in AccessibilityCharacteristic.documentedCases {
            #expect(AccessibilityCharacteristic.fromURI(documented.uri) == documented)
        }
        let custom = AccessibilityCharacteristic.custom(uri: "my.custom.uri")
        #expect(AccessibilityCharacteristic.fromURI(custom.uri) == custom)
    }

    @Test func documentedCasesArrayCountIsStable() {
        #expect(AccessibilityCharacteristic.documentedCases.count == 7)
    }
}

@Suite("AccessibilityCharacteristic — equality + conformance")
struct AccessibilityCharacteristicConformanceTests {

    @Test func documentedAndCustomWithSameURIAreNotEqual() {
        // Doctrine: .custom(uri: X) and the typed case sharing X are
        // distinct cases. Callers that want URI-equality must compare
        // via the .uri accessor.
        let custom = AccessibilityCharacteristic.custom(
            uri: "public.accessibility.describes-video")
        #expect(custom != .describesVideo)
        #expect(custom.uri == AccessibilityCharacteristic.describesVideo.uri)
    }

    @Test func customWithDifferentURIsAreDistinct() {
        #expect(
            AccessibilityCharacteristic.custom(uri: "a")
                != AccessibilityCharacteristic.custom(uri: "b"))
    }

    @Test func codableJSONRoundTripDocumented() throws {
        let value = AccessibilityCharacteristic.describesVideo
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(
            AccessibilityCharacteristic.self, from: data)
        #expect(decoded == value)
    }

    @Test func codableJSONRoundTripCustom() throws {
        let value = AccessibilityCharacteristic.custom(uri: "x-foo.bar.baz")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(
            AccessibilityCharacteristic.self, from: data)
        #expect(decoded == value)
    }

    @Test func hashableSetMembershipDistinguishesCustomFromDocumented() {
        let set: Set<AccessibilityCharacteristic> = [
            .describesVideo,
            .custom(uri: "public.accessibility.describes-video")
        ]
        // Different cases → different hashes → set has 2 elements.
        #expect(set.count == 2)
    }
}
