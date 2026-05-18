// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AVCSampleEntry (avc1)")
struct AVCSampleEntryTests {

    private func makeRecord() -> AVCDecoderConfigurationRecord {
        AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [
                AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))
            ],
            pictureParameterSets: [
                AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))
            ]
        )
    }

    @Test
    func plainRoundTrip() async throws {
        let entry = AVCSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            configuration: makeRecord()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func withColorExtension() async throws {
        let exts = VideoSampleEntryExtensions(
            colorInformation: ColorInformationBox(
                variant: .nclx(
                    NCLXColorInformation(
                        colorPrimaries: .bt709,
                        transferCharacteristics: .bt709,
                        matrixCoefficients: .bt709,
                        fullRangeFlag: .limited
                    )))
        )
        let entry = AVCSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            configuration: makeRecord(),
            extensions: exts
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCSampleEntry)
        #expect(parsed.extensions.colorInformation != nil)
    }

    @Test
    func withPaspExtension() async throws {
        let exts = VideoSampleEntryExtensions(
            pixelAspectRatio: PixelAspectRatioBox(hSpacing: 1, vSpacing: 1)
        )
        let entry = AVCSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            configuration: makeRecord(),
            extensions: exts
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCSampleEntry)
        #expect(parsed.extensions.pixelAspectRatio?.hSpacing == 1)
    }

    @Test
    func withAllExtensions() async throws {
        let exts = VideoSampleEntryExtensions(
            colorInformation: ColorInformationBox(
                variant: .nclx(
                    NCLXColorInformation(
                        colorPrimaries: .bt709,
                        transferCharacteristics: .bt709,
                        matrixCoefficients: .bt709,
                        fullRangeFlag: .limited
                    ))),
            masteringDisplay: MasteringDisplayColourVolumeBox(
                metadata: MasteringDisplayColourVolume(
                    displayPrimaryRedX: 1000, displayPrimaryRedY: 2000,
                    displayPrimaryGreenX: 3000, displayPrimaryGreenY: 4000,
                    displayPrimaryBlueX: 5000, displayPrimaryBlueY: 6000,
                    whitePointX: 7000, whitePointY: 8000,
                    maxDisplayMasteringLuminance: 1_000_000,
                    minDisplayMasteringLuminance: 10
                )),
            contentLightLevel: ContentLightLevelBox(
                metadata: ContentLightLevel(
                    maxContentLightLevel: 1000, maxPicAverageLightLevel: 400
                )),
            pixelAspectRatio: PixelAspectRatioBox(hSpacing: 1, vSpacing: 1),
            cleanAperture: CleanApertureBox(
                cleanApertureWidthN: 1920, cleanApertureWidthD: 1,
                cleanApertureHeightN: 1080, cleanApertureHeightD: 1,
                horizOffN: 0, horizOffD: 1, vertOffN: 0, vertOffD: 1
            ),
            bitRate: BitRateBox(bufferSizeDB: 1000, maxBitrate: 5_000_000, avgBitrate: 2_500_000)
        )
        let entry = AVCSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            configuration: makeRecord(),
            extensions: exts
        )
        var w1 = BinaryWriter()
        entry.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? AVCSampleEntry)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func boxTypeIsAvc1() {
        #expect(AVCSampleEntry.boxType == "avc1")
    }
}

@Suite("AVCSampleEntryInband (avc3)")
struct AVCSampleEntryInbandTests {

    @Test
    func plainRoundTrip() async throws {
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))],
            pictureParameterSets: [AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))]
        )
        let entry = AVCSampleEntryInband(
            visualFields: VisualSampleEntryFields(width: 1280, height: 720),
            configuration: record
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCSampleEntryInband)
        #expect(parsed == entry)
    }

    @Test
    func boxTypeIsAvc3() {
        #expect(AVCSampleEntryInband.boxType == "avc3")
    }
}

@Suite("HEVCSampleEntry (hvc1)")
struct HEVCSampleEntryTests {

