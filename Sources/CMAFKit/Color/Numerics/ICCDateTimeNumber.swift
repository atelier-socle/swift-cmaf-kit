// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCDateTimeNumber
//
// Reference: ICC.1:2022 §4.5 (dateTimeNumber).
//
// Twelve-byte field carrying year, month, day, hour, minute, second
// as separate UInt16 values, big-endian.

import Foundation

/// ICC profile date-time field per ICC.1:2022 §4.5.
public struct ICCDateTimeNumber: Sendable, Hashable, Codable {
    public let year: UInt16
    public let month: UInt16
    public let day: UInt16
    public let hour: UInt16
    public let minute: UInt16
    public let second: UInt16

    public init(year: UInt16, month: UInt16, day: UInt16, hour: UInt16, minute: UInt16, second: UInt16) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
    }

    public static func parse(reader: inout BinaryReader) throws -> ICCDateTimeNumber {
        let year = try reader.readUInt16()
        let month = try reader.readUInt16()
        let day = try reader.readUInt16()
        let hour = try reader.readUInt16()
        let minute = try reader.readUInt16()
        let second = try reader.readUInt16()
        return ICCDateTimeNumber(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeUInt16(year)
        writer.writeUInt16(month)
        writer.writeUInt16(day)
        writer.writeUInt16(hour)
        writer.writeUInt16(minute)
        writer.writeUInt16(second)
    }
}
