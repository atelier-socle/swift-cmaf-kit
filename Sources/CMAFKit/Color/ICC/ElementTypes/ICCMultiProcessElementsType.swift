// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCMultiProcessElementsType
//
// Reference: ICC.1:2022 §10.15 (multiProcessElementsType, signature 'mpet').
//
// Byte-preserved fallback: typed-field surface reduced to the input /
// output channel counts (UInt16). The variable-length body (element
// table + per-element data) is preserved verbatim for byte-perfect
// round-trip.

import Foundation

/// Multi-process elements type per ICC.1:2022 §10.15, byte-preserved.
public struct ICCMultiProcessElementsType: Sendable, Hashable, Equatable, Codable {
    public let inputChannels: UInt16
    public let outputChannels: UInt16
    /// Body bytes after the 4-byte channel header, preserved verbatim.
    public let rawPayload: Data

    public init(inputChannels: UInt16, outputChannels: UInt16, rawPayload: Data) {
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
        self.rawPayload = rawPayload
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCMultiProcessElementsType {
        let inputChannels = try reader.readUInt16()
        let outputChannels = try reader.readUInt16()
        let remaining = byteCount - 4
        let rawPayload = try reader.readData(count: max(0, remaining))
        return ICCMultiProcessElementsType(
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            rawPayload: rawPayload
        )
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt16(inputChannels)
        writer.writeUInt16(outputChannels)
        writer.writeData(rawPayload)
    }
}
