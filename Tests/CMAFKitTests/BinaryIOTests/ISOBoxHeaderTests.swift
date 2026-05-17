// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for ISOBoxHeader — ISO/IEC 14496-12 §4.2 box header surface.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ISOBoxHeader")
struct ISOBoxHeaderTests {

    @Test
    func memberwiseConstruction() {
        let header = ISOBoxHeader(type: "ftyp", size: 24, headerSize: 8)
        #expect(header.type == "ftyp")
        #expect(header.size == 24)
        #expect(header.headerSize == 8)
        #expect(header.userType == nil)
    }

    @Test
    func uuidHeaderCarriesExtendedType() throws {
        let extended = try #require(UUID(uuidString: "12345678-9ABC-DEF0-1234-56789ABCDEF0"))
        let header = ISOBoxHeader(type: "uuid", size: 40, headerSize: 24, userType: extended)
        #expect(header.type == "uuid")
        #expect(header.headerSize == 24)
        #expect(header.userType == extended)
    }

    @Test
    func nonUuidHasNilUserType() {
        let header = ISOBoxHeader(type: "moov", size: 100, headerSize: 8)
        #expect(header.userType == nil)
    }

    @Test
    func headerSizeCases() {
        let standard = ISOBoxHeader(type: "ftyp", size: 24, headerSize: 8)
        let largesize = ISOBoxHeader(type: "mdat", size: 10_000_000_000, headerSize: 16)
        let uuidBox = ISOBoxHeader(
            type: "uuid",
            size: 40,
            headerSize: 24,
            userType: UUID()
        )
        #expect(standard.headerSize == 8)
        #expect(largesize.headerSize == 16)
        #expect(uuidBox.headerSize == 24)
    }

    @Test
    func largesizeBoundary() {
        // Size that requires 64-bit largesize encoding (> UInt32.max).
        let huge: UInt64 = UInt64(UInt32.max) + 1024
        let header = ISOBoxHeader(type: "mdat", size: huge, headerSize: 16)
        #expect(header.size == huge)
        #expect(header.headerSize == 16)
    }

    @Test
    func equatable() {
        let a = ISOBoxHeader(type: "ftyp", size: 24, headerSize: 8)
        let b = ISOBoxHeader(type: "ftyp", size: 24, headerSize: 8)
        let c = ISOBoxHeader(type: "moov", size: 24, headerSize: 8)
        let d = ISOBoxHeader(type: "ftyp", size: 32, headerSize: 8)
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }
}
