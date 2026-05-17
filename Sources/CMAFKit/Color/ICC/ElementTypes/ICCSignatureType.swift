// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCSignatureType
//
// Reference: ICC.1:2022 §10.23 (signatureType, signature 'sig ').
// Payload: a single UInt32 signature value.

import Foundation

/// Signature type per ICC.1:2022 §10.23.
public struct ICCSignatureType: Sendable, Hashable, Equatable, Codable {
    public let signature: UInt32

    public init(signature: UInt32) {
        self.signature = signature
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCSignatureType {
        return ICCSignatureType(signature: try reader.readUInt32())
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt32(signature)
    }
}
