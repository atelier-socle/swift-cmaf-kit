// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("VP8SampleEntry / VP9SampleEntry")
struct VPSampleEntryTests {

    private func makeRecord(profile: VPProfile = .profile0) -> VPCodecConfigurationRecord {
        VPCodecConfigurationRecord(
            profile: profile,
            level: .level40,
            bitDepth: 8,
            chromaSubsampling: .format420Vertical,
            videoFullRangeFlag: .limited,
            colourPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709
        )
    }

    @Test
    func vp9RoundTrip() async throws {
        let entry = VP9SampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            configuration: makeRecord()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? VP9SampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func vp8RoundTrip() async throws {
        let entry = VP8SampleEntry(
            visualFields: VisualSampleEntryFields(width: 640, height: 480),
            configuration: makeRecord()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? VP8SampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func vp9WithExtensions() async throws {
        let exts = VideoSampleEntryExtensions(
            colorInformation: ColorInformationBox(
                variant: .nclx(
                    NCLXColorInformation(
                        colorPrimaries: .bt2020,
                        transferCharacteristics: .bt2020_10bit,
                        matrixCoefficients: .bt2020NCL,
                        fullRangeFlag: .full
                    )))
        )
        let entry = VP9SampleEntry(
            visualFields: VisualSampleEntryFields(width: 3840, height: 2160),
            configuration: makeRecord(profile: .profile2),
            extensions: exts
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? VP9SampleEntry)
        #expect(parsed.extensions.colorInformation != nil)
    }

    @Test
    func vp9BoxTypeIsVp09() {
        #expect(VP9SampleEntry.boxType == "vp09")
    }

    @Test
    func vp8BoxTypeIsVp08() {
        #expect(VP8SampleEntry.boxType == "vp08")
    }
}

@Suite("AV1SampleEntry (av01)")
struct AV1SampleEntryTests {

    @Test
    func mainRoundTrip() async throws {
        let record = AV1CodecConfigurationRecord(
            seqProfile: .main,
            seqLevelIdx0: .level4_0,
            seqTier0: .main,
            highBitdepth: false,
            twelveBit: false,
            monochrome: false,
            chromaSubsamplingX: true,
            chromaSubsamplingY: true,
            chromaSamplePosition: .unknown
        )
        let entry = AV1SampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            configuration: record
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AV1SampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func highBitDepthWithHDR() async throws {
        let record = AV1CodecConfigurationRecord(
            seqProfile: .main,
            seqLevelIdx0: .level5_1,
            seqTier0: .high,
            highBitdepth: true,
            twelveBit: false,
            monochrome: false,
            chromaSubsamplingX: true,
            chromaSubsamplingY: true,
            chromaSamplePosition: .colocated
        )
        let exts = VideoSampleEntryExtensions(
            colorInformation: ColorInformationBox(
                variant: .nclx(
                    NCLXColorInformation(
                        colorPrimaries: .bt2020,
                        transferCharacteristics: .smpteST2084_PQ,
                        matrixCoefficients: .bt2020NCL,
                        fullRangeFlag: .limited
                    )))
        )
        let entry = AV1SampleEntry(
            visualFields: VisualSampleEntryFields(width: 3840, height: 2160),
            configuration: record,
            extensions: exts
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AV1SampleEntry)
        #expect(parsed.configuration.highBitdepth)
        #expect(parsed.extensions.colorInformation != nil)
    }

    @Test
    func boxTypeIsAv01() {
        #expect(AV1SampleEntry.boxType == "av01")
    }
}

@Suite("MP4VisualSampleEntry (mp4v)")
struct MP4VisualSampleEntryTests {

    @Test
    func mpeg4VisualRoundTrip() async throws {
        let decoder = ElementaryStreamDescriptor.DecoderConfigDescriptor(
            objectTypeIndication: .visualISO14496_2,
            streamType: .visualStream,
            upStream: false,
            bufferSizeDB: 4096,
            maxBitrate: 1_000_000,
            avgBitrate: 500_000,
            decoderSpecificInfo: nil
        )
        let esds = ElementaryStreamDescriptor(esID: 1, decoderConfig: decoder)
        let entry = MP4VisualSampleEntry(
            visualFields: VisualSampleEntryFields(width: 720, height: 576),
            elementaryStreamDescriptor: esds
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MP4VisualSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func boxTypeIsMp4v() {
        #expect(MP4VisualSampleEntry.boxType == "mp4v")
    }
}

@Suite("EncryptedVideoSampleEntry (encv)")
struct EncryptedVideoSampleEntryTests {

    @Test
    func emptyOpaqueChildrenRoundTrip() async throws {
        let entry = EncryptedVideoSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            opaqueChildren: []
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func opaqueChildPreserved() async throws {
        // Synthesise a fake `sinf` opaque box: 8-byte header + 0-byte body.
        let sinfBytes = Data([0x00, 0x00, 0x00, 0x08, 0x73, 0x69, 0x6E, 0x66])
        let opaque = ISOBoxOpaque(boxType: "sinf", rawBytes: sinfBytes)
        let entry = EncryptedVideoSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            opaqueChildren: [opaque]
        )
        var w1 = BinaryWriter()
        entry.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.opaqueChildren.count == 1)
        #expect(parsed.opaqueChildren[0].boxType == "sinf")
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func boxTypeIsEncv() {
        #expect(EncryptedVideoSampleEntry.boxType == "encv")
    }
}

@Suite("Video extension boxes")
struct VideoExtensionBoxesTests {

    @Test
    func paspRoundTrip() async throws {
        let box = PixelAspectRatioBox(hSpacing: 16, vSpacing: 9)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? PixelAspectRatioBox)
        #expect(parsed == box)
    }

    @Test
    func clapRoundTrip() async throws {
        let box = CleanApertureBox(
            cleanApertureWidthN: 1920, cleanApertureWidthD: 1,
            cleanApertureHeightN: 1080, cleanApertureHeightD: 1,
            horizOffN: -5, horizOffD: 1, vertOffN: 0, vertOffD: 1
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? CleanApertureBox)
        #expect(parsed == box)
    }

    @Test
    func btrtRoundTrip() async throws {
        let box = BitRateBox(bufferSizeDB: 8192, maxBitrate: 25_000_000, avgBitrate: 10_000_000)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? BitRateBox)
        #expect(parsed == box)
    }

    @Test
    func paspBoxTypeAndSize() {
        let box = PixelAspectRatioBox(hSpacing: 1, vSpacing: 1)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(writer.data.count == 16)  // 8 header + 8 body
        #expect(PixelAspectRatioBox.boxType == "pasp")
    }

    @Test
    func clapBoxTypeAndSize() {
        let box = CleanApertureBox(
            cleanApertureWidthN: 1, cleanApertureWidthD: 1,
            cleanApertureHeightN: 1, cleanApertureHeightD: 1,
            horizOffN: 0, horizOffD: 1, vertOffN: 0, vertOffD: 1
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(writer.data.count == 40)  // 8 header + 32 body
        #expect(CleanApertureBox.boxType == "clap")
    }

    @Test
    func btrtBoxTypeAndSize() {
        let box = BitRateBox(bufferSizeDB: 0, maxBitrate: 0, avgBitrate: 0)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(writer.data.count == 20)  // 8 header + 12 body
        #expect(BitRateBox.boxType == "btrt")
    }
}

@Suite("Video sample-entry registry integration")
struct VideoSampleEntryRegistryTests {

    @Test
    func registryExposesAllSampleEntryFourCCs() async {
        let registry = await BoxRegistry.defaultRegistry()
        let expected: [FourCC] = [
            "avc1", "avc3", "hvc1", "hev1", "dvh1", "dvhe",
            "vp08", "vp09", "av01", "mp4v", "encv",
            "avcC", "hvcC", "vpcC", "av1C", "esds",
            "pasp", "clap", "btrt"
        ]
        for fourCC in expected {
            let parser = await registry.parser(for: fourCC)
            #expect(parser != nil, "registry missing parser for \(fourCC)")
        }
    }
}
