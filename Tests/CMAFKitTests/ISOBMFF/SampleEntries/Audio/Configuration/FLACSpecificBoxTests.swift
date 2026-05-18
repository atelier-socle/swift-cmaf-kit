// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("FLACSpecificBox")
struct FLACSpecificBoxTests {

    private static func makeStreamInfoBlock() -> FLACSpecificBox.FLACMetadataBlock {
        let info = FLACStreamInfo(
            minBlockSize: 4096,
            maxBlockSize: 4096,
            minFrameSize: 14,
            maxFrameSize: 4096,
            sampleRate: 48000,
            channels: 2,
            bitsPerSample: 16,
            totalSamples: 480_000,
            md5: Data(repeating: 0xAB, count: 16)
        )
        return FLACSpecificBox.FLACMetadataBlock(
            isLast: true,
            blockType: .streamInfo,
            blockData: info.encode()
        )
    }

    @Test
    func streamInfoOnlyRoundTrip() async throws {
        let box = FLACSpecificBox(metadataBlocks: [Self.makeStreamInfoBlock()])
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FLACSpecificBox)
        #expect(parsed == box)
    }

    @Test
    func multipleBlocksRoundTrip() async throws {
        let streamInfo = FLACSpecificBox.FLACMetadataBlock(
            isLast: false,
            blockType: .streamInfo,
            blockData: FLACStreamInfo(
                minBlockSize: 4096, maxBlockSize: 4096,
                minFrameSize: 14, maxFrameSize: 4096,
                sampleRate: 48000, channels: 2, bitsPerSample: 16,
                totalSamples: 0, md5: Data(repeating: 0, count: 16)
            ).encode()
        )
        let padding = FLACSpecificBox.FLACMetadataBlock(
            isLast: false,
            blockType: .padding,
            blockData: Data(repeating: 0, count: 64)
        )
        let vorbisComment = FLACSpecificBox.FLACMetadataBlock(
            isLast: true,
            blockType: .vorbisComment,
            blockData: Data([0x04, 0x00, 0x00, 0x00]) + Data("test".utf8)
                + Data([0x00, 0x00, 0x00, 0x00])
        )
        let box = FLACSpecificBox(metadataBlocks: [streamInfo, padding, vorbisComment])
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FLACSpecificBox)
        #expect(parsed.metadataBlocks.count == 3)
        #expect(parsed == box)
    }

    @Test
    func streamInfoAccessorReturnsDecodedValue() {
        let box = FLACSpecificBox(metadataBlocks: [Self.makeStreamInfoBlock()])
        let info = box.streamInfo
        #expect(info?.sampleRate == 48000)
        #expect(info?.channels == 2)
        #expect(info?.bitsPerSample == 16)
    }

    @Test
    func isLastFlagPreserved() async throws {
        let block = FLACSpecificBox.FLACMetadataBlock(
            isLast: true,
            blockType: .streamInfo,
            blockData: FLACStreamInfo(
                minBlockSize: 4096, maxBlockSize: 4096,
                minFrameSize: 14, maxFrameSize: 4096,
                sampleRate: 48000, channels: 2, bitsPerSample: 16,
                totalSamples: 0, md5: Data(repeating: 0, count: 16)
            ).encode()
        )
        let box = FLACSpecificBox(metadataBlocks: [block])
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FLACSpecificBox)
        #expect(parsed.metadataBlocks.first?.isLast == true)
    }

    @Test
    func boxTypeIsDfLa() {
        #expect(FLACSpecificBox.boxType == "dfLa")
    }
}
