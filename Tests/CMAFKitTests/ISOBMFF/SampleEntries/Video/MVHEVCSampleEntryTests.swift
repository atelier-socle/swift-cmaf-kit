// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("MVHEVCSampleEntry")
struct MVHEVCSampleEntryTests {

    // MARK: - Fixtures

    private static func makeRecord() -> HEVCDecoderConfigurationRecord {
        MultiLayerHEVCConfigurationTests.minimalHEVCRecord()
    }

    private static func makeVisualFields(
        width: UInt16 = 1920, height: UInt16 = 1080
    ) -> VisualSampleEntryFields {
        VisualSampleEntryFields(width: width, height: height)
    }

    private static func makeVexu() -> ViewExtendedUsageBox {
        ViewExtendedUsageBox(viewIdentifier: 0, usageFlags: 0x01)
    }

    private static func makeStri() -> StereoInformationBox {
        StereoInformationBox(
            stereoArrangement: .stereoLayered,
            interaxialDistanceMillimeters: 63.0
        )
    }

    private static func makeHero() -> HeroEyeInformationBox {
        HeroEyeInformationBox(heroEye: .leftEye)
    }

    private static func makeMVConfig() -> MultiLayerHEVCConfiguration {
        MultiLayerHEVCConfiguration(
            baseLayer: makeRecord(),
            extensionLayer: makeRecord(),
            layerIDs: [0, 1],
            temporalIDs: [0, 0],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: []),
                LayerDependency(layerID: 1, dependsOnLayerIDs: [0])
            ],
            viewIDs: [0, 1],
            outputLayerSetIDs: [0]
        )
    }

    // MARK: - Box type + accessors

    @Test
    func boxTypeIsHvc2() {
        #expect(MVHEVCSampleEntry.boxType == "hvc2")
    }

    @Test
    func multiLayerConfigBoxTypeIsMhcC() {
        #expect(MVHEVCSampleEntry.multiLayerConfigBoxType == "mhcC")
    }

    // MARK: - Round-trip

    @Test
    func roundTripMinimalEntryBaseOnly() async throws {
        let entry = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(),
            hvcCBase: Self.makeRecord(),
            vexu: Self.makeVexu()
        )
        try await assertRoundTrip(entry)
    }

    @Test
    func roundTripWithExtensionLayer() async throws {
        let entry = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(),
            hvcCBase: Self.makeRecord(),
            hvcCExtension: Self.makeRecord(),
            vexu: Self.makeVexu()
        )
        try await assertRoundTrip(entry)
    }

    @Test
    func roundTripStereoFullSet() async throws {
        let entry = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(),
            hvcCBase: Self.makeRecord(),
            hvcCExtension: Self.makeRecord(),
            vexu: Self.makeVexu(),
            stri: Self.makeStri(),
            hero: Self.makeHero()
        )
        try await assertRoundTrip(entry)
    }

    @Test
    func roundTripWithMultiLayerConfig() async throws {
        let entry = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(),
            hvcCBase: Self.makeRecord(),
            hvcCExtension: Self.makeRecord(),
            vexu: Self.makeVexu(),
            stri: Self.makeStri(),
            hero: Self.makeHero(),
            multiLayerConfiguration: Self.makeMVConfig()
        )
        try await assertRoundTrip(entry)
    }

    @Test
    func roundTripWith4KDimensionsForSpatialVideo() async throws {
        let entry = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(width: 4096, height: 2160),
            hvcCBase: Self.makeRecord(),
            vexu: Self.makeVexu(),
            stri: Self.makeStri(),
            hero: Self.makeHero()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry)
        let recovered = try #require(parsed.first as? MVHEVCSampleEntry)
        #expect(recovered.visualFields.width == 4096)
        #expect(recovered.visualFields.height == 2160)
    }

    // MARK: - Error paths

    @Test
    func parseThrowsWhenVexuMissing() async throws {
        // Forge an hvc2 with hvcC but no vexu — Apple HEVC Stereo
        // Video Profile §3.1 requires vexu.
        let visualFields = Self.makeVisualFields()
        let hvcC = Self.makeRecord()

        var writer = BinaryWriter()
        writer.writeBox(type: MVHEVCSampleEntry.boxType) { body in
            visualFields.encode(to: &body)
            hvcC.encode(to: &body)
            // no vexu — should throw
        }

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: MVHEVCSampleEntryError.missingViewExtendedUsage) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func parseThrowsWhenHvcCMissing() async throws {
        // Forge an hvc2 with vexu but no hvcC.
        let visualFields = Self.makeVisualFields()
        let vexu = Self.makeVexu()

        var writer = BinaryWriter()
        writer.writeBox(type: MVHEVCSampleEntry.boxType) { body in
            visualFields.encode(to: &body)
            vexu.encode(to: &body)
        }

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: MVHEVCSampleEntryError.missingBaseHvcC) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func parseThrowsOnThirdHvcC() async throws {
        // Three consecutive hvcC boxes — base + extension allowed, third rejected.
        let visualFields = Self.makeVisualFields()
        let hvcC = Self.makeRecord()
        let vexu = Self.makeVexu()

        var writer = BinaryWriter()
        writer.writeBox(type: MVHEVCSampleEntry.boxType) { body in
            visualFields.encode(to: &body)
            hvcC.encode(to: &body)
            hvcC.encode(to: &body)
            hvcC.encode(to: &body)  // third — boom
            vexu.encode(to: &body)
        }

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: MVHEVCSampleEntryError.unexpectedExtraHvcC) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    // MARK: - BoxRegistry resolution

    @Test
    func boxRegistryResolvesHvc2() async throws {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "hvc2")
        #expect(parser != nil)
    }

    // MARK: - Equatable / Hashable

    @Test
    func equatableSameInput() {
        let entry = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(),
            hvcCBase: Self.makeRecord(),
            vexu: Self.makeVexu()
        )
        let other = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(),
            hvcCBase: Self.makeRecord(),
            vexu: Self.makeVexu()
        )
        #expect(entry == other)
    }

    @Test
    func hashableSameInput() {
        let entry = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(),
            hvcCBase: Self.makeRecord(),
            vexu: Self.makeVexu()
        )
        var hasher = Hasher()
        entry.hash(into: &hasher)
        _ = hasher.finalize()  // smoke: no crash
    }

    @Test
    func equatableDifferentVexu() {
        let a = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(),
            hvcCBase: Self.makeRecord(),
            vexu: ViewExtendedUsageBox(viewIdentifier: 0, usageFlags: 0x01)
        )
        let b = MVHEVCSampleEntry(
            visualFields: Self.makeVisualFields(),
            hvcCBase: Self.makeRecord(),
            vexu: ViewExtendedUsageBox(viewIdentifier: 1, usageFlags: 0x02)
        )
        #expect(a != b)
    }

    // MARK: - Helpers

    private func assertRoundTrip(
        _ entry: MVHEVCSampleEntry,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry)
        let recovered = try #require(
            parsed.first as? MVHEVCSampleEntry,
            "first parsed box is not MVHEVCSampleEntry",
            sourceLocation: sourceLocation
        )
        #expect(recovered == entry, sourceLocation: sourceLocation)
    }
}
