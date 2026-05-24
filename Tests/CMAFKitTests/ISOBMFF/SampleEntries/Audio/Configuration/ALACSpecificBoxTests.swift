// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// ALACSpecificBox magic-cookie round-trip + validation per Apple ALAC
// public specification.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ALACSpecificBox — magic-cookie round-trip")
struct ALACSpecificBoxRoundTripTests {

    @Test func stereo16Bit44100RoundTrips() async throws {
        let box = ALACSpecificBox(
            bitDepth: 16,
            numChannels: 2,
            maxFrameBytes: 4096,
            avgBitRate: 0,
            sampleRate: 44_100)
        try await assertRoundTrip(box)
    }

    @Test func stereo24Bit96kHzRoundTrips() async throws {
        let box = ALACSpecificBox(
            bitDepth: 24,
            numChannels: 2,
            maxFrameBytes: 8_192,
            avgBitRate: 1_536_000,
            sampleRate: 96_000)
        try await assertRoundTrip(box)
    }

    @Test func multichannel51_24Bit48kHzRoundTrips() async throws {
        let box = ALACSpecificBox(
            bitDepth: 24,
            numChannels: 6,
            maxFrameBytes: 16_384,
            avgBitRate: 4_608_000,
            sampleRate: 48_000)
        try await assertRoundTrip(box)
    }

    @Test func mono32BitRoundTrips() async throws {
        let box = ALACSpecificBox(
            bitDepth: 32,
            numChannels: 1,
            maxFrameBytes: 2_048,
            avgBitRate: 1_500_000,
            sampleRate: 48_000)
        try await assertRoundTrip(box)
    }

    @Test func encodedBodyMatchesAppleMagicCookieSize() {
        let box = ALACSpecificBox(
            bitDepth: 16, numChannels: 2,
            maxFrameBytes: 4096, avgBitRate: 0, sampleRate: 44_100)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // 8-byte box header + 4-byte FullBox leader + 24-byte
        // ALACSpecificConfig = 36 bytes total.
        #expect(writer.data.count == 36)
    }

    @Test func defaultsMatchAppleReferenceEncoder() {
        let box = ALACSpecificBox(
            bitDepth: 16, numChannels: 2,
            maxFrameBytes: 4096, avgBitRate: 0, sampleRate: 44_100)
        #expect(box.frameLength == 4096)
        #expect(box.compatibleVersion == 0)
        #expect(box.pb == 40)
        #expect(box.mb == 10)
        #expect(box.kb == 14)
    }

    private func assertRoundTrip(
        _ box: ALACSpecificBox,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        try box.validate()
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // Use a freshly-initialised registry where `alac` is mapped to
        // the SpecificBox (no `ALACSampleEntry` registered) — exercise
        // the magic-cookie parser standalone. The production fourCC
        // collision is resolved by the global registry mapping `alac`
        // to `ALACSampleEntry` and `ALACSampleEntry.parse` dispatching
        // the inner config box manually.
        let registry = BoxRegistry()
        await registry.register(ALACSpecificBox.self) { reader, header, registry in
            try await ALACSpecificBox.parse(
                reader: &reader, header: header, registry: registry)
        }
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(
            boxes.first as? ALACSpecificBox, sourceLocation: sourceLocation)
        #expect(parsed == box, sourceLocation: sourceLocation)
    }
}

@Suite("ALACSpecificBox — validation")
struct ALACSpecificBoxValidationTests {

    private func base(
        bitDepth: UInt8 = 16, numChannels: UInt8 = 2,
        compatibleVersion: UInt8 = 0, sampleRate: UInt32 = 44_100
    ) -> ALACSpecificBox {
        ALACSpecificBox(
            compatibleVersion: compatibleVersion,
            bitDepth: bitDepth,
            numChannels: numChannels,
            maxFrameBytes: 4096,
            avgBitRate: 0,
            sampleRate: sampleRate)
    }

    @Test func acceptsCanonicalBitDepths() throws {
        for depth: UInt8 in [16, 20, 24, 32] {
            try base(bitDepth: depth).validate()
        }
    }

    @Test func rejectsNon16_20_24_32BitDepth() {
        for depth: UInt8 in [8, 12, 18, 22, 64] {
            #expect(throws: ALACSpecificBoxError.invalidBitDepth(depth)) {
                try base(bitDepth: depth).validate()
            }
        }
    }

    @Test func acceptsOneToEightChannels() throws {
        for channels: UInt8 in 1...8 {
            try base(numChannels: channels).validate()
        }
    }

    @Test func rejectsZeroChannelCount() {
        #expect(throws: ALACSpecificBoxError.invalidChannelCount(0)) {
            try base(numChannels: 0).validate()
        }
    }

    @Test func rejectsNineChannelCount() {
        #expect(throws: ALACSpecificBoxError.invalidChannelCount(9)) {
            try base(numChannels: 9).validate()
        }
    }

    @Test func rejectsNonZeroCompatibleVersion() {
        #expect(throws: ALACSpecificBoxError.invalidCompatibleVersion(1)) {
            try base(compatibleVersion: 1).validate()
        }
    }

    @Test func rejectsZeroSampleRate() {
        #expect(throws: ALACSpecificBoxError.invalidSampleRate(0)) {
            try base(sampleRate: 0).validate()
        }
    }
}
