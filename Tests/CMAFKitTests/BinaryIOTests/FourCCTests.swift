// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for FourCC — ISO/IEC 14496-12 §4.2 box type encoding.

import Foundation
import Testing

@testable import CMAFKit

@Suite("FourCC")
struct FourCCTests {

    @Test
    func literalConstruction() {
        let ftyp: FourCC = "ftyp"
        #expect(ftyp.stringValue == "ftyp")
        #expect(ftyp.rawValue == 0x6674_7970)  // 'f' 't' 'y' 'p'
    }

    @Test
    func rawValueRoundTrip() {
        let raw: UInt32 = 0x6D6F_6F76  // 'moov'
        let code = FourCC(raw)
        #expect(code.stringValue == "moov")
        #expect(code.rawValue == raw)
    }

    @Test
    func failableInitRejectsTooShort() {
        // Force the failable `init?(_:)` path by passing a String variable
        // (a bare literal `FourCC("ftp")` is ambiguous with `init(stringLiteral:)`).
        let short = "ftp"
        let empty = ""
        #expect(FourCC(short) == nil)
        #expect(FourCC(empty) == nil)
    }

    @Test
    func failableInitRejectsTooLong() {
        let tooLong = "ftyp1"
        let longer = "longer string"
        #expect(FourCC(tooLong) == nil)
        #expect(FourCC(longer) == nil)
    }

    @Test
    func failableInitRejectsNonASCII() {
        let psi = "ftψp"
        let accented = "éèçà"
        #expect(FourCC(psi) == nil)
        #expect(FourCC(accented) == nil)
    }

    @Test
    func failableInitAcceptsFourSpaces() {
        let input = "    "
        let spaces = FourCC(input)
        #expect(spaces != nil)
        #expect(spaces?.stringValue == "    ")
        #expect(spaces?.rawValue == 0x2020_2020)
    }

    @Test
    func descriptionMatchesStringValue() {
        let code: FourCC = "free"
        #expect(code.description == "free")
        #expect(code.description == code.stringValue)
    }

    @Test
    func equatableAndHashable() {
        let a: FourCC = "moov"
        let b: FourCC = "moov"
        let c: FourCC = "mdat"
        #expect(a == b)
        #expect(a != c)
        let set: Set<FourCC> = [a, b, c]
        #expect(set.count == 2)  // a == b
    }

    @Test
    func dictionaryKey() {
        let dict: [FourCC: String] = [
            "ftyp": "FileType",
            "moov": "Movie",
            "mdat": "MediaData"
        ]
        #expect(dict["ftyp" as FourCC] == "FileType")
        #expect(dict["moov" as FourCC] == "Movie")
        #expect(dict["xxxx" as FourCC] == nil)
    }

    // Trapping `init(trapping:)`: invariant fence for compile-time literals.
    // The trap (preconditionFailure) is not directly tested here — see the
    // failable `init?(_:)` tests above, which exercise the same validation
    // logic via the non-trapping path.
}
