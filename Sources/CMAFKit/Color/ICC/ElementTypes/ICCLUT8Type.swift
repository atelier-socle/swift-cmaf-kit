// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCLUT8Type
//
// Reference: ICC.1:2022 §10.9 (lut8Type, signature 'mft1').
//
// Byte-preserved fallback: the typed-field surface is reduced to the
// channel counts; the variable-length body (matrix + input tables +
// CLUT + output tables) is preserved verbatim for byte-perfect
// round-trip. The full typed view is deferred to a future release.

import Foundation

/// LUT8 type per ICC.1:2022 §10.9, byte-preserved.
public struct ICCLUT8Type: Sendable, Hashable, Equatable, Codable {
    public let inputChannels: UInt8
    public let outputChannels: UInt8
    public let clutPoints: UInt8
    /// Body bytes after the 4-byte channel header (`inputChannels +
    /// outputChannels + clutPoints + reserved`), preserved verbatim.
    public let rawPayload: Data

    public init(inputChannels: UInt8, outputChannels: UInt8, clutPoints: UInt8, rawPayload: Data) {
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
        self.clutPoints = clutPoints
        self.rawPayload = rawPayload
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCLUT8Type {
        let inputChannels = try reader.readUInt8()
        let outputChannels = try reader.readUInt8()
        let clutPoints = try reader.readUInt8()
        try reader.skip(1)  // reserved
        let remaining = byteCount - 4
        let rawPayload = try reader.readData(count: max(0, remaining))
        return ICCLUT8Type(
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            clutPoints: clutPoints,
            rawPayload: rawPayload
        )
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt8(inputChannels)
        writer.writeUInt8(outputChannels)
        writer.writeUInt8(clutPoints)
        writer.writeZeros(1)
        writer.writeData(rawPayload)
    }
}
