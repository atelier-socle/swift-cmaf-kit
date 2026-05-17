// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCSignatureType")
struct ICCSignatureTypeTests {

    @Test
    func roundTrip() throws {
        let original = ICCSignatureType(signature: 0x7363_6E72)
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCSignatureType.parsePayload(reader: &reader, byteCount: 4)
        #expect(decoded == original)
    }

    @Test
    func zeroSignatureRoundTrip() throws {
        let original = ICCSignatureType(signature: 0)
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCSignatureType.parsePayload(reader: &reader, byteCount: 4)
        #expect(decoded == original)
    }

    @Test
    func isFourBytesOnWire() {
        let s = ICCSignatureType(signature: 0xDEAD_BEEF)
        var writer = BinaryWriter()
        s.encodePayload(to: &writer)
        #expect(writer.data.count == 4)
    }

    @Test
    func hashable() {
        let a = ICCSignatureType(signature: 0x1234)
        let b = ICCSignatureType(signature: 0x1234)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}

@Suite("ICCMeasurementType")
struct ICCMeasurementTypeTests {

    @Test
    func roundTrip() throws {
        let original = ICCMeasurementType(
            standardObserver: .cie1931_2deg,
            backingMeasurement: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.9642),
                y: ICCS15Fixed16Number(1.0),
                z: ICCS15Fixed16Number(0.8249)
            ),
            measurementGeometry: .zeroDegree_45OrFortyFiveDegree_0,
            measurementFlare: ICCU16Fixed16Number(0.01),
            standardIlluminant: .d50
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCMeasurementType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func unknownObserverThrows() async throws {
        var w = BinaryWriter()
        w.writeUInt32(99)  // unknown observer
        for _ in 0..<32 { w.writeUInt8(0) }
        let data = w.data
        var reader = BinaryReader(data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCMeasurementType.parsePayload(reader: &reader, byteCount: data.count)
        }
    }

    @Test
    func d65IlluminantPreserved() throws {
        let original = ICCMeasurementType(
            standardObserver: .cie1964_10deg,
            backingMeasurement: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.9505),
                y: ICCS15Fixed16Number(1.0),
                z: ICCS15Fixed16Number(1.0890)
            ),
            measurementGeometry: .zeroDegree_d_or_d_zeroDegree,
            measurementFlare: ICCU16Fixed16Number(0.005),
            standardIlluminant: .d65
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCMeasurementType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded.standardIlluminant == .d65)
    }

    @Test
    func bodyIs28Bytes() {
        let m = ICCMeasurementType(
            standardObserver: .unknown,
            backingMeasurement: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.0),
                y: ICCS15Fixed16Number(0.0),
                z: ICCS15Fixed16Number(0.0)
            ),
            measurementGeometry: .unknown,
            measurementFlare: ICCU16Fixed16Number(0.0),
            standardIlluminant: .unknown
        )
        var writer = BinaryWriter()
        m.encodePayload(to: &writer)
        #expect(writer.data.count == 28)
    }

    @Test
    func standardObserverCases() {
        #expect(ICCMeasurementType.StandardObserver.cie1931_2deg.rawValue == 1)
        #expect(ICCMeasurementType.StandardObserver.cie1964_10deg.rawValue == 2)
    }
}

@Suite("ICCViewingConditionsType")
struct ICCViewingConditionsTypeTests {

    @Test
    func roundTrip() throws {
        let original = ICCViewingConditionsType(
            unconditionalIlluminant: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.9505),
                y: ICCS15Fixed16Number(1.0),
                z: ICCS15Fixed16Number(1.0890)
            ),
            unconditionalSurround: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.2),
                y: ICCS15Fixed16Number(0.2),
                z: ICCS15Fixed16Number(0.2)
            ),
            illuminantType: .d50
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCViewingConditionsType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func bodyIs28Bytes() {
        let v = ICCViewingConditionsType(
            unconditionalIlluminant: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.0),
                y: ICCS15Fixed16Number(0.0),
                z: ICCS15Fixed16Number(0.0)
            ),
            unconditionalSurround: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.0),
                y: ICCS15Fixed16Number(0.0),
                z: ICCS15Fixed16Number(0.0)
            ),
            illuminantType: .unknown
        )
        var writer = BinaryWriter()
        v.encodePayload(to: &writer)
        #expect(writer.data.count == 28)
    }

    @Test
    func unknownIlluminantThrows() async throws {
        var w = BinaryWriter()
        ICCXYZNumber(x: ICCS15Fixed16Number(0.0), y: ICCS15Fixed16Number(0.0), z: ICCS15Fixed16Number(0.0))
            .encode(to: &w)
        ICCXYZNumber(x: ICCS15Fixed16Number(0.0), y: ICCS15Fixed16Number(0.0), z: ICCS15Fixed16Number(0.0))
            .encode(to: &w)
        w.writeUInt32(999)
        var reader = BinaryReader(w.data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCViewingConditionsType.parsePayload(reader: &reader, byteCount: w.data.count)
        }
    }

    @Test
    func d65SettingsPreserved() throws {
        let original = ICCViewingConditionsType(
            unconditionalIlluminant: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.9505),
                y: ICCS15Fixed16Number(1.0),
                z: ICCS15Fixed16Number(1.0890)
            ),
            unconditionalSurround: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.1),
                y: ICCS15Fixed16Number(0.1),
                z: ICCS15Fixed16Number(0.1)
            ),
            illuminantType: .d65
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCViewingConditionsType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded.illuminantType == .d65)
    }
}

