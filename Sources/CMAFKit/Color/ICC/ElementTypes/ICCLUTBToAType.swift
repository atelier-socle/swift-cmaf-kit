// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCLUTBToAType
//
// Reference: ICC.1:2022 §10.12 (lutBToAType, signature 'mBA ').
//
// Byte-preserved fallback: same shape as ``ICCLUTAToBType`` but with
// the offsets ordered for B→A processing.

import Foundation

/// BToA LUT type per ICC.1:2022 §10.12, byte-preserved.
public struct ICCLUTBToAType: Sendable, Hashable, Equatable, Codable {
    public let inputChannels: UInt8
    public let outputChannels: UInt8
    /// Body bytes after the 4-byte channel header, preserved verbatim.
    public let rawPayload: Data

    public init(inputChannels: UInt8, outputChannels: UInt8, rawPayload: Data) {
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
        self.rawPayload = rawPayload
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCLUTBToAType {
        let inputChannels = try reader.readUInt8()
        let outputChannels = try reader.readUInt8()
        try reader.skip(2)  // reserved
        let remaining = byteCount - 4
        let rawPayload = try reader.readData(count: max(0, remaining))
        return ICCLUTBToAType(
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            rawPayload: rawPayload
        )
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt8(inputChannels)
        writer.writeUInt8(outputChannels)
        writer.writeZeros(2)
        writer.writeData(rawPayload)
    }
}
