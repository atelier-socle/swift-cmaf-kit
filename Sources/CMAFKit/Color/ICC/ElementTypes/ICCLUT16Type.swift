// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCLUT16Type
//
// Reference: ICC.1:2022 §10.10 (lut16Type, signature 'mft2').
//
// Byte-preserved fallback: the typed-field surface is reduced to the
// channel counts; the variable-length body is preserved verbatim for
// byte-perfect round-trip.

import Foundation

/// LUT16 type per ICC.1:2022 §10.10, byte-preserved.
public struct ICCLUT16Type: Sendable, Hashable, Equatable, Codable {
    public let inputChannels: UInt8
    public let outputChannels: UInt8
    public let clutPoints: UInt8
    /// Body bytes after the 4-byte channel header, preserved verbatim.
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
    ) throws -> ICCLUT16Type {
        let inputChannels = try reader.readUInt8()
        let outputChannels = try reader.readUInt8()
        let clutPoints = try reader.readUInt8()
        try reader.skip(1)  // reserved
        let remaining = byteCount - 4
        let rawPayload = try reader.readData(count: max(0, remaining))
        return ICCLUT16Type(
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
