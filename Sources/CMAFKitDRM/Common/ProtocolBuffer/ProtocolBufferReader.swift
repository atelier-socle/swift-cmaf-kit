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

/// Zero-dependency Protocol Buffer wire-format reader (proto2/proto3).
///
/// The reader is value-typed; `mutating` methods advance an internal
/// cursor. Errors thrown by every read method are
/// ``DRMSystemError`` cases carrying the DRM system identifier so
/// callers can route the error appropriately.
public struct ProtocolBufferReader: Sendable {
    /// The system identifier reported in errors thrown by this
    /// reader. Carried verbatim into ``DRMSystemError`` cases.
    public let systemID: KnownDRMSystemID

    private let data: Data
    private var offset: Int

    public init(_ data: Data, systemID: KnownDRMSystemID = .widevine) {
        self.data = data
        self.offset = 0
        self.systemID = systemID
    }

    /// True when at least one more byte is available.
    public var hasMore: Bool { offset < data.count }

    /// 0-based byte cursor relative to the input buffer.
    public var cursor: Int { offset }

    /// Number of bytes remaining in the buffer.
    public var remaining: Int { data.count - offset }

    // MARK: - Low-level wire-format reads

    /// Read a base-128 VARINT. Per the encoding spec a VARINT is at
    /// most 10 bytes (a 64-bit value carries at most ten 7-bit
    /// payload groups plus continuation bits).
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

    /// Read a field tag: `(field_number << 3) | wire_type`.
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

    /// Read a length-prefixed byte sequence (wire type 2).
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

    /// Read an unsigned 32-bit fixed integer (wire type 5; LE).
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

    /// Read an unsigned 64-bit fixed integer (wire type 1; LE).
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

    /// Skip an unknown field by consuming the matching number of
    /// bytes per its wire type.
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
