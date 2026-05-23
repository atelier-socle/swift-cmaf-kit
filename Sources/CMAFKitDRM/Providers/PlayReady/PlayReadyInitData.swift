// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - PlayReadyInitData
//
// Reference: Microsoft "PlayReady Header Object" public
// specification + "PlayReady Header XML" public specification.
//
// PlayReady Object (PRO) outer wire format:
//
//   length        UInt32 LE   total PRO size including this field
//   recordCount   UInt16 LE
//   For each record:
//     recordType   UInt16 LE  0x0001 = PlayReady Header XML
//                              0x0002 = Reserved
//                              0x0003 = Embedded License Store
//     recordLength UInt16 LE
//     recordValue  variable
//
// For record type 0x0001 the value is a UTF-16 LE XML document
// with a leading UTF-16 LE BOM (0xFF 0xFE). The root element is
// WRMHEADER with `xmlns` and `version` attributes; the version
// attribute selects between v4.0 / v4.1 / v4.2 / v4.3 schemas.

import Foundation

/// Typed Microsoft PlayReady init-data payload (PRO + WRMHEADER).
public struct PlayReadyInitData: Sendable, Hashable, Equatable, Codable {

    /// One record inside the PlayReady Object (PRO) envelope.
    public enum Record: Sendable, Hashable, Equatable, Codable {
        /// PlayReady Header XML record (type 0x0001).
        case wrmHeader(WRMHeader)
        /// Embedded License Store record (type 0x0003). Preserved
        /// verbatim — the wire format is operator-specific.
        case embeddedLicenseStore(Data)
        /// Reserved or unknown record type. Preserved verbatim so
        /// round-trip is byte-perfect.
        case other(recordType: UInt16, value: Data)
    }

    /// Typed WRMHEADER XML body per Microsoft "PlayReady Header XML".
    public struct WRMHeader: Sendable, Hashable, Equatable, Codable {

        /// Supported WRMHEADER versions per Microsoft's public spec.
        public enum Version: String, Sendable, Hashable, CaseIterable, Codable {
            case v4_0 = "4.0.0.0"
            case v4_1 = "4.1.0.0"
            case v4_2 = "4.2.0.0"
            case v4_3 = "4.3.0.0"
        }

        /// One KID entry per WRMHEADER schema.
        public struct KID: Sendable, Hashable, Equatable, Codable {
            /// Decoded 16-byte KID per ISO/IEC 23001-7 §8.2.
            public let value: Data
            /// Optional `ALGID` attribute (e.g., "AESCTR", "COCKTAIL").
            public let algorithmID: String?
            /// Optional `CHECKSUM` attribute (base64-encoded).
            public let checksum: Data?
            /// Optional `VALUE` type attribute (e.g., "system").
            public let valueType: String?

            public init(
                value: Data,
                algorithmID: String? = nil,
                checksum: Data? = nil,
                valueType: String? = nil
            ) {
                precondition(
                    value.count == 16,
                    "PlayReady KID must be 16 bytes per ISO/IEC 23001-7 \u{00A7}8.2"
                )
                self.value = value
                self.algorithmID = algorithmID
                self.checksum = checksum
                self.valueType = valueType
            }
        }

        public let version: Version
        /// Single KID in v4.0, multiple KIDs in v4.1+.
        public let kids: [KID]
        /// Document-level CHECKSUM child (base64-encoded).
        public let checksum: Data?
        /// `LA_URL` (License Acquisition URL) child.
        public let licenseAcquisitionURL: URL?
        /// `LUI_URL` (License UI URL) child.
        public let licenseUIURL: URL?
        /// `DS_ID` (Domain Service ID) child.
        public let domainServiceID: String?
        /// Verbatim `CUSTOMATTRIBUTES` child contents (round-tripped
        /// as a string; the spec permits arbitrary XML).
        public let customAttributesXML: String?
        /// `DECRYPTORSETUP` child contents (v4.2+).
        public let decryptorSetup: String?

        public init(
            version: Version,
            kids: [KID],
            checksum: Data? = nil,
            licenseAcquisitionURL: URL? = nil,
            licenseUIURL: URL? = nil,
            domainServiceID: String? = nil,
            customAttributesXML: String? = nil,
            decryptorSetup: String? = nil
        ) {
            self.version = version
            self.kids = kids
            self.checksum = checksum
            self.licenseAcquisitionURL = licenseAcquisitionURL
            self.licenseUIURL = licenseUIURL
            self.domainServiceID = domainServiceID
            self.customAttributesXML = customAttributesXML
            self.decryptorSetup = decryptorSetup
        }
    }

    public let records: [Record]

    public init(records: [Record]) {
        self.records = records
    }

    // MARK: - Parsing

