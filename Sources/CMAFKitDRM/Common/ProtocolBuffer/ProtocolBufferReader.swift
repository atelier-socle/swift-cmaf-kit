// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProtocolBufferReader
//
// Reference: Google "Protocol Buffers Encoding" public specification
// (https://protobuf.dev/programming-guides/encoding/). Implements the
// proto2 / proto3 wire format reader for the four wire types used by
// the Widevine `WidevineCencHeader` message:
//
//   wire type 0 — VARINT (uint32/uint64/sint32/sint64/bool/enum)
//   wire type 1 — I64 (fixed64, sfixed64, double)
//   wire type 2 — LEN (string, bytes, embedded messages, packed repeated)
//   wire type 5 — I32 (fixed32, sfixed32, float)
//
// VARINT encoding: 7 bits per byte; MSB of each byte signals whether
// another byte follows. Maximum 10 bytes for a 64-bit value.
//
// CMAFKitDRM ships a hand-written reader rather than depending on
// `swift-protobuf` so the DRM target keeps zero external dependencies.

import Foundation

/// Zero-dependency Protocol Buffer wire-format reader (proto2 / proto3).
///
/// `ProtocolBufferReader` decodes the four wire types CMAFKitDRM uses
/// to parse Widevine `WidevineCencHeader` messages:
///
/// - wire type 0 — VARINT (`uint32` / `uint64` / `sint32` / `sint64` / `bool` / `enum`)
/// - wire type 1 — I64 (`fixed64` / `sfixed64` / `double`)
/// - wire type 2 — LEN (`string` / `bytes` / embedded messages / packed repeated)
/// - wire type 5 — I32 (`fixed32` / `sfixed32` / `float`)
///
/// The reader is value-typed; `mutating` methods advance an internal
/// cursor. Errors thrown by every read method are
/// ``DRMSystemError`` cases carrying the DRM system identifier so
/// callers can route the error appropriately.
///
/// ## Public visibility
///
/// `ProtocolBufferReader` is intentionally public so consumers
/// implementing a custom DRM provider that conforms to
/// ``DRMInitDataParsing`` can decode protocol-buffer-shaped init data
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
/// var reader = ProtocolBufferReader(psshDataBytes, systemID: .widevine)
/// while reader.hasMore {
///     let (fieldNumber, wireType) = try reader.readTag()
///     switch fieldNumber {
///     case 1: let value = try reader.readVarint()
///         _ = value
///     case 2: let bytes = try reader.readLengthDelimited()
///         _ = bytes
///     default: try reader.skip(wireType: wireType)
///     }
/// }
/// ```
public struct ProtocolBufferReader: Sendable {
    /// The system identifier reported in errors thrown by this
    /// reader. Carried verbatim into ``DRMSystemError`` cases so
    /// callers can route the error to the correct provider.
    public let systemID: KnownDRMSystemID

    private let data: Data
    private var offset: Int

    /// Initialises a reader over a Protocol Buffer message payload.
    ///
    /// - Parameters:
    ///   - data: The raw bytes of a Protocol Buffer message (without
    ///     length prefix).
    ///   - systemID: The DRM system identifier reported in any
    ///     ``DRMSystemError`` thrown while reading. Defaults to
    ///     ``KnownDRMSystemID/widevine``.
    public init(_ data: Data, systemID: KnownDRMSystemID = .widevine) {
        self.data = data
        self.offset = 0
        self.systemID = systemID
    }

    /// `true` when at least one more byte is available to read.
    public var hasMore: Bool { offset < data.count }

    /// 0-based byte cursor relative to the input buffer.
    public var cursor: Int { offset }

    /// Number of bytes remaining in the buffer beyond the current
    /// cursor position.
    public var remaining: Int { data.count - offset }

    // MARK: - Low-level wire-format reads

    /// Reads a base-128 VARINT and returns its 64-bit value.
    ///
    /// Per the Protocol Buffers encoding spec a VARINT is at most
    /// 10 bytes — a 64-bit value carries at most ten 7-bit payload
    /// groups plus continuation bits.
    ///
    /// - Returns: The decoded unsigned 64-bit value.
    /// - Throws: ``DRMSystemError/malformedInitData(systemID:reason:)``
    ///   if the buffer is truncated mid-VARINT or the encoded value
    ///   exceeds 64 bits.
    public mutating func readVarint() throws -> UInt64 {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var byteCount = 0
        while offset < data.count {
            let byte = data[data.startIndex + offset]
            offset += 1
            byteCount += 1
            value |= UInt64(byte & 0x7F) << shift
            if (byte & 0x80) == 0 {
                return value
            }
            shift += 7
            if byteCount == 10 {
                // Byte 10 with continuation bit set means the value
                // would overflow 64 bits.
                if (byte & 0x80) != 0 {
                    throw DRMSystemError.malformedInitData(
                        systemID: systemID,
                        reason: "Varint exceeds 64 bits"
                    )
                }
                return value
            }
        }
        throw DRMSystemError.malformedInitData(
            systemID: systemID,
            reason: "Varint truncated"
        )
    }

