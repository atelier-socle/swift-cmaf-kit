// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ClosedCaptionDecoder
//
// Reference: ATSC A/72 Part 3, SCTE-128 §8, CTA-608-E §F (cc_data
// SEI carriage), CTA-708-E §6.2 (DTVCC packet layout).
//
// Parses the ATSC A/72 `cea_708` payload carried inside a SEI
// `user_data_registered_itu_t_t35` message. Layout:
//
//   itu_t_t35_country_code = 0xB5         (USA)
//   itu_t_t35_provider_code = 0x00 0x31   (ATSC, big-endian UInt16)
//   user_identifier = "GA94"              (0x47 0x41 0x39 0x34)
//   user_data_type_code = 0x03            (cea_708 cc_data)
//   reserved + cc_count                   (1 byte: 1 + 1 + 6 bits = 0x80 | cc_count)
//   reserved                              (1 byte: 0xFF)
//   for i in 0..<cc_count:
//       marker_bits | cc_valid | cc_type  (1 byte)
//       cc_data_1                         (1 byte)
//       cc_data_2                         (1 byte)
//
// Where cc_type:
//   00 = NTSC field 1 byte pair (CEA-608 channel 1/2)
//   01 = NTSC field 2 byte pair (CEA-608 channel 3/4)
//   10 = DTVCC packet header
//   11 = DTVCC packet data

import Foundation

/// Parser for ATSC A/72 closed-caption SEI payloads.
public enum ClosedCaptionDecoder {

    /// Pattern signature bytes per ATSC A/72 / SCTE-128.
    internal static let countryCodeUSA: UInt8 = 0xB5
    internal static let providerCodeATSC: UInt16 = 0x0031
    internal static let userIdentifierGA94: UInt32 = 0x4741_3934
    internal static let userDataTypeCEA708: UInt8 = 0x03

    /// Decode the closed caption payload carried by the supplied
    /// SEI payload bytes. Returns nil when the payload does not
    /// match the recognised ATSC A/72 pattern.
    public static func decode(seiPayload payload: Data) -> ClosedCaptionData? {
        guard payload.count >= 7 else { return nil }
        let bytes = [UInt8](payload)
        let baseIndex = bytes.startIndex
        let country = bytes[baseIndex]
        guard country == countryCodeUSA else { return nil }
        let providerHi = UInt16(bytes[baseIndex + 1])
        let providerLo = UInt16(bytes[baseIndex + 2])
        let provider = (providerHi << 8) | providerLo
        guard provider == providerCodeATSC else { return nil }
        let userIdRaw =
            (UInt32(bytes[baseIndex + 3]) << 24)
            | (UInt32(bytes[baseIndex + 4]) << 16)
            | (UInt32(bytes[baseIndex + 5]) << 8)
            | UInt32(bytes[baseIndex + 6])
        guard userIdRaw == userIdentifierGA94 else { return nil }
        guard payload.count >= 10 else { return nil }
        let userDataType = bytes[baseIndex + 7]
        guard userDataType == userDataTypeCEA708 else { return nil }
        let ccCount = bytes[baseIndex + 8] & 0x1F
        // bytes[baseIndex + 9] is the reserved 0xFF byte.
        let triplesStart = baseIndex + 10
        let triplesEnd = triplesStart + Int(ccCount) * 3
        guard triplesEnd <= payload.count else { return nil }

        var cea608: [CEA608ByteData] = []
        var dtvccPacketBytes: [UInt8] = []
        for index in 0..<Int(ccCount) {
            let cursor = triplesStart + index * 3
            let header = bytes[cursor]
            let ccValid = (header & 0x04) != 0
            let ccType = header & 0x03
            let data1 = bytes[cursor + 1]
            let data2 = bytes[cursor + 2]
            switch ccType {
            case 0x00:
                cea608.append(
                    CEA608ByteData(
                        field: .field1,
                        byte1: data1,
                        byte2: data2,
                        validFlag: ccValid
                    ))
            case 0x01:
                cea608.append(
                    CEA608ByteData(
                        field: .field2,
                        byte1: data1,
                        byte2: data2,
                        validFlag: ccValid
                    ))
            case 0x02, 0x03:
                if ccValid {
                    dtvccPacketBytes.append(data1)
                    dtvccPacketBytes.append(data2)
                }
            default:
                continue
            }
        }
        // Prefer the DTVCC packet when present; else surface
        // CEA-608 byte pairs.
        if !dtvccPacketBytes.isEmpty,
            let packet = parseDTVCCPacket(Data(dtvccPacketBytes))
        {
            return .cea708(packet: packet)
        }
        if !cea608.isEmpty {
            return .cea608(bytes: cea608)
        }
        return nil
    }

    /// Parse a DTVCC caption channel packet per CTA-708-E §6.2.
    internal static func parseDTVCCPacket(_ data: Data) -> DTVCCPacket? {
        guard data.count >= 1 else { return nil }
        let bytes = [UInt8](data)
        let baseIndex = bytes.startIndex
        let header = bytes[baseIndex]
        let sequenceNumber = (header >> 6) & 0x03
        let packetSizeCode = header & 0x3F
        let packetSize: Int
        if packetSizeCode == 0 {
            packetSize = 128
        } else {
            packetSize = Int(packetSizeCode) * 2
        }
        guard bytes.count >= 1 + packetSize else {
            // Partial packet — emit the header but no services.
            return DTVCCPacket(
                sequenceNumber: sequenceNumber,
                packetSizeCode: packetSizeCode,
                services: []
            )
        }
        var services: [DTVCCServiceBlock] = []
        var cursor = baseIndex + 1
        let endCursor = baseIndex + 1 + packetSize
        while cursor < endCursor {
            guard cursor < bytes.endIndex else { break }
            let serviceHeader = bytes[cursor]
            cursor += 1
            var serviceNumberRaw = UInt8((serviceHeader >> 5) & 0x07)
            let blockSize = serviceHeader & 0x1F
            if blockSize == 0 {
                continue
            }
            // Extended service header: when service_number == 7 and
            // an extension byte follows.
            if serviceNumberRaw == 7, cursor < endCursor {
                let extByte = bytes[cursor]
                cursor += 1
                serviceNumberRaw = extByte & 0x3F
            }
            guard let service = CCService.cea708Service(forWireNumber: serviceNumberRaw)
            else { continue }
            let blockEnd = min(cursor + Int(blockSize), endCursor)
            let blockBytes = Array(bytes[cursor..<blockEnd])
            services.append(
                DTVCCServiceBlock(
                    serviceNumber: service,
                    blockSize: blockSize,
                    serviceData: Data(blockBytes)
                ))
            cursor = blockEnd
        }
        return DTVCCPacket(
            sequenceNumber: sequenceNumber,
            packetSizeCode: packetSizeCode,
            services: services
        )
    }
}

// MARK: - SEI extensions

extension AVCSEIMessage {
    /// Typed CEA-608/CEA-708 caption data carried by this SEI
    /// message, if any. Recognises the ATSC A/72 pattern
    /// (`payloadType == 4` and the GA94 user_identifier).
    public var closedCaptions: ClosedCaptionData? {
        guard payloadType == 4 else { return nil }
        return ClosedCaptionDecoder.decode(seiPayload: payload)
    }
}

extension HEVCSEIMessage {
    /// Typed CEA-608/CEA-708 caption data carried by this SEI
    /// message, if any.
    public var closedCaptions: ClosedCaptionData? {
        guard payloadType == 4 else { return nil }
        return ClosedCaptionDecoder.decode(seiPayload: payload)
    }
}
