// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ExpGolomb")
struct ExpGolombTests {

    @Test
    func bitCountForZeroIsOne() {
        #expect(ExpGolomb.bitCount(unsigned: 0) == 1)
    }

    @Test
    func bitCountForOneIsThree() {
        #expect(ExpGolomb.bitCount(unsigned: 1) == 3)
    }

    @Test
    func bitCountForTwoIsThree() {
        #expect(ExpGolomb.bitCount(unsigned: 2) == 3)
    }

    @Test
    func bitCountForThreeIsFive() {
        #expect(ExpGolomb.bitCount(unsigned: 3) == 5)
    }

    @Test
    func bitCountForFifteenIsSeven() {
        // 15 → codeNum 16 → bitWidth 5 → 4 zeros + 5 bits = 9 bits
        // Wait, 15 codeNum=16, bitWidth = 5 (binary 10000 = 5 bits),
        // so total = 2*5 - 1 = 9 bits.
        #expect(ExpGolomb.bitCount(unsigned: 15) == 9)
    }

    @Test
    func mapSignedToUnsignedTable() {
        #expect(ExpGolomb.mapSignedToUnsigned(0) == 0)
        #expect(ExpGolomb.mapSignedToUnsigned(1) == 1)
        #expect(ExpGolomb.mapSignedToUnsigned(-1) == 2)
        #expect(ExpGolomb.mapSignedToUnsigned(2) == 3)
        #expect(ExpGolomb.mapSignedToUnsigned(-2) == 4)
        #expect(ExpGolomb.mapSignedToUnsigned(3) == 5)
        #expect(ExpGolomb.mapSignedToUnsigned(-3) == 6)
    }

    @Test
    func mapUnsignedToSignedTable() {
        #expect(ExpGolomb.mapUnsignedToSigned(0) == 0)
        #expect(ExpGolomb.mapUnsignedToSigned(1) == 1)
        #expect(ExpGolomb.mapUnsignedToSigned(2) == -1)
        #expect(ExpGolomb.mapUnsignedToSigned(3) == 2)
        #expect(ExpGolomb.mapUnsignedToSigned(4) == -2)
        #expect(ExpGolomb.mapUnsignedToSigned(5) == 3)
        #expect(ExpGolomb.mapUnsignedToSigned(6) == -3)
    }

    @Test
    func signedMappingIsInvolutive() {
        for v: Int32 in [0, 1, -1, 2, -2, 100, -100, 1_000_000, -1_000_000] {
            #expect(ExpGolomb.mapUnsignedToSigned(ExpGolomb.mapSignedToUnsigned(v)) == v)
        }
    }

    @Test
    func bitCountMatchesWriter() {
        var writer = BitWriter()
        writer.writeUnsignedExpGolomb(123)
        let expected = ExpGolomb.bitCount(unsigned: 123)
        #expect(writer.bitCount == expected)
    }

    @Test
    func bitCountForUInt32MaxClampsSafely() {
        // codeNum = UInt32.max + 1 = 0x1_0000_0000 (fits UInt64).
        // bitWidth = 33; total = 65 bits.
        #expect(ExpGolomb.bitCount(unsigned: UInt32.max) == 65)
    }

    @Test
    func mapSignedExtremeValueDoesNotTrap() {
        // Int32.min round-trips through Int64 internally; the resulting
        // UInt32 saturates rather than trapping.
        let mapped = ExpGolomb.mapSignedToUnsigned(Int32.min)
        #expect(mapped == UInt32.max)
    }
}
