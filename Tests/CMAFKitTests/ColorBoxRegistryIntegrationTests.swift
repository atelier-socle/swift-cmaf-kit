// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("Color box registry integration")
struct ColorBoxRegistryIntegrationTests {

    @Test
    func registryParsesColrNclx() async throws {
        let box = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709,
                    fullRangeFlag: .limited
                )))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry).first
        #expect(parsed is ColorInformationBox)
    }

    @Test
    func registryParsesMdcv() async throws {
        let box = MasteringDisplayColourVolumeBox(
            metadata: MasteringDisplayColourVolume(
                displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
                displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
                displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
                whitePointX: 15635, whitePointY: 16450,
                maxDisplayMasteringLuminance: 10_000_000,
                minDisplayMasteringLuminance: 50
            ))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry).first
        #expect(parsed is MasteringDisplayColourVolumeBox)
    }

    @Test
    func registryParsesClli() async throws {
        let box = ContentLightLevelBox(
            metadata: ContentLightLevel(
                maxContentLightLevel: 1000,
                maxPicAverageLightLevel: 400
            ))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry).first
        #expect(parsed is ContentLightLevelBox)
    }

    @Test
    func registryParsesDvcC() async throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile8(subProfile: .hdr10Compatible),
            level: .level09,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .hdr10Compatible
        )
        let box = DolbyVisionConfigurationBox(configuration: config)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry).first
        #expect(parsed is DolbyVisionConfigurationBox)
    }

    @Test
    func registryParsesDvvC() async throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile7,
            level: .level09,
            rpuPresent: true, elPresent: true, blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let elConfig = DolbyVisionELConfiguration(configuration: config)
        let box = DolbyVisionELConfigurationBox(elConfiguration: elConfig)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry).first
        #expect(parsed is DolbyVisionELConfigurationBox)
    }

    @Test
    func registryExposesAllFiveBoxTypes() async {
        let registry = await BoxRegistry.defaultRegistry()
        for fourCC: FourCC in ["colr", "mdcv", "clli", "dvcC", "dvvC"] {
            let parser = await registry.parser(for: fourCC)
            #expect(parser != nil, "registry missing \(fourCC)")
        }
    }
}
