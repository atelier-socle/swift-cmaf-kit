// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AV1LEB128")
struct AV1LEB128Tests {

    @Test
    func encodeSmallValue() {
        #expect(AV1LEB128.encode(0) == Data([0x00]))
        #expect(AV1LEB128.encode(127) == Data([0x7F]))
    }

    @Test
    func encodeTwoByteValue() {
        // 128 = 0b1000_0000_0000_0001 (lo 7 + cont, then 1)
        #expect(AV1LEB128.encode(128) == Data([0x80, 0x01]))
    }

    @Test
    func encodeLargeValue() throws {
        let encoded = AV1LEB128.encode(0x0FFF_FFFF)
        let (value, count) = try AV1LEB128.decode(from: encoded, at: 0)
        #expect(value == 0x0FFF_FFFF)
        #expect(count == encoded.count)
    }

    @Test
    func decodeRoundTrip() throws {
        for value: UInt64 in [0, 1, 127, 128, 1024, 0xFFFF, 0xDEAD_BEEF, 0x0FFF_FFFF_FFFF] {
            let encoded = AV1LEB128.encode(value)
            let (decoded, consumed) = try AV1LEB128.decode(from: encoded, at: 0)
            #expect(decoded == value)
            #expect(consumed == encoded.count)
        }
    }

    @Test
    func decodeOverflowThrows() {
        // 9 bytes of 0xFF would imply a 9-byte LEB128, which exceeds the AV1 limit.
        let bytes = Data(repeating: 0xFF, count: 9)
        #expect(throws: BitstreamError.self) {
            _ = try AV1LEB128.decode(from: bytes, at: 0)
        }
    }

    @Test
    func decodeTruncatedThrows() {
        // Continuation bit set but no following byte.
        let bytes = Data([0x80])
        #expect(throws: BitstreamError.self) {
            _ = try AV1LEB128.decode(from: bytes, at: 0)
        }
    }

    @Test
    func byteCountMatchesEncoding() {
        for value: UInt64 in [0, 1, 127, 128, 16384, 0xFFFF, 0xFFFF_FFFF] {
            let encoded = AV1LEB128.encode(value)
            #expect(AV1LEB128.byteCount(for: value) == encoded.count)
        }
    }
}

@Suite("AV1OBU")
struct AV1OBUTests {

    @Test
    func sequenceHeaderOBURoundTripWithSize() throws {
        let obu = AV1OBU(
            header: AV1OBU.Header(obuType: .sequenceHeader, hasSizeField: true),
            payload: Data([0x01, 0x02, 0x03])
        )
        let encoded = obu.encode()
        let (parsed, consumed) = try AV1OBU.parse(data: encoded)
        #expect(parsed == obu)
        #expect(consumed == encoded.count)
    }

    @Test
    func temporalDelimiterRoundTrip() throws {
        let obu = AV1OBU(
            header: AV1OBU.Header(obuType: .temporalDelimiter, hasSizeField: true),
            payload: Data()
        )
        let encoded = obu.encode()
        let (parsed, _) = try AV1OBU.parse(data: encoded)
        #expect(parsed == obu)
    }

    @Test
    func withExtensionHeader() throws {
        let obu = AV1OBU(
            header: AV1OBU.Header(
                obuType: .frame,
                hasSizeField: true,
                extension: AV1OBU.Header.Extension(temporalID: 1, spatialID: 2)
            ),
            payload: Data([0xAA, 0xBB])
        )
        let encoded = obu.encode()
        let (parsed, _) = try AV1OBU.parse(data: encoded)
        #expect(parsed == obu)
        #expect(parsed.header.extension?.temporalID == 1)
        #expect(parsed.header.extension?.spatialID == 2)
    }

    @Test
    func withoutSizeFieldImpliesPayloadToEnd() throws {
        let payload = Data([0x10, 0x20, 0x30, 0x40])
        let obu = AV1OBU(
            header: AV1OBU.Header(obuType: .frame, hasSizeField: false),
            payload: payload
        )
        let encoded = obu.encode()
        let (parsed, _) = try AV1OBU.parse(data: encoded)
        #expect(parsed.payload == payload)
    }

    @Test
    func unknownOBUTypeThrows() {
        // Bits 6..3 set to 9 (not in our enum: 0,1,2,3,4,5,6,7,8,15 are used).
        // 9 → header byte: 0_1001_0_1_0 = 0x4A. Actually obu_type is at bits 6..3.
        // obu_type 9 → bits 6..3 = 1001. Header byte: 0|1001|0|0|0 = 0b0100_1000 = 0x48
        let bytes = Data([0x48, 0x00])
        #expect(throws: BitstreamError.self) {
            _ = try AV1OBU.parse(data: bytes)
        }
    }

    @Test
    func forbiddenBitSetThrows() {
        // obu_forbidden_bit must be 0; setting MSB triggers reservedBitsNonZero.
        let bytes = Data([0x80, 0x00])
        #expect(throws: BitstreamError.self) {
            _ = try AV1OBU.parse(data: bytes)
        }
    }
}
