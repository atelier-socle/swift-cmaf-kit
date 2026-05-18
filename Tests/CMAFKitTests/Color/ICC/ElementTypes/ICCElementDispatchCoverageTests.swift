// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCElement dispatch coverage")
struct ICCElementDispatchCoverageTests {

    @Test
    func textElementRoundTrip() throws {
        let element = ICCElement.text("Hello world")
        var writer = BinaryWriter()
        element.encode(to: &writer)
        let bytes = writer.data
        var reader = BinaryReader(bytes)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: bytes.count
        )
        #expect(decoded == element)
    }

    @Test
    func emptyTextElementRoundTrip() throws {
        let element = ICCElement.text("")
        var writer = BinaryWriter()
        element.encode(to: &writer)
        let bytes = writer.data
        var reader = BinaryReader(bytes)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: bytes.count
        )
        #expect(decoded == element)
    }

    @Test
    func textElementTrailingNullsTrimmed() throws {
        let element = ICCElement.text("ASCII")
        var writer = BinaryWriter()
        element.encode(to: &writer)
        // Encoder appends a null terminator; parser must trim it.
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        if case .text(let value) = decoded {
            #expect(value == "ASCII")
        } else {
            Issue.record("Expected .text case")
        }
    }

    @Test
    func dateTimeElementRoundTrip() throws {
        let element = ICCElement.dateTime(
            ICCDateTimeNumber(
                year: 2026, month: 5, day: 18,
                hour: 14, minute: 30, second: 0
            )
        )
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func dataElementRoundTrip() throws {
        let element = ICCElement.data(
            typeFlag: 0xDEAD_BEEF,
            bytes: Data([0x01, 0x02, 0x03, 0x04])
        )
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func dataElementWithEmptyBytesRoundTrip() throws {
        let element = ICCElement.data(typeFlag: 0, bytes: Data())
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func u16Fixed16ArrayRoundTrip() throws {
        let element = ICCElement.u16Fixed16Array([
            ICCU16Fixed16Number(1.0),
            ICCU16Fixed16Number(0.5),
            ICCU16Fixed16Number(2.0)
        ])
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func emptyU16Fixed16ArrayRoundTrip() throws {
        let element = ICCElement.u16Fixed16Array([])
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func uInt16ArrayRoundTrip() throws {
        let element = ICCElement.uInt16Array([0x0001, 0xFFFF, 0x1234, 0x5678])
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func uInt32ArrayRoundTrip() throws {
        let element = ICCElement.uInt32Array([
            0x0000_0001, 0xDEAD_BEEF, 0xFFFF_FFFF
        ])
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func uInt64ArrayRoundTrip() throws {
        let element = ICCElement.uInt64Array([
            0x0000_0000_0000_0001,
            0xFFFF_FFFF_FFFF_FFFF,
            0xDEAD_BEEF_CAFE_BABE
        ])
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func uInt8ArrayRoundTrip() throws {
        let element = ICCElement.uInt8Array([0x00, 0x42, 0xAA, 0xFF])
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func emptyUInt8ArrayRoundTrip() throws {
        let element = ICCElement.uInt8Array([])
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
        #expect(decoded == element)
    }

    @Test
    func unknownSignatureThrows() {
        // 8-byte preamble: bogus signature + zero reserved.
        let bytes = Data(hex: "DEADBEEF 00000000")
        #expect(throws: Error.self) {
            var reader = BinaryReader(bytes)
            _ = try ICCElement.parse(
                reader: &reader,
                payloadByteCount: bytes.count
            )
        }
    }

    @Test
    func nonZeroReservedThrows() {
        // 8-byte preamble: 'XYZ ' signature + non-zero reserved.
        let bytes = Data(hex: "58595A20 00000001")
        #expect(throws: Error.self) {
            var reader = BinaryReader(bytes)
            _ = try ICCElement.parse(
                reader: &reader,
                payloadByteCount: bytes.count
            )
        }
    }
}

@Suite("ICCElement signature accessor")
struct ICCElementSignatureAccessorTests {

    @Test
    func signatureForTextIsText() {
        #expect(ICCElement.text("x").signature == .text)
    }

    @Test
    func signatureForDateTime() {
        let dt = ICCDateTimeNumber(
            year: 2026, month: 1, day: 1,
            hour: 0, minute: 0, second: 0
        )
        #expect(ICCElement.dateTime(dt).signature == .dateTime)
    }

    @Test
    func signatureForData() {
        let element = ICCElement.data(typeFlag: 0, bytes: Data())
        #expect(element.signature == .data)
    }

    @Test
    func signatureForU16Fixed16Array() {
        #expect(ICCElement.u16Fixed16Array([]).signature == .u16Fixed16Array)
    }

    @Test
    func signatureForUInt16Array() {
        #expect(ICCElement.uInt16Array([]).signature == .uInt16Array)
    }

    @Test
    func signatureForUInt32Array() {
        #expect(ICCElement.uInt32Array([]).signature == .uInt32Array)
    }

    @Test
    func signatureForUInt64Array() {
        #expect(ICCElement.uInt64Array([]).signature == .uInt64Array)
    }

    @Test
    func signatureForUInt8Array() {
        #expect(ICCElement.uInt8Array([]).signature == .uInt8Array)
    }

    @Test
    func signatureRawValuesAreCorrectFourCCs() {
        // text = 'text' = 0x74_65_78_74
        #expect(ICCElementTypeSignature.text.rawValue == 0x7465_7874)
        // data = 'data' = 0x64_61_74_61
        #expect(ICCElementTypeSignature.data.rawValue == 0x6461_7461)
        // dtim = 'dtim'
        #expect(ICCElementTypeSignature.dateTime.rawValue == 0x6474_696D)
    }
}

@Suite("ICCElement typed dispatch round-trips")
struct ICCElementTypedDispatchTests {

    private static func roundTrip(_ element: ICCElement) throws -> ICCElement {
        var writer = BinaryWriter()
        element.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        return try ICCElement.parse(
            reader: &reader,
            payloadByteCount: writer.data.count
        )
    }

    @Test
    func parametricCurveDispatch() throws {
        let element = ICCElement.parametricCurve(
            ICCParametricCurveType(
                functionType: .gammaOnly,
                parameters: [ICCS15Fixed16Number(2.4)]
            )
        )
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func signatureDispatch() throws {
        let element = ICCElement.signature(ICCSignatureType(signature: 0x7363_6E72))
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func measurementDispatch() throws {
        let element = ICCElement.measurement(
            ICCMeasurementType(
                standardObserver: .cie1931_2deg,
                backingMeasurement: ICCXYZNumber(
                    x: ICCS15Fixed16Number(0.95),
                    y: ICCS15Fixed16Number(1.00),
                    z: ICCS15Fixed16Number(1.08)
                ),
                measurementGeometry: .unknown,
                measurementFlare: ICCU16Fixed16Number(0.0),
                standardIlluminant: .d65
            )
        )
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func viewingConditionsDispatch() throws {
        let element = ICCElement.viewingConditions(
            ICCViewingConditionsType(
                unconditionalIlluminant: ICCXYZNumber(
                    x: ICCS15Fixed16Number(0.95),
                    y: ICCS15Fixed16Number(1.0),
                    z: ICCS15Fixed16Number(1.08)
                ),
                unconditionalSurround: ICCXYZNumber(
                    x: ICCS15Fixed16Number(0.0),
                    y: ICCS15Fixed16Number(0.0),
                    z: ICCS15Fixed16Number(0.0)
                ),
                illuminantType: .d65
            )
        )
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func chromaticityDispatch() throws {
        let element = ICCElement.chromaticity(
            ICCChromaticityType(
                phosphorOrColorant: .itu_r_BT_709,
                coordinates: [
                    ICCChromaticityType.ChromaticCoordinate(
                        x: ICCU16Fixed16Number(0.64),
                        y: ICCU16Fixed16Number(0.33)
                    )
                ]
            )
        )
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func lut8Dispatch() throws {
        let element = ICCElement.lut8(
            ICCLUT8Type(
                inputChannels: 3, outputChannels: 3, clutPoints: 16,
                rawPayload: Data([0x10, 0x20, 0x30])
            )
        )
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func lut16Dispatch() throws {
        let element = ICCElement.lut16(
            ICCLUT16Type(
                inputChannels: 1, outputChannels: 1, clutPoints: 8,
                rawPayload: Data([0xAA, 0xBB])
            )
        )
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func lutAToBDispatch() throws {
        let element = ICCElement.lutAToB(
            ICCLUTAToBType(
                inputChannels: 4, outputChannels: 3,
                rawPayload: Data([0x01, 0x02])
            )
        )
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func lutBToADispatch() throws {
        let element = ICCElement.lutBToA(
            ICCLUTBToAType(
                inputChannels: 3, outputChannels: 4,
                rawPayload: Data()
            )
        )
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func multiProcessElementsDispatch() throws {
        let element = ICCElement.multiProcessElements(
            ICCMultiProcessElementsType(
                inputChannels: 3,
                outputChannels: 3,
                rawPayload: Data([0x00, 0x01, 0x02, 0x03])
            )
        )
        #expect(try Self.roundTrip(element) == element)
    }

    @Test
    func preamblePayloadByteCountUnderflowThrows() {
        // payloadByteCount=4 (less than the 8-byte preamble) must throw.
        let bytes = Data(hex: "58595A20 00000000")  // 'XYZ ' + zero reserved
        #expect(throws: Error.self) {
            var reader = BinaryReader(bytes)
            _ = try ICCElement.parse(
                reader: &reader,
                payloadByteCount: 4
            )
        }
    }
}
