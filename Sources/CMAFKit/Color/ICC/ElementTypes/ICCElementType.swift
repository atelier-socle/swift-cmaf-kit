// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCElementTypeSignature + ICCElement dispatch
//
// Reference: ICC.1:2022 §10 (tag type definitions).
//
// Each tag's data begins with an 8-byte preamble:
//   typeSignature: UInt32
//   reserved: UInt32  (must be 0)
// followed by a type-specific payload. ``ICCElement`` parses an
// element from the preamble onwards and round-trips it byte-for-byte.

import Foundation

/// ICC element type signatures per ICC.1:2022 §10.
public enum ICCElementTypeSignature: UInt32, Sendable, Hashable, CaseIterable, Codable {
    case xyz = 0x5859_5A20
    case s15Fixed16Array = 0x7366_3332
    case curve = 0x6375_7276
    case parametricCurve = 0x7061_7261
    case multiLocalizedUnicode = 0x6D6C_7563
    case textDescription = 0x6465_7363
    case signature = 0x7369_6720
    case measurement = 0x6D65_6173
    case viewingConditions = 0x7669_6577
    case lut8 = 0x6D66_7431
    case lut16 = 0x6D66_7432
    case lutAToB = 0x6D41_4220
    case lutBToA = 0x6D42_4120
    case multiProcessElements = 0x6D70_6574
    case namedColor2 = 0x6E63_6C32
    case responseCurveSet16 = 0x7263_7332
    case chromaticity = 0x6368_726D
    case colorantOrder = 0x636C_726F
    case colorantTable = 0x636C_7274
    case profileSequenceDesc = 0x7073_6571
    case profileSequenceIdentifier = 0x7073_6964
    case text = 0x7465_7874
    case dateTime = 0x6474_696D
    case data = 0x6461_7461
    case u16Fixed16Array = 0x7566_3332
    case uInt16Array = 0x7569_3136
    case uInt32Array = 0x7569_3332
    case uInt64Array = 0x7569_3634
    case uInt8Array = 0x7569_3038
}

/// A typed ICC element parsed from a tag's data payload.
///
/// Reference: ICC.1:2022 §10.
public enum ICCElement: Sendable, Equatable, Hashable {
    case xyz(ICCXYZType)
    case s15Fixed16Array(ICCS15Fixed16ArrayType)
    case curve(ICCCurveType)
    case parametricCurve(ICCParametricCurveType)
    case multiLocalizedUnicode(ICCMultiLocalizedUnicodeType)
    case textDescription(ICCTextDescriptionType)
    case signature(ICCSignatureType)
    case measurement(ICCMeasurementType)
    case viewingConditions(ICCViewingConditionsType)
    case lut8(ICCLUT8Type)
    case lut16(ICCLUT16Type)
    case lutAToB(ICCLUTAToBType)
    case lutBToA(ICCLUTBToAType)
    case multiProcessElements(ICCMultiProcessElementsType)
    case namedColor2(ICCNamedColor2Type)
    case responseCurveSet16(ICCResponseCurveSet16Type)
    case chromaticity(ICCChromaticityType)
    case colorantOrder(ICCColorantOrderType)
    case colorantTable(ICCColorantTableType)
    case profileSequenceDesc(ICCProfileSequenceDescType)
    case profileSequenceIdentifier(ICCProfileSequenceIdentifierType)
    case text(String)
    case dateTime(ICCDateTimeNumber)
    case data(typeFlag: UInt32, bytes: Data)
    case u16Fixed16Array([ICCU16Fixed16Number])
    case uInt16Array([UInt16])
    case uInt32Array([UInt32])
    case uInt64Array([UInt64])
    case uInt8Array([UInt8])