@Suite("ICCChromaticityType")
struct ICCChromaticityTypeTests {

    @Test
    func threeChannelRGBRoundTrip() throws {
        let original = ICCChromaticityType(
            phosphorOrColorant: .itu_r_BT_709,
            coordinates: [
                .init(x: ICCU16Fixed16Number(0.64), y: ICCU16Fixed16Number(0.33)),
                .init(x: ICCU16Fixed16Number(0.3), y: ICCU16Fixed16Number(0.6)),
                .init(x: ICCU16Fixed16Number(0.15), y: ICCU16Fixed16Number(0.06))
            ]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCChromaticityType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func unknownColorantRejected() async throws {
        var w = BinaryWriter()
        w.writeUInt16(0)
        w.writeUInt16(99)
        var reader = BinaryReader(w.data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCChromaticityType.parsePayload(reader: &reader, byteCount: w.data.count)
        }
    }

    @Test
    func emptyCoordinatesRoundTrip() throws {
        let original = ICCChromaticityType(
            phosphorOrColorant: .unknown,
            coordinates: []
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCChromaticityType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func phosphorEnumComprehensive() {
        #expect(ICCChromaticityType.PhosphorOrColorant.itu_r_BT_709.rawValue == 1)
        #expect(ICCChromaticityType.PhosphorOrColorant.smpte_RP_145_1994.rawValue == 2)
        #expect(ICCChromaticityType.PhosphorOrColorant.ebu_Tech_3213_E.rawValue == 3)
        #expect(ICCChromaticityType.PhosphorOrColorant.p3.rawValue == 5)
        #expect(ICCChromaticityType.PhosphorOrColorant.itu_r_BT_2020.rawValue == 6)
    }
}

@Suite("ICC LUT types")
struct ICCLUTTypesTests {

    @Test
    func lut8RoundTripPreservesBody() throws {
        let body = Data([0x10, 0x20, 0x30, 0x40, 0x50])
        let original = ICCLUT8Type(
            inputChannels: 3, outputChannels: 3, clutPoints: 16, rawPayload: body
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCLUT8Type.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func lut16RoundTripPreservesBody() throws {
        let body = Data([0xAA, 0xBB, 0xCC])
        let original = ICCLUT16Type(
            inputChannels: 1, outputChannels: 1, clutPoints: 8, rawPayload: body
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCLUT16Type.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func lutAToBChannelCounts() throws {
        let original = ICCLUTAToBType(
            inputChannels: 4, outputChannels: 3, rawPayload: Data([0x01, 0x02])
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCLUTAToBType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
        #expect(decoded.inputChannels == 4)
        #expect(decoded.outputChannels == 3)
    }

    @Test
    func lutBToARoundTrip() throws {
        let original = ICCLUTBToAType(inputChannels: 3, outputChannels: 4, rawPayload: Data())
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCLUTBToAType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func multiProcessElementsRoundTrip() throws {
        let original = ICCMultiProcessElementsType(
            inputChannels: 3,
            outputChannels: 3,
            rawPayload: Data([0x00, 0x01, 0x02, 0x03])
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCMultiProcessElementsType.parsePayload(
            reader: &reader, byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func emptyLUT8Body() throws {
        let original = ICCLUT8Type(
            inputChannels: 0, outputChannels: 0, clutPoints: 0, rawPayload: Data()
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCLUT8Type.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }
}
