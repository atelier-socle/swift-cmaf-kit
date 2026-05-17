// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BinaryWriter
//
// Big-endian binary writer producing a contiguous `Data` buffer. Provides the
// box assembly helpers (`writeBox`, `writeFullBox`) that all ISOBMFF encoders
// use. Reference: ISO/IEC 14496-12 §4.2 (object structured representation —
// including the `size = 1` largesize convention and the `uuid` extended type).
//
// Per addendum F.7 there is no separate `ISOBoxWriter`. All ISOBMFF writes go
// through `BinaryWriter.writeBox` / `writeFullBox` plus each box's per-instance
// `encode(to:)`.

import Foundation

/// Big-endian binary writer producing a contiguous `Data` buffer.
///
/// Multi-byte integers are appended in network (big-endian) order. The
/// ``writeBox(type:body:)``-family helpers implement the ISO/IEC 14496-12 §4.2
/// box framing — including automatic selection of the 64-bit `largesize`
/// encoding when the box payload would otherwise overflow a `UInt32` size
/// field.
public struct BinaryWriter: Sendable {

    /// Accumulated output buffer.
    public private(set) var data: Data

    public init() {
        self.data = Data()
    }

    // MARK: Unsigned integers

    /// Append a `UInt8`.
    public mutating func writeUInt8(_ value: UInt8) {
        data.append(value)
    }

    /// Append a big-endian `UInt16`.
    public mutating func writeUInt16(_ value: UInt16) {
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }

    /// Append a big-endian 24-bit unsigned integer (low 24 bits of `value`).
    public mutating func writeUInt24(_ value: UInt32) {
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }

    /// Append a big-endian `UInt32`.
    public mutating func writeUInt32(_ value: UInt32) {
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }

