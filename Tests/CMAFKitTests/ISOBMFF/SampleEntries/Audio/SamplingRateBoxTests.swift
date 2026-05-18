// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("SamplingRateBox")
struct SamplingRateBoxTests {

    @Test
    func standard48kRoundTrip() async throws {
        let box = SamplingRateBox(samplingRate: 48000)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SamplingRateBox)
        #expect(parsed == box)
    }

    @Test
    func ninetySixKHzRoundTrip() async throws {
        let box = SamplingRateBox(samplingRate: 96000)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SamplingRateBox)
        #expect(parsed.samplingRate == 96000)
    }

    @Test
    func maxSamplingRateRoundTrip() async throws {
        let box = SamplingRateBox(samplingRate: UInt32.max)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SamplingRateBox)
        #expect(parsed.samplingRate == UInt32.max)
    }

    @Test
    func bodyIsTwelveBytesTotal() {
        let box = SamplingRateBox(samplingRate: 48000)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // 8 box header + 4 fullBox version+flags + 4 samplingRate = 16 bytes.
        #expect(writer.data.count == 16)
    }

    @Test
    func rejectsZeroSamplingRate() async throws {
        var box = BinaryWriter()
        box.writeBox(type: "srat") { body in
            body.writeUInt8(0)
            body.writeUInt24(0)
            body.writeUInt32(0)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: box.data, using: registry)
        }
    }

    @Test
    func boxTypeIsSrat() {
        #expect(SamplingRateBox.boxType == "srat")
    }
}
