// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCVPSExtension")
struct HEVCVPSExtensionTests {

    // MARK: - Fixtures

    /// 2-layer stereo-pair VPS extension (base + right eye), Apple Vision Pro
    /// Spatial Video shape.
    private static func stereoPair() -> HEVCVPSExtension {
        HEVCVPSExtension(
            maxLayerCount: 2,
            layerIDs: [0, 1],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: []),
                LayerDependency(layerID: 1, dependsOnLayerIDs: [0])
            ],
            scalabilityMask: ScalabilityMask(raw: 0b0000_0000_0000_0010),  // multi-view
            dimensionIDLen: [1],
            dimensionID: [[0], [1]],
            directRefLayers: [[], [0]],
            viewIDValues: [0, 1],
            auxIDValues: [],
            outputLayerSets: [
                OutputLayerSet(layerSetIDx: 0, outputLayerFlags: [true, true])
            ]
        )
    }

    /// 3-layer extension (base + enhancement + auxiliary alpha plane).
    private static func threeLayerWithAlpha() -> HEVCVPSExtension {
        HEVCVPSExtension(
            maxLayerCount: 3,
            layerIDs: [0, 1, 2],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: []),
                LayerDependency(layerID: 1, dependsOnLayerIDs: [0]),
                LayerDependency(layerID: 2, dependsOnLayerIDs: [0, 1])
            ],
            scalabilityMask: ScalabilityMask(raw: 0b0000_0000_0000_1100),  // spatial+aux
            dimensionIDLen: [2, 1],
            dimensionID: [[0, 0], [1, 0], [0, 1]],
            directRefLayers: [[], [0], [0, 1]],
            viewIDValues: [],
            auxIDValues: [1],
            outputLayerSets: [
                OutputLayerSet(layerSetIDx: 0, outputLayerFlags: [true, false, false]),
                OutputLayerSet(layerSetIDx: 1, outputLayerFlags: [true, true, false])
            ]
        )
    }

    // MARK: - Round-trip

    @Test
    func roundTrip2LayerStereoPair() throws {
        let original = Self.stereoPair()
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCVPSExtension.parse(bitstream: &reader)
        #expect(recovered == original)
    }

    @Test
    func roundTrip3LayerWithAuxiliary() throws {
        let original = Self.threeLayerWithAlpha()
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCVPSExtension.parse(bitstream: &reader)
        #expect(recovered == original)
    }

    @Test
    func roundTripSingleBaseLayer() throws {
        let original = HEVCVPSExtension(
            maxLayerCount: 1,
            layerIDs: [0],
            layerDependencies: [LayerDependency(layerID: 0, dependsOnLayerIDs: [])],
            scalabilityMask: ScalabilityMask(raw: 0),
            dimensionIDLen: [],
            dimensionID: [[]],
            directRefLayers: [[]],
            viewIDValues: [],
            auxIDValues: [],
            outputLayerSets: []
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCVPSExtension.parse(bitstream: &reader)
        #expect(recovered == original)
    }

    // MARK: - Scalability mask

    @Test
    func scalabilityMaskMultiViewFlagDecoded() {
        let mask = ScalabilityMask(raw: 0b0000_0000_0000_0010)
        #expect(mask.isMultiview == true)
        #expect(mask.isSpatialQuality == false)
        #expect(mask.isAuxiliary == false)
        #expect(mask.raw == 0b0000_0000_0000_0010)
    }

    @Test
    func scalabilityMaskAuxFlagDecoded() {
        let mask = ScalabilityMask(raw: 0b0000_0000_0000_1000)
        #expect(mask.isMultiview == false)
        #expect(mask.isSpatialQuality == false)
        #expect(mask.isAuxiliary == true)
    }

    @Test
    func scalabilityMaskRawPreservesUnknownBits() throws {
        // Bit 7 (unknown / future) should round-trip via the raw field.
        let mask = ScalabilityMask(raw: 0b0000_0000_1000_0010)
        #expect(mask.isMultiview == true)
        #expect(mask.raw == 0b0000_0000_1000_0010)

        let ext = HEVCVPSExtension(
            maxLayerCount: 1,
            layerIDs: [0],
            layerDependencies: [LayerDependency(layerID: 0, dependsOnLayerIDs: [])],
            scalabilityMask: mask,
            dimensionIDLen: [1, 1],
            dimensionID: [[0, 0]],
            directRefLayers: [[]],
            viewIDValues: [],
            auxIDValues: [],
            outputLayerSets: []
        )
        var writer = BitWriter()
        try ext.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCVPSExtension.parse(bitstream: &reader)
        #expect(recovered.scalabilityMask.raw == mask.raw)
    }

    // MARK: - Output layer sets

    @Test
    func outputLayerSetFlagsRoundTrip() throws {
        let original = Self.threeLayerWithAlpha()
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCVPSExtension.parse(bitstream: &reader)
        #expect(recovered.outputLayerSets.count == 2)
        #expect(recovered.outputLayerSets[0].outputLayerFlags == [true, false, false])
        #expect(recovered.outputLayerSets[1].outputLayerFlags == [true, true, false])
    }

    // MARK: - View IDs

    @Test
    func viewIDValuesRoundTripStereoPair() throws {
        let original = Self.stereoPair()
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCVPSExtension.parse(bitstream: &reader)
        #expect(recovered.viewIDValues == [0, 1])
    }

    // MARK: - Layer dependencies

    @Test
    func layerDependenciesDerivedConsistently() throws {
        let original = Self.threeLayerWithAlpha()
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCVPSExtension.parse(bitstream: &reader)
        // Layer 2 depends on layer 0 and layer 1.
        #expect(recovered.directRefLayers[2] == [0, 1])
        #expect(recovered.layerDependencies[2].dependsOnLayerIDs == [0, 1])
    }

    // MARK: - Error paths

    @Test
    func invalidLayerCountInEncodeThrows() throws {
        let bogus = HEVCVPSExtension(
            maxLayerCount: 1,
            layerIDs: [0],
            layerDependencies: [LayerDependency(layerID: 0, dependsOnLayerIDs: [])],
            scalabilityMask: ScalabilityMask(raw: 0b1),  // 1 bit set, popcount 1
            dimensionIDLen: [],  // mismatched: popcount is 1 but dimensionIDLen.count is 0
            dimensionID: [[]],
            directRefLayers: [[]],
            viewIDValues: [],
            auxIDValues: [],
            outputLayerSets: []
        )
        var writer = BitWriter()
        #expect(throws: HEVCVPSExtensionError.self) {
            try bogus.encode(to: &writer)
        }
    }

    @Test
    func truncatedBitstreamThrows() throws {
        // Only 1 byte — way too short.
        var reader = BitReader(Data([0x00]))
        #expect(throws: BitstreamError.self) {
            _ = try HEVCVPSExtension.parse(bitstream: &reader)
        }
    }

    // MARK: - Equatable / Hashable

    @Test
    func equatableSameInput() {
        let a = Self.stereoPair()
        let b = Self.stereoPair()
        #expect(a == b)
    }

    @Test
    func hashableSameInput() {
        let a = Self.stereoPair()
        let b = Self.stereoPair()
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }

    @Test
    func equatableDifferentLayerCount() {
        let a = Self.stereoPair()
        let b = Self.threeLayerWithAlpha()
        #expect(a != b)
    }
}
