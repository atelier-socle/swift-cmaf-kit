// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AV1OBU
//
// Reference: AOMedia AV1 Bitstream §5.3.1 + §5.3.2.
//
// One-byte OBU header (plus optional one-byte extension header)
// followed by an optional leb128 size field and the payload. CMAFKit
// captures the payload as `Data` for non-sequence-header OBUs; the
// sequence-header OBU is parsed by ``AV1SequenceHeader``.

import Foundation

/// AV1 Open Bitstream Unit per AOMedia AV1 Bitstream §5.3.
public struct AV1OBU: Sendable, Hashable, Equatable {

    /// One-byte (or two-byte with extension) OBU header.
    public struct Header: Sendable, Hashable, Equatable {
        public let obuType: AV1OBUType
        public let hasSizeField: Bool
        public let `extension`: Extension?

        public struct Extension: Sendable, Hashable, Equatable {
            public let temporalID: UInt8
            public let spatialID: UInt8

            public init(temporalID: UInt8, spatialID: UInt8) {
                precondition(temporalID <= 0x07, "temporalID must fit 3 bits")
                precondition(spatialID <= 0x03, "spatialID must fit 2 bits")
                self.temporalID = temporalID
                self.spatialID = spatialID
            }
        }

        public init(obuType: AV1OBUType, hasSizeField: Bool, extension: Extension? = nil) {
            self.obuType = obuType
            self.hasSizeField = hasSizeField
            self.`extension` = `extension`
        }
    }

    public let header: Header
    public let payload: Data

    public init(header: Header, payload: Data) {
        self.header = header
        self.payload = payload
    }

    /// Parse a single OBU starting at the current cursor of `data`.
    /// Returns the parsed OBU and the number of bytes consumed.
    public static func parse(data: Data, at offset: Int = 0) throws -> (obu: AV1OBU, byteCount: Int) {
        guard offset < data.count else {
            throw BitstreamError.truncated(codec: "AV1", field: "obu_header")
        }
        let headerByte = data[data.startIndex + offset]
        let forbidden = (headerByte & 0x80) != 0
        guard !forbidden else {
            throw BitstreamError.reservedBitsNonZero(codec: "AV1", field: "obu_forbidden_bit")
        }
        let typeRaw = (headerByte >> 3) & 0x0F
        let extFlag = (headerByte & 0x04) != 0
        let hasSize = (headerByte & 0x02) != 0
        guard let type = AV1OBUType(rawValue: typeRaw) else {
            throw BitstreamError.unsupportedValue(
                codec: "AV1", field: "obu_type", value: UInt64(typeRaw)
            )
        }
        var bytesConsumed = 1
        var ext: Header.Extension?
        if extFlag {
            let idx = offset + 1
            guard idx < data.count else {
                throw BitstreamError.truncated(codec: "AV1", field: "obu_extension_header")
            }
            let extByte = data[data.startIndex + idx]
            ext = Header.Extension(
                temporalID: (extByte >> 5) & 0x07,
                spatialID: (extByte >> 3) & 0x03
            )
            bytesConsumed += 1
        }
        var payloadSize: Int
        if hasSize {
            let (size, consumed) = try AV1LEB128.decode(
                from: data, at: offset + bytesConsumed
            )
            bytesConsumed += consumed
            payloadSize = Int(size)
        } else {
            payloadSize = data.count - offset - bytesConsumed
        }
        let payloadStart = data.startIndex + offset + bytesConsumed
        let payloadEnd = payloadStart + payloadSize
        guard payloadEnd <= data.endIndex else {
            throw BitstreamError.truncated(codec: "AV1", field: "obu_payload")
        }
        let payload = data.subdata(in: payloadStart..<payloadEnd)
        bytesConsumed += payloadSize
        let header = Header(obuType: type, hasSizeField: hasSize, extension: ext)
        return (AV1OBU(header: header, payload: payload), bytesConsumed)
    }

    public func encode() -> Data {
        var bytes = Data()
        var headerByte: UInt8 = 0
        headerByte |= (header.obuType.rawValue & 0x0F) << 3
        if header.`extension` != nil { headerByte |= 0x04 }
        if header.hasSizeField { headerByte |= 0x02 }
        bytes.append(headerByte)
        if let ext = header.`extension` {
            var extByte: UInt8 = 0
            extByte |= (ext.temporalID & 0x07) << 5
            extByte |= (ext.spatialID & 0x03) << 3
            bytes.append(extByte)
        }
        if header.hasSizeField {
            bytes.append(AV1LEB128.encode(UInt64(payload.count)))
        }
        bytes.append(payload)
        return bytes
    }
}