    /// Parse a typed element from a reader positioned at the start of an
    /// element's 8-byte preamble. The `payloadByteCount` is the byte
    /// count of the element's data including the 8-byte preamble (the
    /// tag size from the tag table).
    public static func parse(
        reader: inout BinaryReader,
        payloadByteCount: Int
    ) throws -> ICCElement {
        let signatureRaw = try reader.readUInt32()
        let reserved = try reader.readUInt32()
        guard reserved == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC element reserved field is non-zero"
            )
        }
        guard let signature = ICCElementTypeSignature(rawValue: signatureRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC element type signature 0x\(String(signatureRaw, radix: 16))"
            )
        }

        let payloadAfterPreamble = payloadByteCount - 8
        guard payloadAfterPreamble >= 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "ICC element preamble overruns declared tag size"
            )
        }

        return try parseTyped(
            signature: signature,
            reader: &reader,
            payloadAfterPreamble: payloadAfterPreamble
        )
    }

    private static func parseTyped(
        signature: ICCElementTypeSignature,
        reader: inout BinaryReader,
        payloadAfterPreamble: Int
    ) throws -> ICCElement {
        switch signature {
        case .xyz:
            return .xyz(
                try ICCXYZType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .s15Fixed16Array:
            return .s15Fixed16Array(
                try ICCS15Fixed16ArrayType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .curve:
            return .curve(
                try ICCCurveType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .parametricCurve:
            return .parametricCurve(
                try ICCParametricCurveType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .multiLocalizedUnicode:
            return .multiLocalizedUnicode(
                try ICCMultiLocalizedUnicodeType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .textDescription:
            return .textDescription(
                try ICCTextDescriptionType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .signature:
            return .signature(
                try ICCSignatureType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .measurement:
            return .measurement(
                try ICCMeasurementType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .viewingConditions:
            return .viewingConditions(
                try ICCViewingConditionsType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .lut8:
            return .lut8(
                try ICCLUT8Type.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .lut16:
            return .lut16(
                try ICCLUT16Type.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .lutAToB:
            return .lutAToB(
                try ICCLUTAToBType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .lutBToA:
            return .lutBToA(
                try ICCLUTBToAType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .multiProcessElements:
            return .multiProcessElements(
                try ICCMultiProcessElementsType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .namedColor2:
            return .namedColor2(
                try ICCNamedColor2Type.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .responseCurveSet16:
            return .responseCurveSet16(
                try ICCResponseCurveSet16Type.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .chromaticity:
            return .chromaticity(
                try ICCChromaticityType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .colorantOrder:
            return .colorantOrder(
                try ICCColorantOrderType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .colorantTable:
            return .colorantTable(
                try ICCColorantTableType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .profileSequenceDesc:
            return .profileSequenceDesc(
                try ICCProfileSequenceDescType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .profileSequenceIdentifier:
            return .profileSequenceIdentifier(
                try ICCProfileSequenceIdentifierType.parsePayload(
                    reader: &reader, byteCount: payloadAfterPreamble))
        case .text:
            let bytes = try reader.readData(count: payloadAfterPreamble)
            let trimmed = bytes.prefix { $0 != 0 }
            let str = String(data: Data(trimmed), encoding: .ascii) ?? ""
            return .text(str)
        case .dateTime:
            return .dateTime(try ICCDateTimeNumber.parse(reader: &reader))
        case .data:
            let typeFlag = try reader.readUInt32()
            let bytes = try reader.readData(count: payloadAfterPreamble - 4)
            return .data(typeFlag: typeFlag, bytes: bytes)
        case .u16Fixed16Array:
            let count = payloadAfterPreamble / 4
            var array: [ICCU16Fixed16Number] = []
            array.reserveCapacity(count)
            for _ in 0..<count {
                array.append(try ICCU16Fixed16Number.parse(reader: &reader))
            }
            return .u16Fixed16Array(array)
        case .uInt16Array:
            let count = payloadAfterPreamble / 2
            var array: [UInt16] = []
            array.reserveCapacity(count)
            for _ in 0..<count {
                array.append(try reader.readUInt16())
            }
            return .uInt16Array(array)
        case .uInt32Array:
            let count = payloadAfterPreamble / 4
            var array: [UInt32] = []
            array.reserveCapacity(count)
            for _ in 0..<count {
                array.append(try reader.readUInt32())
            }
            return .uInt32Array(array)
        case .uInt64Array:
            let count = payloadAfterPreamble / 8
            var array: [UInt64] = []
            array.reserveCapacity(count)
            for _ in 0..<count {
                array.append(try reader.readUInt64())
            }
            return .uInt64Array(array)
        case .uInt8Array:
            let bytes = try reader.readData(count: payloadAfterPreamble)
            return .uInt8Array(Array(bytes))
        }
    }

    /// Encode this element to the writer, including the 8-byte preamble.
    public func encode(to writer: inout BinaryWriter) {
        writer.writeUInt32(signature.rawValue)
        writer.writeUInt32(0)  // reserved
        encodePayload(to: &writer)
    }

    private func encodePayload(to writer: inout BinaryWriter) {
        switch self {
        case .xyz(let v): v.encodePayload(to: &writer)
        case .s15Fixed16Array(let v): v.encodePayload(to: &writer)
        case .curve(let v): v.encodePayload(to: &writer)
        case .parametricCurve(let v): v.encodePayload(to: &writer)
        case .multiLocalizedUnicode(let v): v.encodePayload(to: &writer)
        case .textDescription(let v): v.encodePayload(to: &writer)
        case .signature(let v): v.encodePayload(to: &writer)
        case .measurement(let v): v.encodePayload(to: &writer)
        case .viewingConditions(let v): v.encodePayload(to: &writer)
        case .lut8(let v): v.encodePayload(to: &writer)
        case .lut16(let v): v.encodePayload(to: &writer)
        case .lutAToB(let v): v.encodePayload(to: &writer)
        case .lutBToA(let v): v.encodePayload(to: &writer)
        case .multiProcessElements(let v): v.encodePayload(to: &writer)
        case .namedColor2(let v): v.encodePayload(to: &writer)
        case .responseCurveSet16(let v): v.encodePayload(to: &writer)
        case .chromaticity(let v): v.encodePayload(to: &writer)
        case .colorantOrder(let v): v.encodePayload(to: &writer)
        case .colorantTable(let v): v.encodePayload(to: &writer)
        case .profileSequenceDesc(let v): v.encodePayload(to: &writer)
        case .profileSequenceIdentifier(let v): v.encodePayload(to: &writer)
        case .text(let s):
            var data = s.data(using: .ascii) ?? Data()
            data.append(0)
            writer.writeData(data)
        case .dateTime(let v): v.encode(to: &writer)
        case .data(let flag, let bytes):
            writer.writeUInt32(flag)
            writer.writeData(bytes)
        case .u16Fixed16Array(let v):
            for n in v { n.encode(to: &writer) }
        case .uInt16Array(let v):
            for n in v { writer.writeUInt16(n) }
        case .uInt32Array(let v):
            for n in v { writer.writeUInt32(n) }
        case .uInt64Array(let v):
            for n in v { writer.writeUInt64(n) }
        case .uInt8Array(let v):
            writer.writeData(Data(v))
        }
    }

    /// The element's on-wire type signature.
    public var signature: ICCElementTypeSignature {
        switch self {
        case .xyz: return .xyz
        case .s15Fixed16Array: return .s15Fixed16Array
        case .curve: return .curve
        case .parametricCurve: return .parametricCurve
        case .multiLocalizedUnicode: return .multiLocalizedUnicode
        case .textDescription: return .textDescription
        case .signature: return .signature
        case .measurement: return .measurement
        case .viewingConditions: return .viewingConditions
        case .lut8: return .lut8
        case .lut16: return .lut16
        case .lutAToB: return .lutAToB
        case .lutBToA: return .lutBToA
        case .multiProcessElements: return .multiProcessElements
        case .namedColor2: return .namedColor2
        case .responseCurveSet16: return .responseCurveSet16
        case .chromaticity: return .chromaticity
        case .colorantOrder: return .colorantOrder
        case .colorantTable: return .colorantTable
        case .profileSequenceDesc: return .profileSequenceDesc
        case .profileSequenceIdentifier: return .profileSequenceIdentifier
        case .text: return .text
        case .dateTime: return .dateTime
        case .data: return .data
        case .u16Fixed16Array: return .u16Fixed16Array
        case .uInt16Array: return .uInt16Array
        case .uInt32Array: return .uInt32Array
        case .uInt64Array: return .uInt64Array
        case .uInt8Array: return .uInt8Array
        }
    }
}