    /// Append a big-endian `UInt64`.
    public mutating func writeUInt64(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8((value >> shift) & 0xff))
        }
    }

    // MARK: Signed integers

    /// Append a big-endian `Int16` (two's complement).
    public mutating func writeInt16(_ value: Int16) {
        writeUInt16(UInt16(bitPattern: value))
    }

    /// Append a big-endian `Int32` (two's complement).
    public mutating func writeInt32(_ value: Int32) {
        writeUInt32(UInt32(bitPattern: value))
    }

    // MARK: Bytes

    /// Append the contents of `bytes`.
    public mutating func writeData(_ bytes: Data) {
        data.append(bytes)
    }

    /// Append the contents of `bytes`.
    public mutating func writeBytes(_ bytes: [UInt8]) {
        data.append(contentsOf: bytes)
    }

    // MARK: FourCC

    /// Append a 4-byte FourCC.
    public mutating func writeFourCC(_ fourCC: FourCC) {
        writeUInt32(fourCC.rawValue)
    }

    // MARK: Strings

    /// Encode and append `string` using the requested encoding. Invalid encodings
    /// produce no bytes.
    public mutating func writeString(_ string: String, encoding: String.Encoding = .utf8) {
        if let bytes = string.data(using: encoding) {
            data.append(bytes)
        }
    }

    /// Encode `string` and append a trailing `0x00` null terminator.
    public mutating func writeNullTerminatedString(_ string: String, encoding: String.Encoding = .utf8) {
        writeString(string, encoding: encoding)
        writeUInt8(0)
    }

    // MARK: Fixed-point

    /// Append an 8.8 fixed-point number (16 bits signed). Rounds to the nearest
    /// representable value.
    public mutating func writeFixed8_8(_ value: Double) {
        let raw = Int16((value * 256.0).rounded())
        writeInt16(raw)
    }

    /// Append a 16.16 fixed-point number (32 bits signed). Rounds to the nearest
    /// representable value.
    public mutating func writeFixed16_16(_ value: Double) {
        let raw = Int32((value * 65536.0).rounded())
        writeInt32(raw)
    }

    /// Append a 2.30 fixed-point number (32 bits signed). Rounds to the nearest
    /// representable value. Used by ISO/IEC 14496-12 §8.3 for matrix rows.
    public mutating func writeFixed2_30(_ value: Double) {
        let raw = Int32((value * Double(1 << 30)).rounded())
        writeInt32(raw)
    }

    // MARK: Matrix

    /// Append the 9-element transformation matrix per ISO/IEC 14496-12 §8.3.
    ///
    /// The first six elements are written in 16.16 fixed-point; the last three
    /// in 2.30 fixed-point. Triggers `precondition` if the array is not exactly
    /// 9 elements long.
    public mutating func writeMatrix3x3(_ values: [Double]) {
        precondition(
            values.count == 9,
            "writeMatrix3x3 requires exactly 9 elements, got \(values.count)"
        )
        for valueIndex in 0..<6 {
            writeFixed16_16(values[valueIndex])
        }
        for valueIndex in 6..<9 {
            writeFixed2_30(values[valueIndex])
        }
    }

    // MARK: UUID

    /// Append a 16-byte UUID (big-endian per RFC 4122 wire encoding).
    public mutating func writeUUID(_ uuid: UUID) {
        let tuple = uuid.uuid
        writeUInt8(tuple.0)
        writeUInt8(tuple.1)
        writeUInt8(tuple.2)
        writeUInt8(tuple.3)
        writeUInt8(tuple.4)
        writeUInt8(tuple.5)
        writeUInt8(tuple.6)
        writeUInt8(tuple.7)
        writeUInt8(tuple.8)
        writeUInt8(tuple.9)
        writeUInt8(tuple.10)
        writeUInt8(tuple.11)
        writeUInt8(tuple.12)
        writeUInt8(tuple.13)
        writeUInt8(tuple.14)
        writeUInt8(tuple.15)
    }

    // MARK: Language code

    /// Append a packed ISO 639-2/T language code per ISO/IEC 14496-12 §8.4.2.3.
    ///
    /// `code` must be exactly 3 lowercase ASCII letters in `a–z`. Each character
    /// is mapped to its 5-bit `letter - 0x60` representation; the three values
    /// are packed into the low 15 bits of a 16-bit big-endian word.
    public mutating func writeLanguageCode(_ code: String) {
        let scalars = code.unicodeScalars
        precondition(
            scalars.count == 3,
            "Language code must be 3 characters, got \(scalars.count): \(code)"
        )
        var packed: UInt16 = 0
        for scalar in scalars {
            precondition(
                (0x61...0x7A).contains(scalar.value),
                "Language code requires lowercase a-z letters, got: \(code)"
            )
            packed = (packed << 5) | UInt16(scalar.value - 0x60)
        }
        writeUInt16(packed)
    }

    // MARK: Padding

    /// Append `count` zero bytes.
    public mutating func writeZeros(_ count: Int) {
        guard count > 0 else { return }
        data.append(contentsOf: Array(repeating: UInt8(0), count: count))
    }

    // MARK: Box helpers

    /// Append a complete box (size + type + body) per ISO/IEC 14496-12 §4.2.
    ///
    /// Auto-selects the 64-bit `largesize` encoding (`size = 1` + 8-byte
    /// largesize) whenever the total box size would not fit in a 32-bit field.
    public mutating func writeBox(type: FourCC, body: Data) {
        writeBoxHeader(type: type, bodySize: UInt64(body.count))
        data.append(body)
    }

    /// Append a complete box, building the body via a closure.
    public mutating func writeBox(type: FourCC, build: (inout BinaryWriter) -> Void) {
        var bodyWriter = BinaryWriter()
        build(&bodyWriter)
        writeBox(type: type, body: bodyWriter.data)
    }

    /// Append a full box (size + type + version + flags + body) per
    /// ISO/IEC 14496-12 §4.2.
    public mutating func writeFullBox(type: FourCC, version: UInt8, flags: UInt32, body: Data) {
        precondition(
            flags <= 0x00FF_FFFF,
            "FullBox flags must fit in 24 bits, got 0x\(String(flags, radix: 16))"
        )
        let totalBodySize = UInt64(body.count) + 4  // version + flags
        writeBoxHeader(type: type, bodySize: totalBodySize)
        writeUInt8(version)
        writeUInt24(flags)
        data.append(body)
    }

    /// Append a full box, building the body via a closure.
    public mutating func writeFullBox(
        type: FourCC,
        version: UInt8,
        flags: UInt32,
        build: (inout BinaryWriter) -> Void
    ) {
        var bodyWriter = BinaryWriter()
        build(&bodyWriter)
        writeFullBox(type: type, version: version, flags: flags, body: bodyWriter.data)
    }

    /// Emit the box framing (size + type), choosing between the standard 8-byte
    /// header and the 16-byte largesize header.
    ///
    /// Exposed at `internal` scope for tests that exercise the largesize
    /// boundary without materialising a multi-GiB body.
    ///
    /// - Parameters:
    ///   - type: FourCC type of the box.
    ///   - bodySize: Body size in bytes (everything after the size+type framing).
    internal mutating func writeBoxHeader(type: FourCC, bodySize: UInt64) {
        // Standard header is 8 bytes: 4 size + 4 type.
        // Largesize header is 16 bytes: 4 size (= 1) + 4 type + 8 largesize.
        let standardTotal = bodySize &+ 8
        let useLargesize = standardTotal > UInt64(UInt32.max)
        if useLargesize {
            writeUInt32(1)  // size = 1 sentinel
            writeFourCC(type)
            writeUInt64(bodySize &+ 16)  // total box size in largesize field
        } else {
            writeUInt32(UInt32(standardTotal))
            writeFourCC(type)
        }
    }
}