    /// Reads a field tag and decomposes it into field number and
    /// wire type.
    ///
    /// The tag wire shape is `(field_number << 3) | wire_type`.
    ///
    /// - Returns: A tuple of `(fieldNumber, wireType)`.
    /// - Throws: ``DRMSystemError/malformedInitData(systemID:reason:)``
    ///   if the tag VARINT is truncated or the field number is `0`
    ///   (Protocol Buffers reserves `0` as invalid).
    public mutating func readTag() throws -> (fieldNumber: UInt32, wireType: UInt8) {
        let raw = try readVarint()
        let fieldNumber = UInt32(raw >> 3)
        let wireType = UInt8(raw & 0x07)
        guard fieldNumber > 0 else {
            throw DRMSystemError.malformedInitData(
                systemID: systemID,
                reason: "Tag field number must be >= 1"
            )
        }
        return (fieldNumber, wireType)
    }

    /// Reads a length-prefixed byte sequence (wire type 2 — LEN).
    ///
    /// Use for `string`, `bytes`, embedded messages, or packed
    /// repeated fields. The returned `Data` is a copy of the
    /// length-prefixed payload.
    ///
    /// - Returns: The raw bytes of the LEN field.
    /// - Throws: ``DRMSystemError/malformedInitData(systemID:reason:)``
    ///   if the length VARINT is malformed or the declared length
    ///   exceeds the remaining buffer.
    public mutating func readLengthDelimited() throws -> Data {
        let length = Int(try readVarint())
        guard length >= 0, offset + length <= data.count else {
            throw DRMSystemError.malformedInitData(
                systemID: systemID,
                reason: "Length-delimited field exceeds payload"
            )
        }
        let start = data.startIndex + offset
        let end = start + length
        offset += length
        return Data(data[start..<end])
    }

    /// Reads an unsigned 32-bit fixed integer in little-endian byte
    /// order (wire type 5 — I32).
    ///
    /// - Returns: The decoded `UInt32` value.
    /// - Throws: ``DRMSystemError/malformedInitData(systemID:reason:)``
    ///   if fewer than 4 bytes remain in the buffer.
    public mutating func readFixed32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw DRMSystemError.malformedInitData(
                systemID: systemID,
                reason: "Fixed32 read past end"
            )
        }
        var value: UInt32 = 0
        for shift in 0..<4 {
            value |= UInt32(data[data.startIndex + offset + shift]) << (shift * 8)
        }
        offset += 4
        return value
    }

    /// Reads an unsigned 64-bit fixed integer in little-endian byte
    /// order (wire type 1 — I64).
    ///
    /// - Returns: The decoded `UInt64` value.
    /// - Throws: ``DRMSystemError/malformedInitData(systemID:reason:)``
    ///   if fewer than 8 bytes remain in the buffer.
    public mutating func readFixed64() throws -> UInt64 {
        guard offset + 8 <= data.count else {
            throw DRMSystemError.malformedInitData(
                systemID: systemID,
                reason: "Fixed64 read past end"
            )
        }
        var value: UInt64 = 0
        for shift in 0..<8 {
            value |= UInt64(data[data.startIndex + offset + shift]) << (shift * 8)
        }
        offset += 8
        return value
    }

    /// Skips an unknown field by consuming the appropriate number of
    /// bytes for the given wire type.
    ///
    /// Use this to tolerate forward-compat schema additions: when a
    /// parser sees a tag it does not recognise, calling `skip` advances
    /// past the field's value bytes without interpreting them.
    ///
    /// - Parameter wireType: The wire type extracted from the field tag.
    /// - Throws: ``DRMSystemError/malformedInitData(systemID:reason:)``
    ///   for unknown wire types or for truncated input.
    public mutating func skip(wireType: UInt8) throws {
        switch wireType {
        case 0:
            _ = try readVarint()
        case 1:
            _ = try readFixed64()
        case 2:
            _ = try readLengthDelimited()
        case 5:
            _ = try readFixed32()
        default:
            throw DRMSystemError.malformedInitData(
                systemID: systemID,
                reason: "Unknown wire type \(wireType)"
            )
        }
    }
}
