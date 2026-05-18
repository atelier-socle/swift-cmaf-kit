// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCDecoderConfigurationRecord")
struct HEVCDecoderConfigurationRecordTests {

    private func makeVPS() -> HEVCParameterSet {
        HEVCParameterSet(rbspBytes: Data([0x40, 0x01, 0x0C, 0x01]))
    }
    private func makeSPS() -> HEVCParameterSet {
        HEVCParameterSet(rbspBytes: Data([0x42, 0x01, 0x01, 0x01]))
    }
    private func makePPS() -> HEVCParameterSet {
        HEVCParameterSet(rbspBytes: Data([0x44, 0x01, 0xC0, 0xF3]))
    }

    private func makeRecord(
        levelIDC: HEVCLevelIDC = .level4_1,
        profileIDC: HEVCProfileIDC = .main10,
        chromaFormat: HEVCChromaFormatIDC = .format420,
        bitDepthLuma: UInt8 = 10,
        bitDepthChroma: UInt8 = 10,
        parameterSetArrays: [HEVCParameterSetArray]? = nil
    ) -> HEVCDecoderConfigurationRecord {
        HEVCDecoderConfigurationRecord(
            profileSpace: .zero,
            tierFlag: .main,
            profileIDC: profileIDC,
            profileCompatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0x6000_0000),
            constraintIndicatorFlags: HEVCConstraintIndicatorFlags(
                progressiveSourceFlag: false,
                interlacedSourceFlag: false,
                nonPackedConstraintFlag: false,
                frameOnlyConstraintFlag: false
            ),
            levelIDC: levelIDC,
            minSpatialSegmentationIDC: 0,
            parallelismType: .mixedOrUnknown,
            chromaFormat: chromaFormat,
            bitDepthLuma: bitDepthLuma,
            bitDepthChroma: bitDepthChroma,
            avgFrameRate: 0,
            constantFrameRate: .unknown,
            numTemporalLayers: 1,
            temporalIdNested: true,
            lengthSize: .fourBytes,
            parameterSetArrays: parameterSetArrays ?? [
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .vpsNUT,
                    parameterSets: [makeVPS()]
                ),
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .spsNUT,
                    parameterSets: [makeSPS()]
                ),
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .ppsNUT,
                    parameterSets: [makePPS()]
                )
            ]
        )
    }

    @Test
    func main10RoundTrip() async throws {
        let record = makeRecord()
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCDecoderConfigurationRecord)
        #expect(parsed == record)
    }

    @Test
    func mainProfileRoundTrip() async throws {
        let record = makeRecord(profileIDC: .main, bitDepthLuma: 8, bitDepthChroma: 8)
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCDecoderConfigurationRecord)
        #expect(parsed.profileIDC == .main)
        #expect(parsed.bitDepthLuma == 8)
    }

    @Test
    func tierFlagRoundTrip() async throws {
        let record = HEVCDecoderConfigurationRecord(
            profileSpace: .zero,
            tierFlag: .high,
            profileIDC: .main10,
            profileCompatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0),
            constraintIndicatorFlags: HEVCConstraintIndicatorFlags(
                progressiveSourceFlag: false,
                interlacedSourceFlag: false,
                nonPackedConstraintFlag: false,
                frameOnlyConstraintFlag: false
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
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCDecoderConfigurationRecord)
        #expect(parsed.tierFlag == .high)
    }

    @Test
    func allParallelismTypes() async throws {
        for type: HEVCParallelismType in [.mixedOrUnknown, .slice, .tile, .waveFront] {
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
                parallelismType: type,
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
            var writer = BinaryWriter()
            record.encode(to: &writer)
            let registry = await BoxRegistry.defaultRegistry()
            let reader = ISOBoxReader()
            let boxes = try await reader.readBoxes(from: writer.data, using: registry)
            let parsed = try #require(boxes.first as? HEVCDecoderConfigurationRecord)
            #expect(parsed.parallelismType == type)
        }
    }

    @Test
    func vpsSpsPpsArraysPreserved() async throws {
        let record = makeRecord()
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCDecoderConfigurationRecord)
        #expect(parsed.parameterSetArrays.count == 3)
        #expect(parsed.parameterSetArrays[0].nalUnitType == .vpsNUT)
        #expect(parsed.parameterSetArrays[1].nalUnitType == .spsNUT)
        #expect(parsed.parameterSetArrays[2].nalUnitType == .ppsNUT)
    }

    @Test
    func arrayCompletenessPreserved() async throws {
        let arrays = [
            HEVCParameterSetArray(
                arrayCompleteness: false,
                nalUnitType: .vpsNUT,
                parameterSets: [HEVCParameterSet(rbspBytes: Data([0x40, 0x01]))]
            )
        ]
        let record = makeRecord(parameterSetArrays: arrays)
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCDecoderConfigurationRecord)
        #expect(parsed.parameterSetArrays[0].arrayCompleteness == false)
    }

    @Test
    func bitDepth12Preserved() async throws {
        let record = makeRecord(bitDepthLuma: 12, bitDepthChroma: 12)
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCDecoderConfigurationRecord)
        #expect(parsed.bitDepthLuma == 12)
        #expect(parsed.bitDepthChroma == 12)
    }

    @Test
    func minSpatialSegmentationIDCPreserved() async throws {
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
            minSpatialSegmentationIDC: 0x0ABC,
            parallelismType: .tile,
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
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCDecoderConfigurationRecord)
        #expect(parsed.minSpatialSegmentationIDC == 0x0ABC)
    }

    @Test
    func unknownProfileRejected() async throws {
        let record = makeRecord()
        var writer = BinaryWriter()
        record.encode(to: &writer)
        var bytes = writer.data
        // Profile-byte offset: 8 (box header) + 1 (config version) = 9.
        // Low 5 bits = profile_idc. Patch to 31 (reserved).
        bytes[9] = (bytes[9] & 0xE0) | 31
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func versionMustBeOne() async throws {
        let record = makeRecord()
        var writer = BinaryWriter()
        record.encode(to: &writer)
        var bytes = writer.data
        bytes[8] = 2
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func temporalIdNestedRoundTrips() async throws {
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
            numTemporalLayers: 4,
            temporalIdNested: false,
            lengthSize: .fourBytes,
            parameterSetArrays: []
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? HEVCDecoderConfigurationRecord)
        #expect(parsed.numTemporalLayers == 4)
        #expect(parsed.temporalIdNested == false)
    }
}
