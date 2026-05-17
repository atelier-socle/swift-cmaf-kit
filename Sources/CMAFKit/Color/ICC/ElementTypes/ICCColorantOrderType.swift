// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCColorantOrderType
//
// Reference: ICC.1:2022 §10.6 (colorantOrderType, signature 'clro').
//
// On-wire layout: UInt32 colorantCount + colorantCount × UInt8 colorantIndex.

import Foundation

/// Colorant order type per ICC.1:2022 §10.6.
public struct ICCColorantOrderType: Sendable, Hashable, Equatable, Codable {
    public let order: [UInt8]

    public init(order: [UInt8]) {
        self.order = order
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCColorantOrderType {
        let count = try reader.readUInt32()
        let data = try reader.readData(count: Int(count))
        return ICCColorantOrderType(order: Array(data))
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt32(UInt32(order.count))
        writer.writeData(Data(order))
    }
}
