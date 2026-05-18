// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("EncryptedAudioSampleEntry")
struct EncryptedAudioSampleEntryTests {

    @Test
    func emptyChildrenRoundTrip() async throws {
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            opaqueChildren: []
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedAudioSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func opaqueChildrenPreservedRoundTrip() async throws {
        // Build a synthetic child of an unknown FourCC.
        var childBytes = BinaryWriter()
        childBytes.writeBox(type: "frma") { body in
            body.writeFourCC("mp4a")
        }
        var childReader = BinaryReader(childBytes.data)
        let opaque = try ISOBoxOpaque.parse(reader: &childReader)
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            opaqueChildren: [opaque]
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedAudioSampleEntry)
        #expect(parsed.opaqueChildren.count == 1)
        #expect(parsed == entry)
    }

    @Test
    func multipleOpaqueChildrenPreserved() async throws {
        var sinfBytes = BinaryWriter()
        sinfBytes.writeBox(type: "sinf") { body in
            body.writeData(Data(repeating: 0xAA, count: 32))
        }
        var frmaBytes = BinaryWriter()
        frmaBytes.writeBox(type: "frma") { body in
            body.writeFourCC("mp4a")
        }
        var sinfReader = BinaryReader(sinfBytes.data)
        let sinf = try ISOBoxOpaque.parse(reader: &sinfReader)
        var frmaReader = BinaryReader(frmaBytes.data)
        let frma = try ISOBoxOpaque.parse(reader: &frmaReader)
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            opaqueChildren: [sinf, frma]
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedAudioSampleEntry)
        #expect(parsed.opaqueChildren.count == 2)
        #expect(parsed == entry)
    }

    @Test
    func extensionsRoutedSeparately() async throws {
        var sinfBytes = BinaryWriter()
        sinfBytes.writeBox(type: "sinf") { body in
            body.writeData(Data(repeating: 0x00, count: 8))
        }
        var sinfReader = BinaryReader(sinfBytes.data)
        let sinf = try ISOBoxOpaque.parse(reader: &sinfReader)
        let chnl = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .predefined(layout: .stereo, omittedChannelsMap: 0)
        )
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            opaqueChildren: [sinf],
            extensions: AudioSampleEntryExtensions(channelLayout: chnl)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedAudioSampleEntry)
        #expect(parsed.opaqueChildren.count == 1)
        #expect(parsed.extensions.channelLayout == chnl)
    }

    @Test
    func boxTypeIsEnca() {
        #expect(EncryptedAudioSampleEntry.boxType == "enca")
    }
}
