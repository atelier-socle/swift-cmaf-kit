// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BinaryReader
//
// Big-endian binary reader over a `Data` buffer. Underpins every ISOBMFF box
// parser. Reference: ISO/IEC 14496-12 §4.2 (object structured representation),
// §8.3 (matrix layout), §8.4.2.3 (language code packing).

import Foundation

/// Big-endian binary reader over a `Data` buffer.
///
/// Every multi-byte integer read consumes bytes in network (big-endian) order.
/// Throws ``BinaryIOError/insufficientData(expected:available:)`` whenever the
/// buffer does not contain the requested number of bytes.
public struct BinaryReader: Sendable {

    /// Backing buffer.
    public let data: Data

    /// Current read offset, in bytes, from the start of `data`.
    public private(set) var offset: Int

    /// Construct a reader over `data`, starting at `offset`.
    public init(_ data: Data, offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    /// Number of bytes remaining after `offset`.
    public var remaining: Int { max(0, data.count - offset) }

    // MARK: Unsigned integers

    /// Read a `UInt8`.
    public mutating func readUInt8() throws -> UInt8 {
        try ensure(1)
        let byte = data[data.startIndex + offset]
        offset += 1
        return byte
    }

    /// Read a big-endian `UInt16`.
    public mutating func readUInt16() throws -> UInt16 {
        try ensure(2)
        let b0 = UInt16(data[data.startIndex + offset])
        let b1 = UInt16(data[data.startIndex + offset + 1])
        offset += 2
        return (b0 << 8) | b1
    }

    /// Read a big-endian 24-bit unsigned integer into the low bits of a `UInt32`.
    public mutating func readUInt24() throws -> UInt32 {
        try ensure(3)
        let b0 = UInt32(data[data.startIndex + offset])
        let b1 = UInt32(data[data.startIndex + offset + 1])
        let b2 = UInt32(data[data.startIndex + offset + 2])
        offset += 3
        return (b0 << 16) | (b1 << 8) | b2
    }

    /// Read a big-endian `UInt32`.
    public mutating func readUInt32() throws -> UInt32 {
        try ensure(4)
        let b0 = UInt32(data[data.startIndex + offset])
        let b1 = UInt32(data[data.startIndex + offset + 1])
        let b2 = UInt32(data[data.startIndex + offset + 2])
        let b3 = UInt32(data[data.startIndex + offset + 3])
        offset += 4
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    /// Read a big-endian `UInt64`.
    public mutating func readUInt64() throws -> UInt64 {
        try ensure(8)
        var value: UInt64 = 0
        for byteIndex in 0..<8 {
            value = (value << 8) | UInt64(data[data.startIndex + offset + byteIndex])
        }
        offset += 8
        return value
    }

    // MARK: Signed integers

    /// Read a big-endian `Int16` (two's complement).
    public mutating func readInt16() throws -> Int16 {
        Int16(bitPattern: try readUInt16())
    }

    /// Read a big-endian `Int32` (two's complement).
    public mutating func readInt32() throws -> Int32 {
        Int32(bitPattern: try readUInt32())
    }

    // MARK: Bytes

    /// Read exactly `count` bytes as a `Data` slice (copied — independent storage).
    public mutating func readData(count: Int) throws -> Data {
        try ensure(count)
        let start = data.startIndex + offset
        let bytes = data.subdata(in: start..<(start + count))
        offset += count
        return bytes
    }

    /// Read exactly `count` bytes as an array of `UInt8`.
    public mutating func readBytes(count: Int) throws -> [UInt8] {
        try ensure(count)
        let start = data.startIndex + offset
        var out = [UInt8]()
        out.reserveCapacity(count)
        for byteIndex in 0..<count {
            out.append(data[start + byteIndex])
        }
        offset += count
        return out
    }

    // MARK: FourCC

    /// Read a 4-byte FourCC. Throws ``BinaryIOError/invalidFourCC(bytes:)`` if
    /// any byte is not ASCII.
    public mutating func readFourCC() throws -> FourCC {
        try ensure(4)
        let bytes = Array(data[(data.startIndex + offset)..<(data.startIndex + offset + 4)])
        for byte in bytes where byte > 0x7F {
            throw BinaryIOError.invalidFourCC(bytes: bytes)
        }
        offset += 4

        let value =
            (UInt32(bytes[0]) << 24)
            | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8)
            | UInt32(bytes[3])
        return FourCC(value)
    }

    // MARK: Strings

    /// Read `length` bytes and decode them as a string in the requested encoding.
    public mutating func readString(length: Int, encoding: String.Encoding = .utf8) throws -> String {
        let bytes = try readData(count: length)
        guard let string = String(data: bytes, encoding: encoding) else {
            throw BinaryIOError.invalidString(encodingRawValue: encoding.rawValue)
        }
        return string
    }

    /// Read bytes until a null terminator (`0x00`) is found; the terminator is
    /// consumed but not included in the result.
    public mutating func readNullTerminatedString(encoding: String.Encoding = .utf8) throws -> String {
        var bytes: [UInt8] = []
        while true {
            let byte = try readUInt8()
            if byte == 0 { break }
            bytes.append(byte)
        }
        let payload = Data(bytes)
        guard let string = String(data: payload, encoding: encoding) else {
            throw BinaryIOError.invalidString(encodingRawValue: encoding.rawValue)
        }
        return string
    }

    // MARK: Fixed-point

    /// Read an 8.8 fixed-point number (16 bits signed).
    public mutating func readFixed8_8() throws -> Double {
        let raw = try readInt16()
        return Double(raw) / 256.0
    }

    /// Read a 16.16 fixed-point number (32 bits signed).
    public mutating func readFixed16_16() throws -> Double {
        let raw = try readInt32()
        return Double(raw) / 65536.0
    }

    /// Read a 2.30 fixed-point number (32 bits signed).
    ///
    /// Used by ISO/IEC 14496-12 §8.3 for the last three elements of the
    /// transformation matrix. The constant `0x40000000` represents `1.0`.
    public mutating func readFixed2_30() throws -> Double {
        let raw = try readInt32()
        return Double(raw) / Double(1 << 30)
    }

    // MARK: Matrix

    /// Read the 9-element transformation matrix per ISO/IEC 14496-12 §8.3.
    ///
    /// The first six elements are 16.16 fixed-point; the last three are 2.30
    /// fixed-point. The identity matrix on disk is
    /// `[0x00010000, 0, 0, 0, 0x00010000, 0, 0, 0, 0x40000000]`
    /// which decodes to `[1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]`.
    public mutating func readMatrix3x3() throws -> [Double] {
        var values: [Double] = []
        values.reserveCapacity(9)
        for _ in 0..<6 {
            values.append(try readFixed16_16())
        }
        for _ in 0..<3 {
            values.append(try readFixed2_30())
        }
        return values
    }

    // MARK: UUID

    /// Read a 16-byte UUID (big-endian per RFC 4122 wire encoding).
    public mutating func readUUID() throws -> UUID {
        let bytes = try readBytes(count: 16)
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }

    // MARK: Language code

    /// Read a packed ISO 639-2/T language code per ISO/IEC 14496-12 §8.4.2.3.
    ///
    /// Reads a 16-bit big-endian value. The high bit is reserved (`0`); the
    /// remaining 15 bits hold three 5-bit characters, each offset by `0x60`
    /// (so `'a' = 1`, `'b' = 2`, …, `'z' = 26`). Returns a 3-character
    /// lowercase string such as `"eng"`, `"fra"`, or `"und"`.
    public mutating func readLanguageCode() throws -> String {
        let packed = try readUInt16()
        let c0 = UInt8((packed >> 10) & 0x1F) &+ 0x60
        let c1 = UInt8((packed >> 5) & 0x1F) &+ 0x60
        let c2 = UInt8(packed & 0x1F) &+ 0x60
        return String(decoding: [c0, c1, c2], as: UTF8.self)
    }

    // MARK: Skip / peek / readToEnd

    /// Advance the offset by `count` bytes. Throws if there are not enough bytes.
    public mutating func skip(_ count: Int) throws {
        try ensure(count)
        offset += count
    }

    /// Return the next `count` bytes without advancing the offset.
    public func peek(_ count: Int) throws -> Data {
        guard remaining >= count else {
            throw BinaryIOError.insufficientData(expected: count, available: remaining)
        }
        let start = data.startIndex + offset
        return data.subdata(in: start..<(start + count))
    }

    /// Consume and return all remaining bytes.
    public mutating func readToEnd() -> Data {
        let rest = data.subdata(in: (data.startIndex + offset)..<data.endIndex)
        offset = data.count
        return rest
    }

    // MARK: Internals

    private func ensure(_ count: Int) throws {
        guard remaining >= count else {
            throw BinaryIOError.insufficientData(expected: count, available: remaining)
        }
    }
}
