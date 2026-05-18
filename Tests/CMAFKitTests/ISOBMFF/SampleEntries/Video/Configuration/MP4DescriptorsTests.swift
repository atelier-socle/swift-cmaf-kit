// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit
@Suite("MP4ObjectTypeIndication")
struct MP4ObjectTypeIndicationTests {

    @Test
    func avcIs0x21() {
        #expect(MP4ObjectTypeIndication.visualISO14496_10.rawValue == 0x21)
    }

    @Test
    func hevcIs0x23() {
        #expect(MP4ObjectTypeIndication.visualISO23008_2.rawValue == 0x23)
    }

    @Test
    func aacIs0x40() {
        #expect(MP4ObjectTypeIndication.audioISO14496_3.rawValue == 0x40)
    }

    @Test
    func unknownValueRejected() {
        #expect(MP4ObjectTypeIndication(rawValue: 0xEE) == nil)
    }

    @Test
    func mpeg4VisualIs0x20() {
        #expect(MP4ObjectTypeIndication.visualISO14496_2.rawValue == 0x20)
    }

    @Test
    func privateAudio0xC0() {
        #expect(MP4ObjectTypeIndication.privateAudio.rawValue == 0xC0)
    }
}

@Suite("MP4StreamType")
struct MP4StreamTypeTests {

    @Test
    func visualStreamIsFour() {
        #expect(MP4StreamType.visualStream.rawValue == 4)
    }

    @Test
    func audioStreamIsFive() {
        #expect(MP4StreamType.audioStream.rawValue == 5)
    }

    @Test
    func elevenCases() {
        #expect(MP4StreamType.allCases.count == 11)
    }

    @Test
    func unknownRejected() {
        #expect(MP4StreamType(rawValue: 99) == nil)
    }
}

@Suite("ElementaryStreamDescriptor")
struct ElementaryStreamDescriptorTests {

    @Test
    func aacRoundTrip() async throws {
        let dsi = Data([0x12, 0x10])
        let decoder = ElementaryStreamDescriptor.DecoderConfigDescriptor(
            objectTypeIndication: .audioISO14496_3,
            streamType: .audioStream,
            upStream: false,
            bufferSizeDB: 1536,
            maxBitrate: 192_000,
            avgBitrate: 128_000,
            decoderSpecificInfo: dsi
        )
        let esds = ElementaryStreamDescriptor(
            esID: 1,
            decoderConfig: decoder
        )
        var writer = BinaryWriter()
        esds.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ElementaryStreamDescriptor)
        #expect(parsed.esID == 1)
        #expect(parsed.decoderConfig.objectTypeIndication == .audioISO14496_3)
        #expect(parsed.decoderConfig.streamType == .audioStream)
        #expect(parsed.decoderConfig.maxBitrate == 192_000)
        #expect(parsed.decoderConfig.avgBitrate == 128_000)
        #expect(parsed.decoderConfig.decoderSpecificInfo == dsi)
    }

    @Test
    func mp4VisualRoundTrip() async throws {
        let decoder = ElementaryStreamDescriptor.DecoderConfigDescriptor(
            objectTypeIndication: .visualISO14496_2,
            streamType: .visualStream,
            upStream: false,
            bufferSizeDB: 0,
            maxBitrate: 1_000_000,
            avgBitrate: 500_000,
            decoderSpecificInfo: nil
        )
        let esds = ElementaryStreamDescriptor(
            esID: 2,
            decoderConfig: decoder
        )
        var writer = BinaryWriter()
        esds.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ElementaryStreamDescriptor)
        #expect(parsed.decoderConfig.objectTypeIndication == .visualISO14496_2)
        #expect(parsed.decoderConfig.decoderSpecificInfo == nil)
    }

    @Test
    func streamPriorityPreserved() async throws {
        let decoder = ElementaryStreamDescriptor.DecoderConfigDescriptor(
            objectTypeIndication: .audioISO14496_3,
            streamType: .audioStream,
            upStream: false,
            bufferSizeDB: 0,
            maxBitrate: 0,
            avgBitrate: 0,
            decoderSpecificInfo: nil
        )
        let esds = ElementaryStreamDescriptor(
            esID: 1,
            streamPriority: 17,
            decoderConfig: decoder
        )
        var writer = BinaryWriter()
        esds.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ElementaryStreamDescriptor)
        #expect(parsed.streamPriority == 17)
    }

    @Test
    func slConfigPredefinedIs2() async throws {
        let decoder = ElementaryStreamDescriptor.DecoderConfigDescriptor(
            objectTypeIndication: .audioISO14496_3,
            streamType: .audioStream,
            upStream: false,
            bufferSizeDB: 0,
            maxBitrate: 0,
            avgBitrate: 0,
            decoderSpecificInfo: nil
        )
        let esds = ElementaryStreamDescriptor(
            esID: 1,
            decoderConfig: decoder,
            slConfig: ElementaryStreamDescriptor.SLConfigDescriptor(predefined: 2)
        )
        var writer = BinaryWriter()
        esds.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ElementaryStreamDescriptor)
        #expect(parsed.slConfig.predefined == 2)
    }

    @Test
    func unknownObjectTypeRejected() async throws {
        let decoder = ElementaryStreamDescriptor.DecoderConfigDescriptor(
            objectTypeIndication: .audioISO14496_3,
            streamType: .audioStream,
            upStream: false,
            bufferSizeDB: 0,
            maxBitrate: 0,
            avgBitrate: 0,
            decoderSpecificInfo: nil
        )
        let esds = ElementaryStreamDescriptor(
            esID: 1,
            decoderConfig: decoder
        )
        var writer = BinaryWriter()
        esds.encode(to: &writer)
        var bytes = writer.data
        // Find the DecoderConfigDescriptor object-type-indication byte.
        // Layout: 8 (box) + 4 (ver+flags) + 1 (es tag) + 4 (BER length)
        //   + 2 (esID) + 1 (es flags+priority)
        //   + 1 (decoder tag) + 4 (BER length) + 1 byte = offset 26.
        let otiOffset = 8 + 4 + 1 + 4 + 2 + 1 + 1 + 4
        bytes[otiOffset] = 0xEE  // unknown object-type-indication
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}
