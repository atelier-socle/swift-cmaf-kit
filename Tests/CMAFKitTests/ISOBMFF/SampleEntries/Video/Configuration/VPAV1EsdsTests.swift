// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("VPProfile")
struct VPProfileTests {

    @Test
    func profile0IsZero() {
        #expect(VPProfile.profile0.rawValue == 0)
    }

    @Test
    func profile3IsThree() {
        #expect(VPProfile.profile3.rawValue == 3)
    }

    @Test
    func fourCases() {
        #expect(VPProfile.allCases.count == 4)
    }

    @Test
    func unknownRejected() {
        #expect(VPProfile(rawValue: 5) == nil)
    }
}

@Suite("VPLevel")
struct VPLevelTests {

    @Test
    func level10IsTen() {
        #expect(VPLevel.level10.rawValue == 10)
    }

    @Test
    func level52IsFiftyTwo() {
        #expect(VPLevel.level52.rawValue == 52)
    }

    @Test
    func level62IsSixtyTwo() {
        #expect(VPLevel.level62.rawValue == 62)
    }

    @Test
    func fourteenCases() {
        #expect(VPLevel.allCases.count == 14)
    }

    @Test
    func unknownRejected() {
        #expect(VPLevel(rawValue: 99) == nil)
    }

    @Test
    func level40IsForty() {
        #expect(VPLevel.level40.rawValue == 40)
    }
}

@Suite("VPChromaSubsampling")
struct VPChromaSubsamplingTests {

    @Test
    func format420VerticalIsZero() {
        #expect(VPChromaSubsampling.format420Vertical.rawValue == 0)
    }

    @Test
    func format444IsThree() {
        #expect(VPChromaSubsampling.format444.rawValue == 3)
    }

    @Test
    func fourCases() {
        #expect(VPChromaSubsampling.allCases.count == 4)
    }

    @Test
    func unknownRejected() {
        #expect(VPChromaSubsampling(rawValue: 4) == nil)
    }
}

@Suite("VPCodecConfigurationRecord")
struct VPCodecConfigurationRecordTests {

    @Test
    func vp9Profile0RoundTrip() async throws {
        let record = VPCodecConfigurationRecord(
            profile: .profile0,
            level: .level40,
            bitDepth: 8,
            chromaSubsampling: .format420Vertical,
            videoFullRangeFlag: .limited,
            colourPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? VPCodecConfigurationRecord)
        #expect(parsed == record)
    }

    @Test
    func vp9Profile2BitDepth10RoundTrip() async throws {
        let record = VPCodecConfigurationRecord(
            profile: .profile2,
            level: .level50,
            bitDepth: 10,
            chromaSubsampling: .format420Colocated,
            videoFullRangeFlag: .full,
            colourPrimaries: .bt2020,
            transferCharacteristics: .smpteST2084_PQ,
            matrixCoefficients: .bt2020NCL
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? VPCodecConfigurationRecord)
        #expect(parsed.bitDepth == 10)
        #expect(parsed.videoFullRangeFlag == .full)
        #expect(parsed.transferCharacteristics == .smpteST2084_PQ)
    }

    @Test
    func vp9Profile3BitDepth12RoundTrip() async throws {
        let record = VPCodecConfigurationRecord(
            profile: .profile3,
            level: .level51,
            bitDepth: 12,
            chromaSubsampling: .format444,
            videoFullRangeFlag: .limited,
            colourPrimaries: .bt2020,
            transferCharacteristics: .bt2020_12bit,
            matrixCoefficients: .bt2020NCL
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? VPCodecConfigurationRecord)
        #expect(parsed.bitDepth == 12)
        #expect(parsed.chromaSubsampling == .format444)
    }

    @Test
    func vp8Profile0RoundTrip() async throws {
        let record = VPCodecConfigurationRecord(
            profile: .profile0,
            level: .level30,
            bitDepth: 8,
            chromaSubsampling: .format420Vertical,
            videoFullRangeFlag: .limited,
            colourPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? VPCodecConfigurationRecord)
        #expect(parsed == record)
    }

