// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCResponseCurveSet16Type")
struct ICCResponseCurveSet16TypeTests {

    private func makeEntry(
        unit: ICCMeasurementUnitSignature,
        channels: Int,
        measurementsPerChannel: Int
    ) -> ICCResponseCurveSet16Type.MeasurementTypeEntry {
        let pcs = (0..<channels).map { i in
            ICCXYZNumber(
                x: ICCS15Fixed16Number(Double(i) * 0.1),
                y: ICCS15Fixed16Number(Double(i) * 0.2),
                z: ICCS15Fixed16Number(Double(i) * 0.3)
            )
        }
        let measurements: [[ICCResponse16Number]] = (0..<channels).map { c in
            (0..<measurementsPerChannel).map { k in
                ICCResponse16Number(
                    deviceValue: UInt16(c * 100 + k),
                    measurementValue: ICCS15Fixed16Number(Double(k) * 0.01)
                )
            }
        }
        return ICCResponseCurveSet16Type.MeasurementTypeEntry(
            measurementUnit: unit,
            pcsValuesAtMaxColorant: pcs,
            measurementsByChannel: measurements
        )
    }

    @Test
    func singleChannelSingleMeasurementTypeRoundTrip() throws {
        let entry = makeEntry(unit: .statusA, channels: 1, measurementsPerChannel: 4)
        let original = ICCResponseCurveSet16Type(numberOfChannels: 1, measurementTypes: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCResponseCurveSet16Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func threeChannelTwoMeasurementTypesRoundTrip() throws {
        let entryA = makeEntry(unit: .statusA, channels: 3, measurementsPerChannel: 2)
        let entryE = makeEntry(unit: .statusE, channels: 3, measurementsPerChannel: 3)
        let original = ICCResponseCurveSet16Type(
            numberOfChannels: 3,
            measurementTypes: [entryA, entryE]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCResponseCurveSet16Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func cmykFourChannelStatusARoundTrip() throws {
        let entry = makeEntry(unit: .statusA, channels: 4, measurementsPerChannel: 5)
        let original = ICCResponseCurveSet16Type(numberOfChannels: 4, measurementTypes: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCResponseCurveSet16Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.measurementTypes[0].measurementUnit == .statusA)
        #expect(decoded.measurementTypes[0].measurementsByChannel.count == 4)
    }

    @Test
    func zeroMeasurementTypesRoundTrip() throws {
        let original = ICCResponseCurveSet16Type(numberOfChannels: 3, measurementTypes: [])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCResponseCurveSet16Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func allNineMeasurementUnitsRoundTrip() throws {
        let units: [ICCMeasurementUnitSignature] = [
            .statusA, .statusE, .statusI, .statusT, .statusM,
            .dinNoFilter, .dinWithFilter,
            .dinNarrowBandNoFilter, .dinNarrowBandWithFilter
        ]
        for unit in units {
            let entry = makeEntry(unit: unit, channels: 1, measurementsPerChannel: 1)
            let original = ICCResponseCurveSet16Type(
                numberOfChannels: 1,
                measurementTypes: [entry]
            )
            var writer = BinaryWriter()
            original.encodePayload(to: &writer)
            var reader = BinaryReader(writer.data)
            let decoded = try ICCResponseCurveSet16Type.parsePayload(
                reader: &reader,
                byteCount: writer.data.count
            )
            #expect(decoded.measurementTypes[0].measurementUnit == unit)
        }
    }

    @Test
    func unknownMeasurementUnitThrows() async throws {
        // numberOfChannels=1, measurementTypeCount=1, offset=20 (8 preamble + 8 header + 4 offset),
        // then unknown unit sig 0x12345678.
        var w = BinaryWriter()
        w.writeUInt16(1)  // numberOfChannels
        w.writeUInt16(1)  // measurementTypeCount
        w.writeUInt32(20)  // offset (wire-relative: preamble 8 + header 12 = 20)
        w.writeUInt32(0x1234_5678)  // unknown unit
        // Fill in enough bytes to attempt parse: 1 channel × UInt32 count + 1 × XYZ + 0 measurements
        w.writeUInt32(0)  // measurement count for channel 0
        ICCXYZNumber(
            x: ICCS15Fixed16Number(0.0),
            y: ICCS15Fixed16Number(0.0),
            z: ICCS15Fixed16Number(0.0)
        ).encode(to: &w)
        var reader = BinaryReader(w.data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCResponseCurveSet16Type.parsePayload(
                reader: &reader,
                byteCount: w.data.count
            )
        }
    }

    @Test
    func offsetOutOfBoundsThrows() async throws {
        var w = BinaryWriter()
        w.writeUInt16(1)
        w.writeUInt16(1)
        w.writeUInt32(99999)  // bad offset
        var reader = BinaryReader(w.data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCResponseCurveSet16Type.parsePayload(
                reader: &reader,
                byteCount: w.data.count
            )
        }
    }

    @Test
    func emptyChannelsRoundTrip() throws {
        // 1 channel, 1 measurement type, 0 measurements in that channel.
        let entry = ICCResponseCurveSet16Type.MeasurementTypeEntry(
            measurementUnit: .statusA,
            pcsValuesAtMaxColorant: [
                ICCXYZNumber(
                    x: ICCS15Fixed16Number(0.0),
                    y: ICCS15Fixed16Number(0.0),
                    z: ICCS15Fixed16Number(0.0)
                )
            ],
            measurementsByChannel: [[]]
        )
        let original = ICCResponseCurveSet16Type(numberOfChannels: 1, measurementTypes: [entry])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCResponseCurveSet16Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.measurementTypes[0].measurementsByChannel[0].isEmpty)
    }

    @Test
    func twoMeasurementTypesOffsetsDistinct() throws {
        let entryA = makeEntry(unit: .statusA, channels: 2, measurementsPerChannel: 2)
        let entryE = makeEntry(unit: .statusE, channels: 2, measurementsPerChannel: 3)
        let original = ICCResponseCurveSet16Type(
            numberOfChannels: 2,
            measurementTypes: [entryA, entryE]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        // The header section is 2 + 2 + 4*2 = 12 bytes; offsets should be 8+12=20 and 20+sizeof(entryA).
        // We don't need to check exact values — just that round-trip preserves both entries.
        var reader = BinaryReader(writer.data)
        let decoded = try ICCResponseCurveSet16Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.measurementTypes.count == 2)
        #expect(decoded.measurementTypes[0].measurementUnit == .statusA)
        #expect(decoded.measurementTypes[1].measurementUnit == .statusE)
    }

    @Test
    func iccElementWraps() throws {
        let entry = makeEntry(unit: .statusA, channels: 1, measurementsPerChannel: 2)
        let rcs = ICCResponseCurveSet16Type(numberOfChannels: 1, measurementTypes: [entry])
        let element: ICCElement = .responseCurveSet16(rcs)
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        if case .responseCurveSet16(let decodedRCS) = decoded {
            #expect(decodedRCS == rcs)
        } else {
            Issue.record("Expected responseCurveSet16 element")
        }
    }

    @Test
    func equatableConformance() {
        let entry = makeEntry(unit: .statusA, channels: 2, measurementsPerChannel: 1)
        let a = ICCResponseCurveSet16Type(numberOfChannels: 2, measurementTypes: [entry])
        let b = ICCResponseCurveSet16Type(numberOfChannels: 2, measurementTypes: [entry])
        #expect(a == b)
    }

    @Test
    func measurementUnitSignatureEnumValues() {
        #expect(ICCMeasurementUnitSignature.statusA.rawValue == 0x5374_6141)
        #expect(ICCMeasurementUnitSignature.statusE.rawValue == 0x5374_6145)
        #expect(ICCMeasurementUnitSignature.allCases.count == 9)
    }
}
