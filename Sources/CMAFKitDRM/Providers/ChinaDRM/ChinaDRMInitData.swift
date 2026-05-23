// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ChinaDRMInitData
//
// Reference: GY/T 277 / GY/T 277.2 (China DRM national standard,
// published by the State Administration of Radio, Film and
// Television); DASH-IF reference documentation summary.
//
// The system identifier `3d5e6d35-9b9a-41e8-b843-dd3c6e72c42c`
// carries a leading 4-byte big-endian KID count followed by N
// 16-byte KIDs. Trailing bytes (operator-specific extensions)
// are preserved in ``innerPayload`` per GY/T 277.2's allowance
// for operator-profile extensions whose layout is implementation-
// dependent.

import Foundation

/// Typed China DRM init-data payload.
public struct ChinaDRMInitData: Sendable, Hashable, Equatable, Codable {

    /// Each KID is the raw 16-byte UUID per ISO/IEC 23001-7 §8.2.
    public let kids: [Data]
    /// Bytes after the KID array. Operator-profile dependent per
    /// GY/T 277.2; preserved verbatim for byte-perfect round-trip.
    public let innerPayload: Data

    public init(kids: [Data], innerPayload: Data = Data()) {
        for kid in kids {
            precondition(
                kid.count == 16,
                "China DRM kid must be 16 bytes per ISO/IEC 23001-7 \u{00A7}8.2"
            )
        }
        self.kids = kids
        self.innerPayload = innerPayload
    }

    public static func parse(_ data: Data) throws -> ChinaDRMInitData {
        guard data.count >= 4 else {
            throw DRMSystemError.malformedInitData(
                systemID: .chinaDRM,
                reason: "China DRM init data is shorter than the 4-byte KID count header"
            )
        }
        let bytes = [UInt8](data)
        let baseIndex = bytes.startIndex
        let count =
            (UInt32(bytes[baseIndex]) << 24)
            | (UInt32(bytes[baseIndex + 1]) << 16)
            | (UInt32(bytes[baseIndex + 2]) << 8)
            | UInt32(bytes[baseIndex + 3])
        let kidsStart = baseIndex + 4
        let kidsEnd = kidsStart + Int(count) * 16
        guard kidsEnd <= bytes.count else {
            throw DRMSystemError.malformedInitData(
                systemID: .chinaDRM,
                reason: "China DRM declares \(count) KIDs but buffer truncated"
            )
        }
        var kids: [Data] = []
        kids.reserveCapacity(Int(count))
        for index in 0..<Int(count) {
            let start = kidsStart + index * 16
            let end = start + 16
            kids.append(Data(bytes[start..<end]))
        }
        let inner = Data(bytes[kidsEnd..<bytes.count])
        return ChinaDRMInitData(kids: kids, innerPayload: inner)
    }

    public static func encode(_ value: ChinaDRMInitData) throws -> Data {
        guard value.kids.count <= Int(UInt32.max) else {
            throw DRMSystemError.malformedInitData(
                systemID: .chinaDRM,
                reason: "China DRM KID count exceeds UInt32.max on encode"
            )
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(4 + value.kids.count * 16 + value.innerPayload.count)
        let count = UInt32(value.kids.count)
        bytes.append(UInt8((count >> 24) & 0xFF))
        bytes.append(UInt8((count >> 16) & 0xFF))
        bytes.append(UInt8((count >> 8) & 0xFF))
        bytes.append(UInt8(count & 0xFF))
        for kid in value.kids {
            guard kid.count == 16 else {
                throw DRMSystemError.malformedInitData(
                    systemID: .chinaDRM,
                    reason: "China DRM kid must be 16 bytes on encode"
                )
            }
            bytes.append(contentsOf: kid)
        }
        bytes.append(contentsOf: value.innerPayload)
        return Data(bytes)
    }
}

extension ChinaDRMInitData: DRMInitDataParsing {
    public static var systemID: KnownDRMSystemID { .chinaDRM }
    public typealias TypedInitData = ChinaDRMInitData
}