    private func makeRecord() -> HEVCDecoderConfigurationRecord {
        HEVCDecoderConfigurationRecord(
            profileSpace: .zero,
            tierFlag: .main,
            profileIDC: .main10,
            profileCompatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0x6000_0000),
            constraintIndicatorFlags: HEVCConstraintIndicatorFlags(
                progressiveSourceFlag: true,
                interlacedSourceFlag: false,
                nonPackedConstraintFlag: false,
                frameOnlyConstraintFlag: true
            ),
            levelIDC: .level4_1,
            minSpatialSegmentationIDC: 0,
            parallelismType: .mixedOrUnknown,
            chromaFormat: .format420,
            bitDepthLuma: 10,
            bitDepthChroma: 10,
            avgFrameRate: 0,
            constantFrameRate: .unknown,
            numTemporalLayers: 1,
            temporalIdNested: true,
            lengthSize: .fourBytes,
            parameterSetArrays: [
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .vpsNUT,
                    parameterSets: [HEVCParameterSet(rbspBytes: Data([0x40, 0x01]))]
                )
            ]
        )
    }

    @Test
    func plainRoundTrip() async throws {
        let entry = HEVCSampleEntry(
            visualFields: VisualSampleEntryFields(width: 3840, height: 2160),
            configuration: makeRecord()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func withHDR10Extensions() async throws {
        let exts = VideoSampleEntryExtensions(
            colorInformation: ColorInformationBox(
                variant: .nclx(
                    NCLXColorInformation(
                        colorPrimaries: .bt2020,
                        transferCharacteristics: .smpteST2084_PQ,
                        matrixCoefficients: .bt2020NCL,
                        fullRangeFlag: .limited
                    ))),
            masteringDisplay: MasteringDisplayColourVolumeBox(
                metadata: MasteringDisplayColourVolume(
                    displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
                    displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
                    displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
                    whitePointX: 15635, whitePointY: 16450,
                    maxDisplayMasteringLuminance: 10_000_000,
                    minDisplayMasteringLuminance: 50
                )),
            contentLightLevel: ContentLightLevelBox(
                metadata: ContentLightLevel(
                    maxContentLightLevel: 4000, maxPicAverageLightLevel: 1000
                ))
        )
        let entry = HEVCSampleEntry(
            visualFields: VisualSampleEntryFields(width: 3840, height: 2160),
            configuration: makeRecord(),
            extensions: exts
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCSampleEntry)
        #expect(parsed.extensions.colorInformation != nil)
        #expect(parsed.extensions.masteringDisplay != nil)
        #expect(parsed.extensions.contentLightLevel?.metadata.maxContentLightLevel == 4000)
    }

    @Test
    func boxTypeIsHvc1() {
        #expect(HEVCSampleEntry.boxType == "hvc1")
    }
}

@Suite("HEVCSampleEntryInband (hev1)")
struct HEVCSampleEntryInbandTests {

    @Test
    func plainRoundTrip() async throws {
        let record = HEVCDecoderConfigurationRecord(
            profileSpace: .zero,
            tierFlag: .main,
            profileIDC: .main,
            profileCompatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0),
            constraintIndicatorFlags: HEVCConstraintIndicatorFlags(
                progressiveSourceFlag: false,
                interlacedSourceFlag: false,
                nonPackedConstraintFlag: false,
                frameOnlyConstraintFlag: false
            ),
            levelIDC: .level3,
            minSpatialSegmentationIDC: 0,
            parallelismType: .mixedOrUnknown,
            chromaFormat: .format420,
            bitDepthLuma: 8,
            bitDepthChroma: 8,
            avgFrameRate: 0,
            constantFrameRate: .unknown,
            numTemporalLayers: 1,
            temporalIdNested: true,
            lengthSize: .fourBytes,
            parameterSetArrays: []
        )
        let entry = HEVCSampleEntryInband(
            visualFields: VisualSampleEntryFields(width: 1280, height: 720),
            configuration: record
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCSampleEntryInband)
        #expect(parsed == entry)
    }

    @Test
    func boxTypeIsHev1() {
        #expect(HEVCSampleEntryInband.boxType == "hev1")
    }
}

@Suite("DolbyVisionHEVCSampleEntry (dvh1)")
struct DolbyVisionHEVCSampleEntryTests {

