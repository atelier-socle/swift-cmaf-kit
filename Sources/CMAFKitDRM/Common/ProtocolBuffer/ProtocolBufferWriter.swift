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

/// Zero-dependency Protocol Buffer wire-format writer (proto2 / proto3).
///
/// `ProtocolBufferWriter` is the counterpart to ``ProtocolBufferReader``
/// — it accumulates bytes into the four wire types CMAFKitDRM emits:
///
/// - wire type 0 — VARINT (`uint32` / `uint64` / `sint32` / `sint64` / `bool` / `enum`)
/// - wire type 1 — I64 (`fixed64` / `sfixed64` / `double`)
/// - wire type 2 — LEN (`string` / `bytes` / embedded messages / packed repeated)
/// - wire type 5 — I32 (`fixed32` / `sfixed32` / `float`)
///
/// CMAFKitDRM emits fields in ascending field-number order, which is
/// the canonical form callers can rely on for byte-perfect round-trip
/// with ``ProtocolBufferReader``.
///
/// ## Public visibility
///
/// `ProtocolBufferWriter` is intentionally public so consumers
/// implementing a custom DRM provider that conforms to
/// ``DRMInitDataParsing`` can encode protocol-buffer-shaped init data
/// without adding a third-party dependency. The API surface is
/// deliberately minimal — only the wire types required by the typed
/// providers shipped by CMAFKitDRM are supported. For full Protocol
/// Buffer compliance (`oneof`, `repeated`, embedded message nesting
/// with schema validation, JSON serialisation), consumers should
/// adopt [swift-protobuf](https://github.com/apple/swift-protobuf)
/// directly.
///
/// ## Example
///
/// ```swift
/// var writer = ProtocolBufferWriter()
/// writer.writeVarintField(fieldNumber: 1, value: 42)
/// writer.writeStringField(fieldNumber: 2, value: "provider-x")
/// let bytes = writer.data
/// ```
public struct ProtocolBufferWriter: Sendable {

    /// The accumulated wire-format bytes.
    public private(set) var data: Data

    /// Initialises an empty writer.
    public init() {
        self.data = Data()
    }

    // MARK: - Low-level wire-format writes

    /// Appends a base-128 VARINT.
    ///
    /// VARINT carries values up to 64 bits using 7 bits of payload
    /// per byte; the MSB of each byte signals whether another byte
    /// follows.
    ///
    /// - Parameter value: The 64-bit unsigned value to encode.
    public mutating func writeVarint(_ value: UInt64) {
        var v = value
        while v > 0x7F {
            data.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v & 0x7F))
    }

    /// Appends a field tag composed of field number and wire type.
    ///
    /// The wire shape is `(field_number << 3) | wire_type` encoded as
    /// a VARINT.
    ///
    /// - Parameters:
    ///   - fieldNumber: Protocol Buffer field number (must be `>= 1`).
    ///   - wireType: Wire type in `0...5` per the encoding spec.
    public mutating func writeTag(fieldNumber: UInt32, wireType: UInt8) {
        precondition(fieldNumber > 0, "Protocol Buffer field number must be >= 1")
        precondition(wireType <= 5, "Wire type must be in 0...5")
        let raw = (UInt64(fieldNumber) << 3) | UInt64(wireType & 0x07)
        writeVarint(raw)
    }

    /// Appends a length-prefixed byte sequence (wire type 2 — LEN).
    ///
    /// Use for `string`, `bytes`, embedded messages, or packed
    /// repeated fields.
    ///
    /// - Parameter bytes: The payload to emit length-prefixed.
    public mutating func writeLengthDelimited(_ bytes: Data) {
        writeVarint(UInt64(bytes.count))
        data.append(bytes)
    }

    /// Appends a fixed 32-bit integer in little-endian byte order
    /// (wire type 5 — I32).
    ///
    /// - Parameter value: The `UInt32` value to encode.
    public mutating func writeFixed32(_ value: UInt32) {
        for shift in 0..<4 {
            data.append(UInt8((value >> (shift * 8)) & 0xFF))
        }
    }

    /// Appends a fixed 64-bit integer in little-endian byte order
    /// (wire type 1 — I64).
    ///
    /// - Parameter value: The `UInt64` value to encode.
    public mutating func writeFixed64(_ value: UInt64) {
        for shift in 0..<8 {
            data.append(UInt8((value >> (shift * 8)) & 0xFF))
        }
    }

    // MARK: - Typed convenience writes

    /// Appends a `(tag, VARINT)` pair for a single VARINT-typed field.
    ///
    /// - Parameters:
    ///   - fieldNumber: Protocol Buffer field number.
    ///   - value: The 64-bit unsigned value to encode.
    public mutating func writeVarintField(
        fieldNumber: UInt32, value: UInt64
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 0)
        writeVarint(value)
    }

    /// Appends a `(tag, length-prefixed bytes)` pair for a `bytes`
    /// or embedded-message field.
    ///
    /// - Parameters:
    ///   - fieldNumber: Protocol Buffer field number.
    ///   - value: The bytes to emit length-prefixed.
    public mutating func writeBytesField(
        fieldNumber: UInt32, value: Data
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 2)
        writeLengthDelimited(value)
    }

    /// Appends a `(tag, length-prefixed UTF-8 bytes)` pair for a
    /// `string` field.
    ///
    /// - Parameters:
    ///   - fieldNumber: Protocol Buffer field number.
    ///   - value: The string to encode as UTF-8.
    public mutating func writeStringField(
        fieldNumber: UInt32, value: String
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 2)
        writeLengthDelimited(Data(value.utf8))
    }

    /// Appends a `(tag, fixed32)` pair.
    ///
    /// - Parameters:
    ///   - fieldNumber: Protocol Buffer field number.
    ///   - value: The `UInt32` value to encode.
    public mutating func writeFixed32Field(
        fieldNumber: UInt32, value: UInt32
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 5)
        writeFixed32(value)
    }

    /// Appends a `(tag, fixed64)` pair.
    ///
    /// - Parameters:
    ///   - fieldNumber: Protocol Buffer field number.
    ///   - value: The `UInt64` value to encode.
    public mutating func writeFixed64Field(
        fieldNumber: UInt32, value: UInt64
    ) {
        writeTag(fieldNumber: fieldNumber, wireType: 1)
        writeFixed64(value)
    }
}
