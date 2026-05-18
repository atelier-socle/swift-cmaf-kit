// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SamplingRateBox (srat)
//
// Reference: ISO/IEC 14496-12 §12.2.5 (sampling rate box).
//
// High-precision sampling rate override carried as a full box child of
// an audio sample entry. When present, supersedes the legacy 16.16
// fixed-point `sampleRate` stored in ``AudioSampleEntryFields``.

import Foundation

/// Sampling rate box (`srat`) — full box carrying a 32-bit sample rate.
public struct SamplingRateBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "srat"

    public let version: UInt8
    public let flags: UInt32
    /// Sampling rate in Hz. A zero value is spec-illegal.
    public let samplingRate: UInt32

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        samplingRate: UInt32
    ) {
        precondition(
            samplingRate > 0,
            "SamplingRateBox.samplingRate must be non-zero per ISO/IEC 14496-12 §12.2.5"
        )
        self.version = version
        self.flags = flags
        self.samplingRate = samplingRate
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SamplingRateBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let samplingRate = try reader.readUInt32()
        guard samplingRate > 0 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "SamplingRateBox samplingRate must be non-zero"
            )
        }
        return SamplingRateBox(version: version, flags: flags, samplingRate: samplingRate)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(samplingRate)
        }
    }
}
