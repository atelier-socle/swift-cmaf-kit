// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for the four media-header boxes (vmhd, smhd, nmhd, sthd) —
// ISO/IEC 14496-12 §8.4.5.2, §8.4.5.3, §12.6.

import Foundation
import Testing

@testable import CMAFKit

// MARK: - vmhd

@Suite("VideoMediaHeaderBox")
struct VideoMediaHeaderBoxTests {

    @Test
    func defaultFlagsAreOne() {
        let box = VideoMediaHeaderBox()
        #expect(box.flags == 0x0000_0001)
    }

    @Test
    func roundTripDefault() async throws {
        let original = VideoMediaHeaderBox()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? VideoMediaHeaderBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripWithOpcolor() async throws {
        let original = VideoMediaHeaderBox(
            graphicsMode: 1,
            opcolor: (0xFF00, 0x0F0F, 0x00FF)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? VideoMediaHeaderBox)
        #expect(parsed.graphicsMode == 1)
        #expect(parsed.opcolor.0 == 0xFF00)
        #expect(parsed.opcolor.1 == 0x0F0F)
        #expect(parsed.opcolor.2 == 0x00FF)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = VideoMediaHeaderBox()
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) + gfxMode(2) + opcolor(6) = 20
        let expected = Data(
            hex: """
                00 00 00 14 76 6D 68 64
                00 00 00 01
                00 00
                00 00 00 00 00 00
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 14 76 6D 68 64
                00 00 00 01
                00 02
                12 34 56 78 9A BC
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? VideoMediaHeaderBox)
        #expect(parsed.graphicsMode == 2)
        #expect(parsed.opcolor.0 == 0x1234)
        #expect(parsed.opcolor.1 == 0x5678)
        #expect(parsed.opcolor.2 == 0x9ABC)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 14 76 6D 68 64 00 00 00 01")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }
}

// MARK: - smhd

@Suite("SoundMediaHeaderBox")
struct SoundMediaHeaderBoxTests {

    @Test
    func defaultBalanceIsZero() {
        let box = SoundMediaHeaderBox()
        #expect(box.balance == 0.0)
    }

    @Test
    func roundTripCentredBalance() async throws {
        let original = SoundMediaHeaderBox(balance: 0.0)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SoundMediaHeaderBox)
        #expect(parsed.balance == 0.0)
    }

    @Test
    func roundTripFullLeftBalance() async throws {
        let original = SoundMediaHeaderBox(balance: -1.0)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SoundMediaHeaderBox)
        #expect(parsed.balance == -1.0)
    }

    @Test
    func roundTripFullRightBalance() async throws {
        let original = SoundMediaHeaderBox(balance: 1.0)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SoundMediaHeaderBox)
        #expect(parsed.balance == 1.0)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = SoundMediaHeaderBox()
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) + balance(2) + reserved(2) = 16
        let expected = Data(
            hex: """
                00 00 00 10 73 6D 68 64
                00 00 00 00
                00 00
                00 00
                """)
        #expect(writer.data == expected)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 10 73 6D 68 64 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }
}

// MARK: - nmhd

@Suite("NullMediaHeaderBox")
struct NullMediaHeaderBoxTests {

    @Test
    func emptyBody() {
        let box = NullMediaHeaderBox()
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) = 12
        #expect(writer.data.count == 12)
    }

    @Test
    func roundTripDefault() async throws {
        let original = NullMediaHeaderBox()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? NullMediaHeaderBox)
        #expect(parsed == original)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = NullMediaHeaderBox()
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(hex: "00 00 00 0C 6E 6D 68 64 00 00 00 00")
        #expect(writer.data == expected)
    }

    @Test
    func customFlagsPreserved() async throws {
        let original = NullMediaHeaderBox(version: 0, flags: 0x00AB_CDEF)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? NullMediaHeaderBox)
        #expect(parsed.flags == 0x00AB_CDEF)
    }
}

// MARK: - sthd

@Suite("SubtitleMediaHeaderBox")
struct SubtitleMediaHeaderBoxTests {

    @Test
    func emptyBody() {
        let box = SubtitleMediaHeaderBox()
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(writer.data.count == 12)
    }

    @Test
    func roundTripDefault() async throws {
        let original = SubtitleMediaHeaderBox()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SubtitleMediaHeaderBox)
        #expect(parsed == original)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = SubtitleMediaHeaderBox()
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(hex: "00 00 00 0C 73 74 68 64 00 00 00 00")
        #expect(writer.data == expected)
    }

    @Test
    func customFlagsPreserved() async throws {
        let original = SubtitleMediaHeaderBox(version: 0, flags: 0x0012_3456)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SubtitleMediaHeaderBox)
        #expect(parsed.flags == 0x0012_3456)
    }
}
