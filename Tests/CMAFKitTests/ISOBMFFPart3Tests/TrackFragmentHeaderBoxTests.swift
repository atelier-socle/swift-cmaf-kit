// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for TrackFragmentHeaderBox (tfhd) — ISO/IEC 14496-12 §8.8.7.

import Foundation
import Testing

@testable import CMAFKit

@Suite("TrackFragmentHeaderBox")
struct TrackFragmentHeaderBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let original = TrackFragmentHeaderBox(trackID: 1)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentHeaderBox)
        #expect(parsed == original)
        // Default flag is defaultBaseIsMoof — the CMAF-recommended addressing mode.
        #expect(parsed.defaultBaseIsMoof == true)
    }

    @Test
    func roundTripAllOptionalFields() async throws {
        let original = TrackFragmentHeaderBox(
            trackID: 1,
            baseDataOffset: 0xDEAD_BEEF_FEED_FACE,
            sampleDescriptionIndex: 2,
            defaultSampleDuration: 1024,
            defaultSampleSize: 512,
            defaultSampleFlags: 0x0101_0000
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentHeaderBox)
        #expect(parsed.baseDataOffset == 0xDEAD_BEEF_FEED_FACE)
        #expect(parsed.sampleDescriptionIndex == 2)
        #expect(parsed.defaultSampleDuration == 1024)
        #expect(parsed.defaultSampleSize == 512)
        #expect(parsed.defaultSampleFlags == 0x0101_0000)
    }

    @Test
    func publicInitReconcilesFlags() {
        // Pass only defaultSampleSize. The reconciler must set the bit and
        // clear any others not provided.
        let box = TrackFragmentHeaderBox(
            flags: 0,
            trackID: 1,
            defaultSampleSize: 100
        )
        #expect((box.flags & TrackFragmentHeaderBox.flagDefaultSampleSize) != 0)
        #expect((box.flags & TrackFragmentHeaderBox.flagDefaultSampleDuration) == 0)
        #expect((box.flags & TrackFragmentHeaderBox.flagDefaultSampleFlags) == 0)
        #expect((box.flags & TrackFragmentHeaderBox.flagSampleDescriptionIndex) == 0)
        #expect((box.flags & TrackFragmentHeaderBox.flagBaseDataOffset) == 0)
    }

    @Test
    func publicInitClearsConflictingFlags() {
        // Pass flags that claim defaultSampleSize is present but provide nil.
        // The reconciler must clear the bit.
        let box = TrackFragmentHeaderBox(
            flags: TrackFragmentHeaderBox.flagDefaultSampleSize
                | TrackFragmentHeaderBox.flagDefaultSampleDuration,
            trackID: 1,
            defaultSampleDuration: nil,
            defaultSampleSize: nil
        )
        #expect((box.flags & TrackFragmentHeaderBox.flagDefaultSampleSize) == 0)
        #expect((box.flags & TrackFragmentHeaderBox.flagDefaultSampleDuration) == 0)
    }

    @Test
    func defaultBaseIsMoofFlagPreserved() {
        // Default constructor sets defaultBaseIsMoof. Verify reconciliation
        // does not clobber non-Optional-driven flag bits.
        let box = TrackFragmentHeaderBox(trackID: 1, defaultSampleSize: 100)
        #expect(box.defaultBaseIsMoof == true)
    }

    @Test
    func emptyDurationFlagIsAccessible() {
        let box = TrackFragmentHeaderBox(
            flags: TrackFragmentHeaderBox.flagDefaultBaseIsMoof
                | TrackFragmentHeaderBox.flagDurationIsEmpty,
            trackID: 1
        )
        #expect(box.durationIsEmpty == true)
    }

    @Test
    func encodeMatchesKnownBytesMinimal() {
        // tfhd with default flags (flagDefaultBaseIsMoof = 0x020000).
        let box = TrackFragmentHeaderBox(trackID: 1)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 10 74 66 68 64
                00 02 00 00
                00 00 00 01
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytesWithAllFields() async throws {
        // flags = 0x02003B = defaultBaseIsMoof | flagBaseDataOffset(0x000001)
        //   | flagSampleDescriptionIndex(0x000002) | flagDefaultSampleDuration(0x000008)
        //   | flagDefaultSampleSize(0x000010) | flagDefaultSampleFlags(0x000020)
        // Total body: 4 (ver+flags) + 4 (trackID) + 8 (baseDataOffset) + 4 + 4 + 4 + 4 = 32 bytes
        // Box size: 8 (header) + 32 (body) = 40 = 0x28
        let bytes = Data(
            hex: """
                00 00 00 28 74 66 68 64
                00 02 00 3B
                00 00 00 01
                00 00 00 00 00 00 10 00
                00 00 00 02
                00 00 04 00
                00 00 02 00
                01 00 00 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentHeaderBox)
        #expect(parsed.trackID == 1)
        #expect(parsed.baseDataOffset == 0x1000)
        #expect(parsed.sampleDescriptionIndex == 2)
        #expect(parsed.defaultSampleDuration == 0x400)
        #expect(parsed.defaultSampleSize == 0x200)
        #expect(parsed.defaultSampleFlags == 0x0100_0000)
    }

    @Test
    func decodeSideTrustsWireFlags() async throws {
        // Encode → decode → encode → exact byte equality.
        let original = TrackFragmentHeaderBox(
            trackID: 42,
            defaultSampleDuration: 1024,
            defaultSampleFlags: 0x0202_0000
        )
        var w1 = BinaryWriter()
        original.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentHeaderBox)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }
}
