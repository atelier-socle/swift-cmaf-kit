// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("EncryptedVideoSampleEntry shell coverage")
struct EncryptedVideoSampleEntryShellCoverageTests {

    private static func makeVisualFields() -> VisualSampleEntryFields {
        VisualSampleEntryFields(width: 1920, height: 1080)
    }

    private static func makeOpaque(fourCC: FourCC, payload: Data = Data()) -> ISOBoxOpaque {
        var w = BinaryWriter()
        w.writeBox(type: fourCC) { body in
            body.writeData(payload)
        }
        return ISOBoxOpaque(boxType: fourCC, rawBytes: w.data)
    }

    @Test
    func singleOpaqueChildRoundTrip() async throws {
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [Self.makeOpaque(fourCC: "sinf")]
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed == entry)
        #expect(parsed.opaqueChildren.count == 1)
    }

    @Test
    func multipleOpaqueChildrenRoundTrip() async throws {
        let children: [ISOBoxOpaque] = [
            Self.makeOpaque(fourCC: "sinf", payload: Data([0x01])),
            Self.makeOpaque(fourCC: "frma", payload: Data([0x02])),
            Self.makeOpaque(fourCC: "schi", payload: Data([0x03]))
        ]
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: children
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.opaqueChildren.count == 3)
        #expect(parsed.opaqueChildren[0].boxType == "sinf")
        #expect(parsed.opaqueChildren[1].boxType == "frma")
        #expect(parsed.opaqueChildren[2].boxType == "schi")
        #expect(parsed == entry)
    }

    @Test
    func withColorInformationExtension() async throws {
        let colr = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709,
                    fullRangeFlag: .full
                )
            )
        )
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [],
            extensions: VideoSampleEntryExtensions(colorInformation: colr)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.extensions.colorInformation == colr)
    }

    @Test
    func withMasteringDisplayExtension() async throws {
        let mdcv = MasteringDisplayColourVolumeBox(
            metadata: MasteringDisplayColourVolume(
                displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
                displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
                displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
                whitePointX: 15635, whitePointY: 16450,
                maxDisplayMasteringLuminance: 10_000_000,
                minDisplayMasteringLuminance: 50
            )
        )
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [],
            extensions: VideoSampleEntryExtensions(masteringDisplay: mdcv)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.extensions.masteringDisplay == mdcv)
    }

    @Test
    func withContentLightLevelExtension() async throws {
        let clli = ContentLightLevelBox(
            metadata: ContentLightLevel(
                maxContentLightLevel: 1000,
                maxPicAverageLightLevel: 400
            )
        )
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [],
            extensions: VideoSampleEntryExtensions(contentLightLevel: clli)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.extensions.contentLightLevel == clli)
    }

    @Test
    func withPixelAspectRatioExtension() async throws {
        let pasp = PixelAspectRatioBox(hSpacing: 1, vSpacing: 1)
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [],
            extensions: VideoSampleEntryExtensions(pixelAspectRatio: pasp)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.extensions.pixelAspectRatio == pasp)
    }

    @Test
    func withBitRateExtension() async throws {
        let btrt = BitRateBox(
            bufferSizeDB: 4096,
            maxBitrate: 25_000_000,
            avgBitrate: 12_000_000
        )
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [],
            extensions: VideoSampleEntryExtensions(bitRate: btrt)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.extensions.bitRate == btrt)
    }

    @Test
    func withMultipleExtensions() async throws {
        let colr = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt2020, transferCharacteristics: .smpteST2084_PQ,
                    matrixCoefficients: .bt2020NCL, fullRangeFlag: .limited
                )
            )
        )
        let mdcv = MasteringDisplayColourVolumeBox(
            metadata: MasteringDisplayColourVolume(
                displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
                displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
                displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
                whitePointX: 15635, whitePointY: 16450,
                maxDisplayMasteringLuminance: 10_000_000,
                minDisplayMasteringLuminance: 50
            )
        )
        let clli = ContentLightLevelBox(
            metadata: ContentLightLevel(
                maxContentLightLevel: 4000,
                maxPicAverageLightLevel: 1000
            )
        )
        let pasp = PixelAspectRatioBox(hSpacing: 1, vSpacing: 1)
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [],
            extensions: VideoSampleEntryExtensions(
                colorInformation: colr,
                masteringDisplay: mdcv,
                contentLightLevel: clli,
                pixelAspectRatio: pasp
            )
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.extensions.colorInformation == colr)
        #expect(parsed.extensions.masteringDisplay == mdcv)
        #expect(parsed.extensions.contentLightLevel == clli)
        #expect(parsed.extensions.pixelAspectRatio == pasp)
    }

}

@Suite("EncryptedVideoSampleEntry shell coverage — apertures and Dolby Vision")
struct EncryptedVideoSampleEntryShellCoverageDolbyTests {

    private static func makeVisualFields() -> VisualSampleEntryFields {
        VisualSampleEntryFields(width: 1920, height: 1080)
    }

    private static func makeOpaque(fourCC: FourCC, payload: Data = Data()) -> ISOBoxOpaque {
        var w = BinaryWriter()
        w.writeBox(type: fourCC) { body in
            body.writeData(payload)
        }
        return ISOBoxOpaque(boxType: fourCC, rawBytes: w.data)
    }

    @Test
    func withCleanApertureExtension() async throws {
        let clap = CleanApertureBox(
            cleanApertureWidthN: 1920, cleanApertureWidthD: 1,
            cleanApertureHeightN: 1080, cleanApertureHeightD: 1,
            horizOffN: 0, horizOffD: 1,
            vertOffN: 0, vertOffD: 1
        )
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [],
            extensions: VideoSampleEntryExtensions(cleanAperture: clap)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.extensions.cleanAperture == clap)
    }

    @Test
    func withDolbyVisionConfigurationExtension() async throws {
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1,
                versionMinor: 0,
                profile: .profile5,
                level: .level05,
                rpuPresent: true,
                elPresent: false,
                blPresent: true,
                blSignalCompatibilityID: .nonCompatible
            )
        )
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [],
            extensions: VideoSampleEntryExtensions(dolbyVisionConfiguration: dvcC)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.extensions.dolbyVisionConfiguration == dvcC)
    }

    @Test
    func withDolbyVisionELConfigurationExtension() async throws {
        let dvvC = DolbyVisionELConfigurationBox(
            elConfiguration: DolbyVisionELConfiguration(
                configuration: DolbyVisionConfiguration(
                    versionMajor: 1, versionMinor: 0,
                    profile: .profile7, level: .level06,
                    rpuPresent: true, elPresent: true, blPresent: false,
                    blSignalCompatibilityID: .nonCompatible
                )
            )
        )
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [],
            extensions: VideoSampleEntryExtensions(dolbyVisionELConfiguration: dvvC)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.extensions.dolbyVisionELConfiguration == dvvC)
    }

    @Test
    func withOpaqueChildrenAndExtensions() async throws {
        let colr = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt709, transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709, fullRangeFlag: .full
                )
            )
        )
        let entry = EncryptedVideoSampleEntry(
            visualFields: Self.makeVisualFields(),
            opaqueChildren: [
                Self.makeOpaque(fourCC: "sinf", payload: Data([0xAA, 0xBB])),
                Self.makeOpaque(fourCC: "frma")
            ],
            extensions: VideoSampleEntryExtensions(colorInformation: colr)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedVideoSampleEntry)
        #expect(parsed.opaqueChildren.count == 2)
        #expect(parsed.extensions.colorInformation == colr)
        #expect(parsed == entry)
    }
}
