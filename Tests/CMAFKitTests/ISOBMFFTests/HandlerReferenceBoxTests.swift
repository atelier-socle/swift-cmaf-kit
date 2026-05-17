// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for HandlerReferenceBox (hdlr) — ISO/IEC 14496-12 §8.4.3.
// Covers all 7 standard handler types + C-style and Pascal-style name decoding.

import Foundation
import Testing

@testable import CMAFKit

@Suite("HandlerReferenceBox")
struct HandlerReferenceBoxTests {

    @Test
    func roundTripVideoHandler() async throws {
        let original = HandlerReferenceBox(handlerType: HandlerReferenceBox.typeVideo, name: "VideoHandler")
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HandlerReferenceBox)
        #expect(parsed == original)
    }

    @Test
    func handlerTypeConstants() {
        #expect(HandlerReferenceBox.typeVideo == "vide")
        #expect(HandlerReferenceBox.typeAudio == "soun")
        #expect(HandlerReferenceBox.typeSubtitle == "subt")
        #expect(HandlerReferenceBox.typeText == "text")
        #expect(HandlerReferenceBox.typeHint == "hint")
        #expect(HandlerReferenceBox.typeMeta == "meta")
        #expect(HandlerReferenceBox.typeAuxiliaryVideo == "auxv")
    }

    @Test
    func roundTripAllSevenHandlerTypes() async throws {
        let types: [FourCC] = [
            HandlerReferenceBox.typeVideo,
            HandlerReferenceBox.typeAudio,
            HandlerReferenceBox.typeSubtitle,
            HandlerReferenceBox.typeText,
            HandlerReferenceBox.typeHint,
            HandlerReferenceBox.typeMeta,
            HandlerReferenceBox.typeAuxiliaryVideo
        ]
        for handlerType in types {
            let original = HandlerReferenceBox(handlerType: handlerType, name: "Test")
            var writer = BinaryWriter()
            original.encode(to: &writer)
            let registry = await BoxRegistry.defaultRegistry()
            let reader = ISOBoxReader()
            let boxes = try await reader.readBoxes(from: writer.data, using: registry)
            let parsed = try #require(boxes.first as? HandlerReferenceBox)
            #expect(parsed.handlerType == handlerType)
        }
    }

    @Test
    func emptyName() async throws {
        let original = HandlerReferenceBox(handlerType: HandlerReferenceBox.typeVideo, name: "")
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HandlerReferenceBox)
        #expect(parsed.name.isEmpty)
    }

    @Test
    func unicodeName() async throws {
        let original = HandlerReferenceBox(
            handlerType: HandlerReferenceBox.typeAudio,
            name: "Café — øéçà"
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HandlerReferenceBox)
        #expect(parsed.name == "Café — øéçà")
    }

    @Test
    func encoderEmitsCStyleName() {
        let box = HandlerReferenceBox(handlerType: HandlerReferenceBox.typeVideo, name: "Hi")
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + version+flags(4) + preDefined(4) + handlerType(4)
        // + reserved(12) + name "Hi" + NUL = 35 bytes
        // Verify the last 3 bytes are 'H','i',0x00.
        let bytes = Array(writer.data.suffix(3))
        #expect(bytes == [0x48, 0x69, 0x00])
    }

    @Test
    func pascalStyleNameDecoded() throws {
        // Synthesize a hdlr body with Pascal-style name: length(1) + "Audio".
        var pascalBytes = Data()
        pascalBytes.append(0x05)  // length
        pascalBytes.append(contentsOf: "Audio".utf8)
        let decoded = try HandlerReferenceBox.decodeHandlerName(pascalBytes)
        #expect(decoded == "Audio")
    }

    @Test
    func cStyleNameDecoded() throws {
        // C-style: bytes followed by 0x00.
        var bytes = Data()
        bytes.append(contentsOf: "Video".utf8)
        bytes.append(0x00)
        let decoded = try HandlerReferenceBox.decodeHandlerName(bytes)
        #expect(decoded == "Video")
    }

    @Test
    func emptyBufferDecodesToEmpty() throws {
        let decoded = try HandlerReferenceBox.decodeHandlerName(Data())
        #expect(decoded.isEmpty)
    }

    @Test
    func roundTripPreservesFlags() async throws {
        let original = HandlerReferenceBox(
            flags: 0x00AB_CDEF,
            handlerType: HandlerReferenceBox.typeVideo,
            name: ""
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HandlerReferenceBox)
        #expect(parsed.flags == 0x00AB_CDEF)
    }
}
