// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for the internal big-endian Data helpers used by every lazy table.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Data big-endian helpers")
struct LazyTableDataHelpersTests {

    @Test
    func readUInt8AtOffset() {
        let bytes = Data([0x12, 0x34, 0x56])
        #expect(bytes.readUInt8(at: 0) == 0x12)
        #expect(bytes.readUInt8(at: 2) == 0x56)
    }

    @Test
    func readUInt16BigEndian() {
        let bytes = Data([0x12, 0x34, 0x56, 0x78])
        #expect(bytes.readUInt16BigEndian(at: 0) == 0x1234)
        #expect(bytes.readUInt16BigEndian(at: 2) == 0x5678)
    }

    @Test
    func readUInt24BigEndian() {
        let bytes = Data([0x12, 0x34, 0x56, 0xAB, 0xCD, 0xEF])
        #expect(bytes.readUInt24BigEndian(at: 0) == 0x0012_3456)
        #expect(bytes.readUInt24BigEndian(at: 3) == 0x00AB_CDEF)
    }

    @Test
    func readUInt32BigEndian() {
        let bytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        #expect(bytes.readUInt32BigEndian(at: 0) == 0xDEAD_BEEF)
    }

    @Test
    func readInt32BigEndianSigned() {
        let bytes = Data([0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00, 0x00, 0x00])
        #expect(bytes.readInt32BigEndian(at: 0) == -1)
        #expect(bytes.readInt32BigEndian(at: 4) == Int32.min)
    }

    @Test
    func readUInt64BigEndian() {
        let bytes = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        #expect(bytes.readUInt64BigEndian(at: 0) == 0x0102_0304_0506_0708)
    }

    @Test
    func appendUInt32BigEndianRoundTrip() {
        var bytes = Data()
        bytes.appendUInt32BigEndian(0xDEAD_BEEF)
        #expect(bytes.readUInt32BigEndian(at: 0) == 0xDEAD_BEEF)
    }

    @Test
    func appendUInt64BigEndianRoundTrip() {
        var bytes = Data()
        bytes.appendUInt64BigEndian(0x0102_0304_0506_0708)
        #expect(bytes.readUInt64BigEndian(at: 0) == 0x0102_0304_0506_0708)
    }

    @Test
    func appendInt32BigEndianSigned() {
        var bytes = Data()
        bytes.appendInt32BigEndian(-1)
        bytes.appendInt32BigEndian(Int32.min)
        #expect(bytes.readInt32BigEndian(at: 0) == -1)
        #expect(bytes.readInt32BigEndian(at: 4) == Int32.min)
    }

    @Test
    func appendUInt16And24BigEndianRoundTrip() {
        var bytes = Data()
        bytes.appendUInt16BigEndian(0x1234)
        bytes.appendUInt24BigEndian(0x00AB_CDEF)
        #expect(bytes.readUInt16BigEndian(at: 0) == 0x1234)
        #expect(bytes.readUInt24BigEndian(at: 2) == 0x00AB_CDEF)
    }
}
