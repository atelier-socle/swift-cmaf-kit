// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AC4SpecificBox (dac4)
//
// Reference: ETSI TS 103 190-2 Annex E.
//
// On-wire layout (after the 8-byte box header):
//   UInt8  (ac4_dsi_version: 3 | bitstream_version_hi: 5)
//   UInt8  (bitstream_version_lo: 2 | ... presentation count and other
//            bit-level fields)
//
// The AC-4 TOC is a variable-bit structure. CMAFKit fully types the
// top-level fields and each presentation entry's byte-length envelope;
// the inner bitstream is preserved as `Data` for decoding by a future
// bitstream parser.

import Foundation

/// AC-4 specific box (`dac4`).
public struct AC4SpecificBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "dac4"

    /// One presentation entry inside the AC-4 TOC.
    public struct PresentationEntry: Sendable, Equatable, Hashable {
        public let presentationVersion: UInt8
        public let presentationConfig: UInt8
        public let presentationLength: UInt16
        /// Bitstream payload of the presentation; decoded by a future
        /// codec-bitstream parser.
        public let presentationBytes: Data

        public init(
            presentationVersion: UInt8,
            presentationConfig: UInt8,
            presentationLength: UInt16,
            presentationBytes: Data
        ) {
            precondition(
                Int(presentationLength) == presentationBytes.count,
                "AC-4 presentationLength must equal presentationBytes.count"
            )
            self.presentationVersion = presentationVersion
            self.presentationConfig = presentationConfig
            self.presentationLength = presentationLength
            self.presentationBytes = presentationBytes
        }
    }

    /// `ac4_dsi_version` — 3-bit value, currently always 1 per ETSI
    /// TS 103 190-2.
    public let dsiVersion: UInt8
    /// Top-level `bitstream_version` field.
    public let bitstreamVersion: UInt8
    public let presentations: [PresentationEntry]

    public init(
        dsiVersion: UInt8 = 1,
        bitstreamVersion: UInt8,
        presentations: [PresentationEntry]
    ) {
        precondition(
            dsiVersion <= 0x07,
            "AC4SpecificBox.dsiVersion must fit in 3 bits"
        )
        self.dsiVersion = dsiVersion
        self.bitstreamVersion = bitstreamVersion
        self.presentations = presentations
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> AC4SpecificBox {
        let bodyByteCount = Int(header.size) - header.headerSize
        let bodyBytes = try reader.readData(count: bodyByteCount)
        var body = BinaryReader(bodyBytes)

        let firstByte = try body.readUInt8()
        let dsiVersion = (firstByte >> 5) & 0x07
        let bitstreamVersion = try body.readUInt8()
        let presentationCount = Int(try body.readUInt8())

        var presentations: [PresentationEntry] = []
        presentations.reserveCapacity(presentationCount)
        for _ in 0..<presentationCount {
            let version = try body.readUInt8()
            let config = try body.readUInt8()
            let length = try body.readUInt16()
            guard body.remaining >= Int(length) else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "AC-4 presentation length \(length) exceeds remaining bytes"
                )
            }
            let bytes = try body.readData(count: Int(length))
            presentations.append(
                PresentationEntry(
                    presentationVersion: version,
                    presentationConfig: config,
                    presentationLength: length,
                    presentationBytes: bytes
                )
            )
        }

        return AC4SpecificBox(
            dsiVersion: dsiVersion,
            bitstreamVersion: bitstreamVersion,
            presentations: presentations
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            let firstByte: UInt8 = (dsiVersion & 0x07) << 5
            body.writeUInt8(firstByte)
            body.writeUInt8(bitstreamVersion)
            body.writeUInt8(UInt8(presentations.count))
            for presentation in presentations {
                body.writeUInt8(presentation.presentationVersion)
                body.writeUInt8(presentation.presentationConfig)
                body.writeUInt16(presentation.presentationLength)
                body.writeData(presentation.presentationBytes)
            }
        }
    }
}
