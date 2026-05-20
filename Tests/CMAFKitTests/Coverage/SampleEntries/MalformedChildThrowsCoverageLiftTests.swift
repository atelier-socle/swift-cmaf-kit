// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for the malformed-child throw paths in the audio
// and video sample-entry parsers. Each parser checks the FourCC
// of its expected child and throws when the child mismatch
// occurs; the happy path is exercised by the codec sweep but the
// throw path requires a hand-crafted malformed input.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Sample-entry malformed-child throws — coverage lift")
struct MalformedChildThrowsCoverageLiftTests {

    // Build a sample entry: 8-byte sample-entry preamble + 6-byte
    // reserved + 2-byte data_reference_index, then 20 bytes of
    // audio fields (channelCount/sampleSize/etc.) per
    // ISO 14496-12, then a bogus child box that the parser is
    // expected to reject.
    private static func malformedAudioEntryBytes(
        outerType: FourCC,
        bogusChild: FourCC
    ) -> Data {
        var writer = BinaryWriter()
        writer.writeBox(type: outerType) { body in
            // 8 bytes: reserved (6) + data_reference_index (2)
            for _ in 0..<6 { body.writeUInt8(0) }
            body.writeUInt16(1)
            // 20 bytes of AudioSampleEntry fields per
            // ISO 14496-12 §8.5.2.2.
            body.writeUInt32(0)
            body.writeUInt32(0)
            body.writeUInt16(2)  // channelCount
            body.writeUInt16(16)  // sampleSize
            body.writeUInt16(0)
            body.writeUInt16(0)
            body.writeUInt32(48_000 << 16)  // sampleRate
            // A bogus child of size 8 (header only).
            body.writeBox(type: bogusChild) { _ in }
        }
        return writer.data
    }

    private func attemptParse(_ data: Data) async throws -> any ISOBox {
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: data, using: registry)
        return try #require(boxes.first)
    }

    @Test
    func mp4aWithWrongChildThrows() async {
        let bytes = Self.malformedAudioEntryBytes(
            outerType: "mp4a", bogusChild: "xxxx"
        )
        await #expect(throws: ISOBoxError.self) {
            _ = try await self.attemptParse(bytes)
        }
    }

    @Test
    func ac3WithWrongChildThrows() async {
        let bytes = Self.malformedAudioEntryBytes(
            outerType: "ac-3", bogusChild: "xxxx"
        )
        await #expect(throws: ISOBoxError.self) {
            _ = try await self.attemptParse(bytes)
        }
    }

    @Test
    func ec3WithWrongChildThrows() async {
        let bytes = Self.malformedAudioEntryBytes(
            outerType: "ec-3", bogusChild: "xxxx"
        )
        await #expect(throws: ISOBoxError.self) {
            _ = try await self.attemptParse(bytes)
        }
    }

    @Test
    func ac4WithWrongChildThrows() async {
        let bytes = Self.malformedAudioEntryBytes(
            outerType: "ac-4", bogusChild: "xxxx"
        )
        await #expect(throws: ISOBoxError.self) {
            _ = try await self.attemptParse(bytes)
        }
    }

    @Test
    func opusWithWrongChildThrows() async {
        let bytes = Self.malformedAudioEntryBytes(
            outerType: "Opus", bogusChild: "xxxx"
        )
        await #expect(throws: ISOBoxError.self) {
            _ = try await self.attemptParse(bytes)
        }
    }

    @Test
    func flacWithWrongChildThrows() async {
        let bytes = Self.malformedAudioEntryBytes(
            outerType: "fLaC", bogusChild: "xxxx"
        )
        await #expect(throws: ISOBoxError.self) {
            _ = try await self.attemptParse(bytes)
        }
    }
}
