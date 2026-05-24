// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("MultiLayerHEVCConfiguration")
struct MultiLayerHEVCConfigurationTests {

    // MARK: - Fixtures

    /// Minimal valid `HEVCDecoderConfigurationRecord` for testing the
    /// multi-layer record's embedded-record carriage.
    static func minimalHEVCRecord(
        levelIDC: HEVCLevelIDC = .level4_1
    ) -> HEVCDecoderConfigurationRecord {
        HEVCDecoderConfigurationRecord(
            profileSpace: .zero,
            tierFlag: .main,
            profileIDC: .main,
            profileCompatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0x6000_0000),
            constraintIndicatorFlags: HEVCConstraintIndicatorFlags(
                progressiveSourceFlag: true,
                interlacedSourceFlag: false,
                nonPackedConstraintFlag: true,
                frameOnlyConstraintFlag: true
            ),
            levelIDC: levelIDC,
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
            parameterSetArrays: [
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .vpsNUT,
                    parameterSets: [HEVCParameterSet(rbspBytes: Data([0x40, 0x01, 0xAA]))]
                ),
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .spsNUT,
                    parameterSets: [HEVCParameterSet(rbspBytes: Data([0x42, 0x01, 0xBB]))]
                ),
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .ppsNUT,
                    parameterSets: [HEVCParameterSet(rbspBytes: Data([0x44, 0x01, 0xCC]))]
                )
            ]
        )
    }

    private static func twoLayerStereoConfig() -> MultiLayerHEVCConfiguration {
        MultiLayerHEVCConfiguration(
            baseLayer: minimalHEVCRecord(),
            extensionLayer: minimalHEVCRecord(),
            layerIDs: [0, 1],
            temporalIDs: [0, 0],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: []),
                LayerDependency(layerID: 1, dependsOnLayerIDs: [0])
            ],
            viewIDs: [0, 1],
            auxIDs: [],
            outputLayerSetIDs: [0]
        )
    }

    private static func threeLayerConfig() -> MultiLayerHEVCConfiguration {
        MultiLayerHEVCConfiguration(
            baseLayer: minimalHEVCRecord(),
            extensionLayer: minimalHEVCRecord(levelIDC: .level5_1),
            layerIDs: [0, 1, 2],
            temporalIDs: [0, 0, 0],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: []),
                LayerDependency(layerID: 1, dependsOnLayerIDs: [0]),
                LayerDependency(layerID: 2, dependsOnLayerIDs: [0, 1])
            ],
            viewIDs: [0, 1, 2],
            auxIDs: [3],
            outputLayerSetIDs: [0, 1]
        )
    }

    // MARK: - Round-trip

    @Test
    func roundTrip2LayerStereo() async throws {
        let original = Self.twoLayerStereoConfig()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let recovered = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        #expect(recovered == original)
    }

    @Test
    func roundTrip3Layer() async throws {
        let original = Self.threeLayerConfig()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let recovered = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        #expect(recovered == original)
    }

    @Test
    func roundTripSingleLayerNoExtension() async throws {
        let original = MultiLayerHEVCConfiguration(
            baseLayer: Self.minimalHEVCRecord(),
            extensionLayer: nil,
            layerIDs: [0],
            temporalIDs: [0],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: [])
            ]
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let recovered = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        #expect(recovered == original)
        #expect(recovered.extensionLayer == nil)
    }

    // MARK: - View / aux / OLS preservation

    @Test
    func viewIDsPreservedRoundTrip() async throws {
        let original = Self.twoLayerStereoConfig()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let recovered = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        #expect(recovered.viewIDs == [0, 1])
    }

    @Test
    func layerDependenciesPreservedRoundTrip() async throws {
        let original = Self.threeLayerConfig()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let recovered = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        // Layer 2 depends on layers 0 and 1
        #expect(recovered.layerDependencies[2].dependsOnLayerIDs == [0, 1])
    }

    @Test
    func outputLayerSetIDsPreservedRoundTrip() async throws {
        let original = Self.threeLayerConfig()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let recovered = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        #expect(recovered.outputLayerSetIDs == [0, 1])
    }

    @Test
    func auxIDsPreservedRoundTrip() async throws {
        let original = Self.threeLayerConfig()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let recovered = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        #expect(recovered.auxIDs == [3])
    }

    // MARK: - Opaque tail preservation

    @Test
    func opaqueTailPreservedRoundTrip() async throws {
        let opaque = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE])
        let original = MultiLayerHEVCConfiguration(
            baseLayer: Self.minimalHEVCRecord(),
            extensionLayer: nil,
            layerIDs: [0],
            temporalIDs: [0],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: [])
            ],
            multiLayerExtensionData: opaque
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let recovered = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        #expect(recovered.multiLayerExtensionData == opaque)
    }

    // MARK: - Error paths

    @Test
    func truncatedRecordThrows() async throws {
        // Just 2 bytes — way smaller than the record header.
        var reader = BinaryReader(Data([0x00, 0x00]))
        await #expect(throws: BinaryIOError.self) {
            _ = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        }
    }

    @Test
    func zeroLayerCountThrows() async throws {
        // Forge a record with size=6, layerCount=0, flags=0
        // → MultiLayerHEVCConfigurationError.missingBaseLayerConfiguration
        let bytes = Data([
            0x00, 0x00, 0x00, 0x06,  // size = 6
            0x00,  // layerCount = 0
            0x00  // flags = 0
        ])
        var reader = BinaryReader(bytes)
        await #expect(
            throws: MultiLayerHEVCConfigurationError.missingBaseLayerConfiguration
        ) {
            _ = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        }
    }

    // MARK: - Equatable / Hashable

    @Test
    func equatableSameInput() {
        let a = Self.twoLayerStereoConfig()
        let b = Self.twoLayerStereoConfig()
        #expect(a == b)
    }

    @Test
    func hashableSameInput() {
        let a = Self.twoLayerStereoConfig()
        let b = Self.twoLayerStereoConfig()
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }

    @Test
    func equatableDifferentLayerCount() {
        let a = Self.twoLayerStereoConfig()
        let b = Self.threeLayerConfig()
        #expect(a != b)
    }

    // MARK: - Embedded record edge cases (coverage lift)

    @Test
    func embeddedRecordTooSmallThrows() async throws {
        // Forge: size=11 valid header, layerCount=1, flags=0, embedded
        // size=2 (< 8-byte hvcC header minimum).
        let bytes = Data([
            0x00, 0x00, 0x00, 0x0B,  // total record size = 11
            0x01,  // layerCount
            0x00,  // flags
            0x00, 0x00, 0x00, 0x02,  // embedded blob size = 2 (invalid)
            0xAA  // (insufficient bytes — but parse hits size check first)
        ])
        var reader = BinaryReader(bytes)
        await #expect(throws: MultiLayerHEVCConfigurationError.self) {
            _ = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        }
    }

    @Test
    func embeddedRecordWrongFourCCThrows() async throws {
        // Forge an embedded blob whose 8-byte header carries the WRONG
        // FourCC ("xxxx" instead of "hvcC"). parseEmbeddedRecord must
        // throw `.malformedRecord`.
        let wrongHeader = Data([
            0x00, 0x00, 0x00, 0x08,  // box size = 8
            0x78, 0x78, 0x78, 0x78  // "xxxx" — not hvcC
        ])
        var blob = Data()
        let blobSize = UInt32(wrongHeader.count).bigEndian
        withUnsafeBytes(of: blobSize) { blob.append(contentsOf: $0) }
        blob.append(wrongHeader)

        let totalSize = UInt32(4 + 1 + 1 + blob.count + 1 + 1 + 1).bigEndian  // size + layerCount + flags + blob + layerID + temporalID + depCount
        var bytes = Data()
        withUnsafeBytes(of: totalSize) { bytes.append(contentsOf: $0) }
        bytes.append(0x01)  // layerCount
        bytes.append(0x00)  // flags
        bytes.append(blob)
        bytes.append(0x00)  // layerIDs[0]
        bytes.append(0x00)  // temporalIDs[0]
        bytes.append(0x00)  // depCount
        var reader = BinaryReader(bytes)
        await #expect(throws: MultiLayerHEVCConfigurationError.self) {
            _ = try await MultiLayerHEVCConfiguration.parse(from: &reader)
        }
    }
}
