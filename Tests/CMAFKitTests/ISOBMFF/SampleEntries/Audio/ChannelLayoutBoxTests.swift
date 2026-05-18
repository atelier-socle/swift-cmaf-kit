// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ChannelLayoutBox")
struct ChannelLayoutBoxTests {

    @Test
    func predefinedStereoRoundTrip() async throws {
        let box = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .predefined(layout: .stereo, omittedChannelsMap: 0)
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChannelLayoutBox)
        #expect(parsed == box)
    }

    @Test
    func predefinedFiveOneRoundTrip() async throws {
        let box = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .predefined(layout: .fiveOne, omittedChannelsMap: 0)
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChannelLayoutBox)
        #expect(parsed == box)
    }

    @Test
    func predefinedWithOmittedChannelsMap() async throws {
        let box = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .predefined(layout: .sevenOne, omittedChannelsMap: 0x0000_0000_0000_0080)
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChannelLayoutBox)
        #expect(parsed == box)
    }

    @Test
    func explicitPositionsRoundTrip() async throws {
        let positions = [
            ExplicitChannelPosition(speakerPosition: .leftFront),
            ExplicitChannelPosition(speakerPosition: .rightFront)
        ]
        let box = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .explicit(positions: positions)
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChannelLayoutBox)
        #expect(parsed == box)
    }

    @Test
    func explicitWithCustomPositionRoundTrip() async throws {
        let custom = ExplicitChannelPosition.CustomPosition(azimuth: 45, elevation: 10)
        let positions = [
            ExplicitChannelPosition(speakerPosition: .leftFront),
            ExplicitChannelPosition(speakerPosition: .rightFront),
            ExplicitChannelPosition(speakerPosition: .explicit, customPosition: custom)
        ]
        let box = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .explicit(positions: positions)
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChannelLayoutBox)
        #expect(parsed == box)
    }

    @Test
    func negativeAzimuthAndElevation() async throws {
        let custom = ExplicitChannelPosition.CustomPosition(azimuth: -60, elevation: -15)
        let positions = [
            ExplicitChannelPosition(speakerPosition: .explicit, customPosition: custom)
        ]
        let box = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .explicit(positions: positions)
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChannelLayoutBox)
        if case .explicit(let parsedPositions) = parsed.channelLayout {
            #expect(parsedPositions[0].customPosition?.azimuth == -60)
            #expect(parsedPositions[0].customPosition?.elevation == -15)
        } else {
            Issue.record("Expected explicit channel layout")
        }
    }

    @Test
    func objectStructuredOnly() async throws {
        let box = ChannelLayoutBox(
            streamStructure: .objectStructured,
            objectCount: 8
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChannelLayoutBox)
        #expect(parsed == box)
    }

    @Test
    func mixedChannelAndObjectStructured() async throws {
        let box = ChannelLayoutBox(
            streamStructure: [.channelStructured, .objectStructured],
            channelLayout: .predefined(layout: .stereo, omittedChannelsMap: 0),
            objectCount: 4
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChannelLayoutBox)
        #expect(parsed == box)
    }

    @Test
    func boxTypeIsChnl() {
        #expect(ChannelLayoutBox.boxType == "chnl")
    }
}
