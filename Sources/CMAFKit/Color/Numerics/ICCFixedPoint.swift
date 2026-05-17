// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICC fixed-point numerics
//
// Reference: ICC.1:2022 §4.6 (s15Fixed16Number) + §4.7 (u16Fixed16Number).
//
// Fixed-point numbers stored as Int32 / UInt32 big-endian on the wire.

import Foundation

/// Signed 15-bit-integer + 16-bit-fraction fixed-point number.
///
/// Reference: ICC.1:2022 §4.6.
public struct ICCS15Fixed16Number: Sendable, Hashable, Codable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public init(_ value: Double) {
        let scaled = value * 65536.0
        self.rawValue = Int32(scaled.rounded())
    }

    public var doubleValue: Double {
        Double(rawValue) / 65536.0
    }

    public static func parse(reader: inout BinaryReader) throws -> ICCS15Fixed16Number {
        let raw = try reader.readInt32()
        return ICCS15Fixed16Number(rawValue: raw)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeInt32(rawValue)
    }
}

/// Unsigned 16-bit-integer + 16-bit-fraction fixed-point number.
///
/// Reference: ICC.1:2022 §4.7.
public struct ICCU16Fixed16Number: Sendable, Hashable, Codable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(_ value: Double) {
        let scaled = value * 65536.0
        self.rawValue = UInt32(scaled.rounded())
    }

    public var doubleValue: Double {
        Double(rawValue) / 65536.0
    }

    public static func parse(reader: inout BinaryReader) throws -> ICCU16Fixed16Number {
        let raw = try reader.readUInt32()
        return ICCU16Fixed16Number(rawValue: raw)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeUInt32(rawValue)
    }
}
