// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MovieFragmentHeaderBox (mfhd)
//
// Reference: ISO/IEC 14496-12 §8.8.5 (movie fragment header box).
//
// Carries the sequence number of this fragment within the presentation.
// Consumers use it to detect missing or out-of-order fragments.

import Foundation

/// Movie-fragment header.
///
/// `sequenceNumber` is 1-based and strictly increasing within a single
/// presentation.
public struct MovieFragmentHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "mfhd"

    public let version: UInt8
    public let flags: UInt32
    /// 1-based sequence number of this fragment in the presentation.
    public let sequenceNumber: UInt32

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        sequenceNumber: UInt32
    ) {
        self.version = version
        self.flags = flags
        self.sequenceNumber = sequenceNumber
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MovieFragmentHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let sequenceNumber = try reader.readUInt32()
        return MovieFragmentHeaderBox(
            version: version,
            flags: flags,
            sequenceNumber: sequenceNumber
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(sequenceNumber)
        }
    }
}