    private func makeHEVCRecord() -> HEVCDecoderConfigurationRecord {
        HEVCDecoderConfigurationRecord(
            profileSpace: .zero,
            tierFlag: .main,
            profileIDC: .main10,
            profileCompatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0x6000_0000),
            constraintIndicatorFlags: HEVCConstraintIndicatorFlags(
                progressiveSourceFlag: true,
                interlacedSourceFlag: false,
                nonPackedConstraintFlag: false,
                frameOnlyConstraintFlag: true
            ),
            levelIDC: .level5_1,
            minSpatialSegmentationIDC: 0,
            parallelismType: .mixedOrUnknown,
            chromaFormat: .format420,
            bitDepthLuma: 10,
            bitDepthChroma: 10,
            avgFrameRate: 0,
            constantFrameRate: .unknown,
            numTemporalLayers: 1,
            temporalIdNested: true,
            lengthSize: .fourBytes,
            parameterSetArrays: []
        )
    }

    @Test
    func profile8_1RoundTrip() async throws {
        let dvConfig = DolbyVisionConfiguration(
            versionMajor: 1,
            versionMinor: 0,
            profile: .profile8(subProfile: .hdr10Compatible),
            level: .level09,
            rpuPresent: true,
            elPresent: false,
            blPresent: true,
            blSignalCompatibilityID: .hdr10Compatible
        )
        let entry = DolbyVisionHEVCSampleEntry(
            visualFields: VisualSampleEntryFields(width: 3840, height: 2160),
            hevcConfiguration: makeHEVCRecord(),
            dolbyVisionConfiguration: dvConfig
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DolbyVisionHEVCSampleEntry)
        #expect(parsed == entry)
    }

    @Test
    func profile7DualLayerRoundTrip() async throws {
        let dvConfig = DolbyVisionConfiguration(
            versionMajor: 1,
            versionMinor: 0,
            profile: .profile7,
            level: .level09,
            rpuPresent: true,
            elPresent: true,
            blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let elConfig = DolbyVisionELConfiguration(configuration: dvConfig)
        let entry = DolbyVisionHEVCSampleEntry(
            visualFields: VisualSampleEntryFields(width: 3840, height: 2160),
            hevcConfiguration: makeHEVCRecord(),
            dolbyVisionConfiguration: dvConfig,
            dolbyVisionELConfiguration: elConfig
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DolbyVisionHEVCSampleEntry)
        #expect(parsed.dolbyVisionELConfiguration != nil)
    }

    @Test
    func missingDvcCThrows() async throws {
        // Encode an HEVC sample entry under the dvh1 FourCC without a dvcC.
        let hevcRecord = makeHEVCRecord()
        var writer = BinaryWriter()
        writer.writeBox(type: "dvh1") { body in
            VisualSampleEntryFields(width: 1920, height: 1080).encode(to: &body)
            hevcRecord.encode(to: &body)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func boxTypeIsDvh1() {
        #expect(DolbyVisionHEVCSampleEntry.boxType == "dvh1")
    }
}

@Suite("DolbyVisionHEVCSampleEntryInband (dvhe)")
struct DolbyVisionHEVCSampleEntryInbandTests {

    @Test
    func profile5RoundTrip() async throws {
        let dvConfig = DolbyVisionConfiguration(
            versionMajor: 1,
            versionMinor: 0,
            profile: .profile5,
            level: .level06,
            rpuPresent: true,
            elPresent: false,
            blPresent: true,
            blSignalCompatibilityID: .nonCompatible
        )
        let record = HEVCDecoderConfigurationRecord(
            profileSpace: .zero,
            tierFlag: .main,
            profileIDC: .main10,
            profileCompatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0),
            constraintIndicatorFlags: HEVCConstraintIndicatorFlags(
                progressiveSourceFlag: false,
                interlacedSourceFlag: false,
                nonPackedConstraintFlag: false,
                frameOnlyConstraintFlag: false
            ),
            levelIDC: .level3,
            minSpatialSegmentationIDC: 0,
            parallelismType: .mixedOrUnknown,
            chromaFormat: .format420,
            bitDepthLuma: 10,
            bitDepthChroma: 10,
            avgFrameRate: 0,
            constantFrameRate: .unknown,
            numTemporalLayers: 1,
            temporalIdNested: true,
            lengthSize: .fourBytes,
            parameterSetArrays: []
        )
        let entry = DolbyVisionHEVCSampleEntryInband(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            hevcConfiguration: record,
            dolbyVisionConfiguration: dvConfig
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DolbyVisionHEVCSampleEntryInband)
        #expect(parsed == entry)
    }

    @Test
    func boxTypeIsDvhe() {
        #expect(DolbyVisionHEVCSampleEntryInband.boxType == "dvhe")
    }
}