    @Test
    func unknownProfileRejected() async throws {
        let record = VPCodecConfigurationRecord(
            profile: .profile0,
            level: .level40,
            bitDepth: 8,
            chromaSubsampling: .format420Vertical,
            videoFullRangeFlag: .limited,
            colourPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        var bytes = writer.data
        // Profile byte is at offset 8 (box header) + 4 (full-box ver+flags) = 12.
        bytes[12] = 99
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}

@Suite("AV1Profile")
struct AV1ProfileTests {

    @Test
    func mainIsZero() {
        #expect(AV1Profile.main.rawValue == 0)
    }

    @Test
    func professionalIsTwo() {
        #expect(AV1Profile.professional.rawValue == 2)
    }

    @Test
    func threeCases() {
        #expect(AV1Profile.allCases.count == 3)
    }
}

@Suite("AV1Level")
struct AV1LevelTests {

    @Test
    func level2_0IsZero() {
        #expect(AV1Level.level2_0.rawValue == 0)
    }

    @Test
    func level5_1IsThirteen() {
        #expect(AV1Level.level5_1.rawValue == 13)
    }

    @Test
    func level7_3IsTwentyThree() {
        #expect(AV1Level.level7_3.rawValue == 23)
    }

    @Test
    func maximumIs31() {
        #expect(AV1Level.maximum.rawValue == 31)
    }

    @Test
    func reservedRangeRejected() {
        #expect(AV1Level(rawValue: 24) == nil)
        #expect(AV1Level(rawValue: 30) == nil)
    }

    @Test
    func count25() {
        // 24 levels + maximum.
        #expect(AV1Level.allCases.count == 25)
    }
}

@Suite("AV1Tier")
struct AV1TierTests {

    @Test
    func mainIsZero() {
        #expect(AV1Tier.main.rawValue == 0)
    }

    @Test
    func highIsOne() {
        #expect(AV1Tier.high.rawValue == 1)
    }

    @Test
    func twoCases() {
        #expect(AV1Tier.allCases.count == 2)
    }
}

@Suite("AV1ChromaSamplePosition")
struct AV1ChromaSamplePositionTests {

    @Test
    func unknownIsZero() {
        #expect(AV1ChromaSamplePosition.unknown.rawValue == 0)
    }

    @Test
    func colocatedIsTwo() {
        #expect(AV1ChromaSamplePosition.colocated.rawValue == 2)
    }

    @Test
    func fourCases() {
        #expect(AV1ChromaSamplePosition.allCases.count == 4)
    }
}

@Suite("AV1CodecConfigurationRecord")
struct AV1CodecConfigurationRecordTests {

    @Test
    func main8bitRoundTrip() async throws {
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
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AV1CodecConfigurationRecord)
        #expect(parsed == record)
    }

    @Test
    func main10bitRoundTrip() async throws {
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
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AV1CodecConfigurationRecord)
        #expect(parsed.highBitdepth)
        #expect(parsed.seqTier0 == .high)
    }

    @Test
    func professional12bitRoundTrip() async throws {
        let record = AV1CodecConfigurationRecord(
            seqProfile: .professional,
            seqLevelIdx0: .level6_0,
            seqTier0: .main,
            highBitdepth: true,
            twelveBit: true,
            monochrome: false,
            chromaSubsamplingX: false,
            chromaSubsamplingY: false,
            chromaSamplePosition: .colocated
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AV1CodecConfigurationRecord)
        #expect(parsed.twelveBit)
        #expect(parsed.seqProfile == .professional)
    }

    @Test
    func initialPresentationDelayRoundTrip() async throws {
        let record = AV1CodecConfigurationRecord(
            seqProfile: .main,
            seqLevelIdx0: .level4_0,
            seqTier0: .main,
            highBitdepth: false,
            twelveBit: false,
            monochrome: false,
            chromaSubsamplingX: true,
            chromaSubsamplingY: true,
            chromaSamplePosition: .unknown,
            initialPresentationDelayMinusOne: 7
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AV1CodecConfigurationRecord)
        #expect(parsed.initialPresentationDelayMinusOne == 7)
    }

    @Test
    func configOBUsRoundTrip() async throws {
        let obus = Data([0x0A, 0x0B, 0x0C, 0x0D])
        let record = AV1CodecConfigurationRecord(
            seqProfile: .main,
            seqLevelIdx0: .level4_0,
            seqTier0: .main,
            highBitdepth: false,
            twelveBit: false,
            monochrome: false,
            chromaSubsamplingX: true,
            chromaSubsamplingY: true,
            chromaSamplePosition: .unknown,
            configOBUs: obus
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AV1CodecConfigurationRecord)
        #expect(parsed.configOBUs == obus)
    }

    @Test
    func markerMustBeSet() async throws {
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
        var writer = BinaryWriter()
        record.encode(to: &writer)
        var bytes = writer.data
        // marker/version byte at offset 8.
        bytes[8] = 0x01  // marker=0, version=1 — invalid
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}
