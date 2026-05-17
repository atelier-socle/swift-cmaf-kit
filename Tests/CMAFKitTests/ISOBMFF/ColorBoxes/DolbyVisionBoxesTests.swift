// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("DolbyVisionConfigurationBox")
struct DolbyVisionConfigurationBoxTests {

    @Test
    func dvcCRoundTrip() async throws {
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
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DolbyVisionConfigurationBox)
        #expect(parsed == box)
    }

    @Test
    func dvcCBoxSize() {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile5,
            level: .level01,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .nonCompatible
        )
        let box = DolbyVisionConfigurationBox(configuration: config)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // 8 header + 24 body = 32 bytes
        #expect(writer.data.count == 32)
    }

    @Test
    func boxTypeIsDvcC() {
        #expect(DolbyVisionConfigurationBox.boxType == "dvcC")
    }

    @Test
    func profile10_2RoundTripThroughRegistry() async throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile10(subProfile: .sdrCompatible),
            level: .level11,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .sdrCompatible
        )
        let box = DolbyVisionConfigurationBox(configuration: config)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DolbyVisionConfigurationBox)
        if case .profile10(let sub) = parsed.configuration.profile {
            #expect(sub == .sdrCompatible)
        } else {
            Issue.record("Expected profile10")
        }
    }

    @Test
    func equalityForSameInputs() {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile7,
            level: .level06,
            rpuPresent: true, elPresent: true, blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let a = DolbyVisionConfigurationBox(configuration: config)
        let b = DolbyVisionConfigurationBox(configuration: config)
        #expect(a == b)
    }
}

@Suite("DolbyVisionELConfigurationBox")
struct DolbyVisionELConfigurationBoxTests {

    @Test
    func dvvCRoundTrip() async throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile7,
            level: .level09,
            rpuPresent: true, elPresent: true, blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let el = DolbyVisionELConfiguration(configuration: config)
        let box = DolbyVisionELConfigurationBox(elConfiguration: el)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DolbyVisionELConfigurationBox)
        #expect(parsed == box)
    }

    @Test
    func boxTypeIsDvvC() {
        #expect(DolbyVisionELConfigurationBox.boxType == "dvvC")
    }

    @Test
    func dvvCBoxSize() {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile7,
            level: .level01,
            rpuPresent: true, elPresent: true, blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let el = DolbyVisionELConfiguration(configuration: config)
        let box = DolbyVisionELConfigurationBox(elConfiguration: el)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(writer.data.count == 32)
    }

    @Test
    func registryRecognisesDvvC() async throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile7,
            level: .level08,
            rpuPresent: true, elPresent: true, blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let el = DolbyVisionELConfiguration(configuration: config)
        let box = DolbyVisionELConfigurationBox(elConfiguration: el)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        #expect(await registry.parser(for: "dvvC") != nil)
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry).first
        #expect(parsed is DolbyVisionELConfigurationBox)
    }
}