    public static func parse(_ data: Data) throws -> PlayReadyInitData {
        guard data.count >= 6 else {
            throw DRMSystemError.malformedInitData(
                systemID: .playReady,
                reason: "PlayReady Object header is shorter than 6 bytes"
            )
        }
        let bytes = [UInt8](data)
        let baseIndex = bytes.startIndex
        let length =
            UInt32(bytes[baseIndex])
            | (UInt32(bytes[baseIndex + 1]) << 8)
            | (UInt32(bytes[baseIndex + 2]) << 16)
            | (UInt32(bytes[baseIndex + 3]) << 24)
        guard Int(length) == data.count else {
            throw DRMSystemError.malformedInitData(
                systemID: .playReady,
                reason:
                    "PlayReady Object length \(length) does not match buffer "
                    + "size \(data.count)"
            )
        }
        let recordCount =
            UInt16(bytes[baseIndex + 4])
            | (UInt16(bytes[baseIndex + 5]) << 8)
        var cursor = baseIndex + 6
        var records: [Record] = []
        records.reserveCapacity(Int(recordCount))
        for _ in 0..<recordCount {
            guard cursor + 4 <= bytes.count else {
                throw DRMSystemError.malformedInitData(
                    systemID: .playReady,
                    reason: "PlayReady record header truncated"
                )
            }
            let recordType =
                UInt16(bytes[cursor])
                | (UInt16(bytes[cursor + 1]) << 8)
            let recordLength =
                UInt16(bytes[cursor + 2])
                | (UInt16(bytes[cursor + 3]) << 8)
            cursor += 4
            guard cursor + Int(recordLength) <= bytes.count else {
                throw DRMSystemError.malformedInitData(
                    systemID: .playReady,
                    reason: "PlayReady record value truncated"
                )
            }
            let value = Data(bytes[cursor..<cursor + Int(recordLength)])
            cursor += Int(recordLength)
            switch recordType {
            case 0x0001:
                let header = try parseWRMHeader(value)
                records.append(.wrmHeader(header))
            case 0x0003:
                records.append(.embeddedLicenseStore(value))
            default:
                records.append(.other(recordType: recordType, value: value))
            }
        }
        return PlayReadyInitData(records: records)
    }

    private static func parseWRMHeader(_ recordValue: Data) throws -> WRMHeader {
        guard recordValue.count >= 2 else {
            throw DRMSystemError.malformedInitData(
                systemID: .playReady,
                reason: "WRMHEADER record is shorter than the UTF-16 LE BOM"
            )
        }
        let firstByte = recordValue[recordValue.startIndex]
        let secondByte = recordValue[recordValue.startIndex + 1]
        guard firstByte == 0xFF && secondByte == 0xFE else {
            throw DRMSystemError.malformedInitData(
                systemID: .playReady,
                reason: "Missing UTF-16 LE BOM in WRMHEADER record"
            )
        }
        let xmlBody = recordValue.suffix(from: recordValue.startIndex + 2)
        guard let xmlString = String(data: xmlBody, encoding: .utf16LittleEndian) else {
            throw DRMSystemError.malformedInitData(
                systemID: .playReady,
                reason: "WRMHEADER record is not valid UTF-16 LE"
            )
        }
        guard let utf8Data = xmlString.data(using: .utf8) else {
            throw DRMSystemError.malformedInitData(
                systemID: .playReady,
                reason: "WRMHEADER round-trip to UTF-8 failed"
            )
        }
        return try WRMHeaderXMLParser.parse(utf8Data, originalUTF16String: xmlString)
    }

    // MARK: - Encoding

    public static func encode(_ value: PlayReadyInitData) throws -> Data {
        var recordPayloads: [(type: UInt16, value: Data)] = []
        for record in value.records {
            switch record {
            case .wrmHeader(let header):
                recordPayloads.append((0x0001, try encodeWRMHeader(header)))
            case .embeddedLicenseStore(let bytes):
                recordPayloads.append((0x0003, bytes))
            case .other(let type, let bytes):
                recordPayloads.append((type, bytes))
            }
        }
        let totalLength = 6 + recordPayloads.reduce(0) { $0 + 4 + $1.value.count }
        guard totalLength <= Int(UInt32.max) else {
            throw DRMSystemError.malformedInitData(
                systemID: .playReady,
                reason: "PlayReady Object exceeds UInt32.max on encode"
            )
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(totalLength)
        let length = UInt32(totalLength)
        bytes.append(UInt8(length & 0xFF))
        bytes.append(UInt8((length >> 8) & 0xFF))
        bytes.append(UInt8((length >> 16) & 0xFF))
        bytes.append(UInt8((length >> 24) & 0xFF))
        let count = UInt16(recordPayloads.count)
        bytes.append(UInt8(count & 0xFF))
        bytes.append(UInt8((count >> 8) & 0xFF))
        for record in recordPayloads {
            guard record.value.count <= Int(UInt16.max) else {
                throw DRMSystemError.malformedInitData(
                    systemID: .playReady,
                    reason: "PlayReady record value exceeds UInt16.max on encode"
                )
            }
            bytes.append(UInt8(record.type & 0xFF))
            bytes.append(UInt8((record.type >> 8) & 0xFF))
            let valueLength = UInt16(record.value.count)
            bytes.append(UInt8(valueLength & 0xFF))
            bytes.append(UInt8((valueLength >> 8) & 0xFF))
            bytes.append(contentsOf: record.value)
        }
        return Data(bytes)
    }

    private static func encodeWRMHeader(_ header: WRMHeader) throws -> Data {
        let xmlString = WRMHeaderXMLSerializer.serialize(header)
        guard let utf16 = xmlString.data(using: .utf16LittleEndian) else {
            throw DRMSystemError.roundTripFailure(
                systemID: .playReady,
                reason: "WRMHEADER XML failed to encode as UTF-16 LE"
            )
        }
        var bytes: [UInt8] = [0xFF, 0xFE]
        bytes.append(contentsOf: utf16)
        return Data(bytes)
    }
}

extension PlayReadyInitData: DRMInitDataParsing {
    public static var systemID: KnownDRMSystemID { .playReady }
    public typealias TypedInitData = PlayReadyInitData
}
