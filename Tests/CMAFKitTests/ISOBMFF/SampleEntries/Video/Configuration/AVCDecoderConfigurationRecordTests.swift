// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AVCDecoderConfigurationRecord")
struct AVCDecoderConfigurationRecordTests {

    private func makeSPS() -> AVCParameterSet {
        // Minimal 4-byte fake SPS NAL: header byte 0x67 = nal_ref_idc=3, type=7 (SPS).
        return AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))
    }

    private func makePPS() -> AVCParameterSet {
        // Minimal 4-byte fake PPS NAL: header byte 0x68 = nal_ref_idc=3, type=8 (PPS).
        return AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))
    }

    @Test
    func baselineRoundTrip() async throws {
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [makeSPS()],
            pictureParameterSets: [makePPS()]
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCDecoderConfigurationRecord)
        #expect(parsed == record)
    }

    @Test
    func highProfileRoundTrip() async throws {
        let hpf = AVCDecoderConfigurationRecord.HighProfileFields(
            chromaFormat: .format420,
            bitDepthLuma: 8,
            bitDepthChroma: 8,
            sequenceParameterSetExtensions: []
        )
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .high,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0x00),
            levelIndication: .level4_1,
            lengthSize: .fourBytes,
            sequenceParameterSets: [makeSPS()],
            pictureParameterSets: [makePPS()],
            highProfileFields: hpf
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCDecoderConfigurationRecord)
        #expect(parsed == record)
    }

    @Test
    func high10ProfileRoundTrip() async throws {
        let hpf = AVCDecoderConfigurationRecord.HighProfileFields(
            chromaFormat: .format420,
            bitDepthLuma: 10,
            bitDepthChroma: 10,
            sequenceParameterSetExtensions: []
        )
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .high10,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0x00),
            levelIndication: .level5,
            lengthSize: .fourBytes,
            sequenceParameterSets: [makeSPS()],
            pictureParameterSets: [makePPS()],
            highProfileFields: hpf
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCDecoderConfigurationRecord)
        #expect(parsed.highProfileFields?.bitDepthLuma == 10)
        #expect(parsed.highProfileFields?.chromaFormat == .format420)
    }

    @Test
    func multipleParameterSetsRoundTrip() async throws {
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .main,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0x40),
            levelIndication: .level4,
            lengthSize: .fourBytes,
            sequenceParameterSets: [makeSPS(), makeSPS()],
            pictureParameterSets: [makePPS(), makePPS(), makePPS()]
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCDecoderConfigurationRecord)
        #expect(parsed.sequenceParameterSets.count == 2)
        #expect(parsed.pictureParameterSets.count == 3)
    }

    @Test
    func lengthSizeFourBytesRoundTrip() async throws {
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [makeSPS()],
            pictureParameterSets: [makePPS()]
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCDecoderConfigurationRecord)
        #expect(parsed.lengthSize == .fourBytes)
    }

    @Test
    func lengthSizeTwoBytesRoundTrip() async throws {
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0),
            levelIndication: .level3,
            lengthSize: .twoBytes,
            sequenceParameterSets: [makeSPS()],
            pictureParameterSets: [makePPS()]
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCDecoderConfigurationRecord)
        #expect(parsed.lengthSize == .twoBytes)
    }

    @Test
    func versionMustBeOne() async throws {
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [makeSPS()],
            pictureParameterSets: [makePPS()]
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        var bytes = writer.data
        // Patch configuration version (offset 8: right after the 8-byte box header) to 2.
        bytes[8] = 2
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func unknownProfileRejected() async throws {
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [makeSPS()],
            pictureParameterSets: [makePPS()]
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        var bytes = writer.data
        bytes[9] = 200  // unknown profile
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func profileCompatibilityPreserved() async throws {
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [makeSPS()],
            pictureParameterSets: [makePPS()]
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCDecoderConfigurationRecord)
        #expect(parsed.profileCompatibility.rawValue == 0xE0)
    }

    @Test
    func highProfileWithSPSExtensions() async throws {
        let spsExt = AVCParameterSet(rbspBytes: Data([0x6D, 0x01, 0x02, 0x03]))
        let hpf = AVCDecoderConfigurationRecord.HighProfileFields(
            chromaFormat: .format422,
            bitDepthLuma: 10,
            bitDepthChroma: 10,
            sequenceParameterSetExtensions: [spsExt]
        )
        let record = AVCDecoderConfigurationRecord(
            profileIndication: .high422,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0),
            levelIndication: .level5_1,
            lengthSize: .fourBytes,
            sequenceParameterSets: [makeSPS()],
            pictureParameterSets: [makePPS()],
            highProfileFields: hpf
        )
        var writer = BinaryWriter()
        record.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? AVCDecoderConfigurationRecord)
        #expect(parsed.highProfileFields?.sequenceParameterSetExtensions.count == 1)
    }
}

@Suite("AVCParameterSet")
struct AVCParameterSetTests {

    @Test
    func nalTypeDecodedFromFirstByte() {
        let sps = AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))
        #expect(sps.nalUnitType == .sequenceParameterSet)
    }

    @Test
    func ppsNalTypeDecoded() {
        let pps = AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))
        #expect(pps.nalUnitType == .pictureParameterSet)
    }

    @Test
    func nalRefIdcDecoded() {
        let sps = AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))
        #expect(sps.nalRefIdc == 3)
    }

    @Test
    func rbspPreservedVerbatim() {
        let bytes = Data([0x67, 0x42, 0xC0, 0x1E, 0x89, 0xAB, 0xCD])
        let sps = AVCParameterSet(rbspBytes: bytes)
        #expect(sps.rbspBytes == bytes)
    }

    @Test
    func equatableHashable() {
        let a = AVCParameterSet(rbspBytes: Data([0x67, 0x42]))
        let b = AVCParameterSet(rbspBytes: Data([0x67, 0x42]))
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}

@Suite("NALLengthSize")
struct NALLengthSizeTests {

    @Test
    func fourBytesMapsToThreeOnWire() {
        #expect(NALLengthSize.fourBytes.lengthSizeMinusOne == 3)
    }

    @Test
    func oneByteMapsToZero() {
        #expect(NALLengthSize.oneByte.lengthSizeMinusOne == 0)
    }

    @Test
    func twoBytesMapsToOne() {
        #expect(NALLengthSize.twoBytes.lengthSizeMinusOne == 1)
    }

    @Test
    func parseRejectsReservedValue2() async throws {
        #expect(throws: ISOBoxError.self) {
            _ = try NALLengthSize(lengthSizeMinusOne: 2)
        }
    }

    @Test
    func parseValidValues() throws {
        #expect(try NALLengthSize(lengthSizeMinusOne: 0) == .oneByte)
        #expect(try NALLengthSize(lengthSizeMinusOne: 1) == .twoBytes)
        #expect(try NALLengthSize(lengthSizeMinusOne: 3) == .fourBytes)
    }
}
