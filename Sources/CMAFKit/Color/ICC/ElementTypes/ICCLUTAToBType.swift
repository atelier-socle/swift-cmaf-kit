// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCLUTAToBType
//
// Reference: ICC.1:2022 §10.11 (lutAToBType, signature 'mAB ').
//
// Byte-preserved fallback: the typed-field surface is reduced to the
// channel counts; the variable-length body (offsets table + curves +
// matrix + CLUT) is preserved verbatim for byte-perfect round-trip.

import Foundation

/// AToB LUT type per ICC.1:2022 §10.11, byte-preserved.
public struct ICCLUTAToBType: Sendable, Hashable, Equatable, Codable {
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
    ) throws -> ICCLUTAToBType {
        let inputChannels = try reader.readUInt8()
        let outputChannels = try reader.readUInt8()
        try reader.skip(2)  // reserved
        let remaining = byteCount - 4
        let rawPayload = try reader.readData(count: max(0, remaining))
        return ICCLUTAToBType(
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
