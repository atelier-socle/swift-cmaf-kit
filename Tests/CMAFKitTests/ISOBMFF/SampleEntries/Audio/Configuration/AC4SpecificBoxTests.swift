// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AC4SpecificBox")
struct AC4SpecificBoxTests {

    @Test
    func emptyPresentationsRoundTrip() async throws {
        let box = AC4SpecificBox(
            dsiVersion: 1,
            bitstreamVersion: 2,
            presentations: []
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC4SpecificBox)
        #expect(parsed == box)
    }

    @Test
    func singlePresentationRoundTrip() async throws {
        let presentation = AC4SpecificBox.PresentationEntry(
            presentationVersion: 1,
            presentationConfig: 0x20,
            presentationLength: 4,
            presentationBytes: Data([0xDE, 0xAD, 0xBE, 0xEF])
        )
        let box = AC4SpecificBox(
            dsiVersion: 1,
            bitstreamVersion: 2,
            presentations: [presentation]
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC4SpecificBox)
        #expect(parsed == box)
    }

    @Test
    func multiplePresentationsRoundTrip() async throws {
        let presentations = [
            AC4SpecificBox.PresentationEntry(
                presentationVersion: 1,
                presentationConfig: 0x00,
                presentationLength: 2,
                presentationBytes: Data([0x01, 0x02])
            ),
            AC4SpecificBox.PresentationEntry(
                presentationVersion: 2,
                presentationConfig: 0x10,
                presentationLength: 3,
                presentationBytes: Data([0xAA, 0xBB, 0xCC])
            ),
            AC4SpecificBox.PresentationEntry(
                presentationVersion: 1,
                presentationConfig: 0x20,
                presentationLength: 0,
                presentationBytes: Data()
            )
        ]
        let box = AC4SpecificBox(
            dsiVersion: 1,
            bitstreamVersion: 3,
            presentations: presentations
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC4SpecificBox)
        #expect(parsed.presentations.count == 3)
        #expect(parsed == box)
    }

    @Test
    func dsiVersionPreserved() async throws {
        let box = AC4SpecificBox(
            dsiVersion: 5,
            bitstreamVersion: 0,
            presentations: []
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC4SpecificBox)
        #expect(parsed.dsiVersion == 5)
    }

    @Test
    func bitstreamVersionPreserved() async throws {
        let box = AC4SpecificBox(
            dsiVersion: 1,
            bitstreamVersion: 0xFE,
            presentations: []
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AC4SpecificBox)
        #expect(parsed.bitstreamVersion == 0xFE)
    }

    @Test
    func boxTypeIsDac4() {
        #expect(AC4SpecificBox.boxType == "dac4")
    }
}
