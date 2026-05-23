// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProtocolBufferWriter
//
// Reference: Google "Protocol Buffers Encoding" public specification.
// Counterpart to ``ProtocolBufferReader`` — emits the proto2 / proto3
// wire format for the four wire types used by CMAFKitDRM:
//
//   wire type 0 — VARINT
//   wire type 1 — I64
//   wire type 2 — LEN
//   wire type 5 — I32
//
// CMAFKitDRM emits fields in ascending field-number order, which is
// the canonical form callers can rely on for byte-perfect round-trip
// with ``ProtocolBufferReader``.

import Foundation

/// Zero-dependency Protocol Buffer wire-format writer.
public struct ProtocolBufferWriter: Sendable {

    /// The accumulated wire-format bytes.
    public private(set) var data: Data

    public init() {
        self.data = Data()
    }

    // MARK: - Low-level wire-format writes

    /// Append a base-128 VARINT.
    public mutating func writeVarint(_ value: UInt64) {
        var v = value
        while v > 0x7F {
            data.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v & 0x7F))
    }

    /// Append a tag: `(field_number << 3) | wire_type`.
    public mutating func writeTag(fieldNumber: UInt32, wireType: UInt8) {
        precondition(fieldNumber > 0, "Protocol Buffer field number must be >= 1")
        precondition(wireType <= 5, "Wire type must be in 0...5")
        let raw = (UInt64(fieldNumber) << 3) | UInt64(wireType & 0x07)
        writeVarint(raw)
    }

    /// Append a length-prefixed byte sequence (wire type 2).
    public mutating func writeLengthDelimited(_ bytes: Data) {
        writeVarint(UInt64(bytes.count))
        data.append(bytes)
    }

    /// Append a fixed 32-bit integer (wire type 5; LE).
    public mutating func writeFixed32(_ value: UInt32) {
        for shift in 0..<4 {
            data.append(UInt8((value >> (shift * 8)) & 0xFF))
        }
    }

    /// Append a fixed 64-bit integer (wire type 1; LE).
    public mutating func writeFixed64(_ value: UInt64) {
        for shift in 0..<8 {
            data.append(UInt8((value >> (shift * 8)) & 0xFF))
        }
    }

    // MARK: - Typed convenience writes

    /// Append a `(tag, varint)` pair.
    public mutating func writeVarintField(
        fieldNumber: UInt32, value: UInt64
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 0)
        writeVarint(value)
    }

    /// Append a `(tag, length-prefixed bytes)` pair.
    public mutating func writeBytesField(
        fieldNumber: UInt32, value: Data
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 2)
        writeLengthDelimited(value)
    }

    /// Append a `(tag, length-prefixed UTF-8 bytes)` pair.
    public mutating func writeStringField(
        fieldNumber: UInt32, value: String
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 2)
        writeLengthDelimited(Data(value.utf8))
    }

    /// Append a `(tag, fixed32)` pair.
    public mutating func writeFixed32Field(
        fieldNumber: UInt32, value: UInt32
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 5)
        writeFixed32(value)
    }

    /// Append a `(tag, fixed64)` pair.
    public mutating func writeFixed64Field(
        fieldNumber: UInt32, value: UInt64
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 1)
        writeFixed64(value)
    }
}
