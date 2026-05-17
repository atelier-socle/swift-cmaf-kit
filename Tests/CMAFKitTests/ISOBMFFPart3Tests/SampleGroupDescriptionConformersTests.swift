// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for the typed SampleGroupDescription conformers:
//   - RollSampleGroupDescription      (ISO/IEC 14496-12 §10.1)
//   - AudioPreRollSampleGroupDescription (ISO/IEC 23003-3)
//   - RandomAccessPointSampleGroupDescription (ISO/IEC 14496-12 §10.4)
//   - CENCSampleGroupDescription      (ISO/IEC 23001-7 §6)
//   - RawSampleGroupDescription       (permanent fallback)

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleGroupDescription conformers")
struct SampleGroupDescriptionConformersTests {

    // MARK: - Roll

    @Test
    func rollGroupingTypeIs_roll() {
        #expect(RollSampleGroupDescription.groupingType == "roll")
    }

    @Test
    func rollEncodesAsInt16() {
        let entry = RollSampleGroupDescription(rollDistance: -512)
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        #expect(writer.data == Data([0xFE, 0x00]))
    }

    @Test
    func rollNegativeAndPositiveRoundTrip() throws {
        for distance: Int16 in [-1024, -1, 0, 1, 32_767] {
            let entry = RollSampleGroupDescription(rollDistance: distance)
            var writer = BinaryWriter()
            entry.encode(to: &writer)
            var reader = BinaryReader(writer.data)
            let parsed = try RollSampleGroupDescription.parse(reader: &reader)
            #expect(parsed.rollDistance == distance)
        }
    }

    // MARK: - AudioPreRoll

    @Test
    func audioPreRollGroupingTypeIs_prol() {
        #expect(AudioPreRollSampleGroupDescription.groupingType == "prol")
    }

    @Test
    func audioPreRollHasSameLayoutAsRoll() throws {
        let prol = AudioPreRollSampleGroupDescription(rollDistance: -64)
        var writer = BinaryWriter()
        prol.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let parsed = try AudioPreRollSampleGroupDescription.parse(reader: &reader)
        #expect(parsed.rollDistance == -64)
        // Same wire bytes as RollSampleGroupDescription would produce.
        let roll = RollSampleGroupDescription(rollDistance: -64)
        var rollWriter = BinaryWriter()
        roll.encode(to: &rollWriter)
        #expect(writer.data == rollWriter.data)
    }

    // MARK: - RAP

    @Test
    func rapGroupingTypeIsRapSpace() {
        #expect(RandomAccessPointSampleGroupDescription.groupingType == "rap ")
    }

    @Test
    func rapByteEncoding() {
        let known = RandomAccessPointSampleGroupDescription(
            numLeadingSamplesKnown: true, numLeadingSamples: 5
        )
        var writer = BinaryWriter()
        known.encode(to: &writer)
        #expect(writer.data == Data([0x85]))

        let unknown = RandomAccessPointSampleGroupDescription(
            numLeadingSamplesKnown: false, numLeadingSamples: 0
        )
        var writer2 = BinaryWriter()
        unknown.encode(to: &writer2)
        #expect(writer2.data == Data([0x00]))
    }

    @Test
    func rapBitsParseCorrectly() throws {
        var reader = BinaryReader(Data([0x87]))
        let parsed = try RandomAccessPointSampleGroupDescription.parse(reader: &reader)
        #expect(parsed.numLeadingSamplesKnown == true)
        #expect(parsed.numLeadingSamples == 7)
    }

    // MARK: - CENC (seig)

    @Test
    func seigGroupingTypeIs_seig() {
        #expect(CENCSampleGroupDescription.groupingType == "seig")
    }

    @Test
    func seigPatternEncryptionBytesPacked() throws {
        // cbcs 1:9 video pattern: cryptByteBlock=1, skipByteBlock=9.
        let kid = try #require(UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF"))
        let entry = CENCSampleGroupDescription(
            cryptByteBlock: 1,
            skipByteBlock: 9,
            isProtected: 1,
            perSampleIVSize: 16,
            kid: kid,
            constantIV: Data()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        // Layout: reserved(1) | pattern(1) | isProtected(1) | ivSize(1) | KID(16).
        #expect(writer.data[0] == 0x00)  // reserved
        #expect(writer.data[1] == 0x19)  // (1 << 4) | 9
        #expect(writer.data[2] == 0x01)  // isProtected
        #expect(writer.data[3] == 0x10)  // perSampleIVSize = 16
        var reader = BinaryReader(writer.data)
        let parsed = try CENCSampleGroupDescription.parse(reader: &reader)
        #expect(parsed.cryptByteBlock == 1)
        #expect(parsed.skipByteBlock == 9)
        #expect(parsed.kid == kid)
    }

    @Test
    func seigConstantIVAppendedWhenIsProtectedAndIVSizeZero() throws {
        let kid = try #require(UUID(uuidString: "AABBCCDD-EEFF-1122-3344-556677889900"))
        let constantIV = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let entry = CENCSampleGroupDescription(
            cryptByteBlock: 0,
            skipByteBlock: 0,
            isProtected: 1,
            perSampleIVSize: 0,
            kid: kid,
            constantIV: constantIV
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let parsed = try CENCSampleGroupDescription.parse(reader: &reader)
        #expect(parsed.constantIV == constantIV)
    }

    // MARK: - Raw fallback

    @Test
    func rawSentinelGroupingTypeIsZero() {
        // The sentinel value is FourCC(0); the actual grouping type lives
        // on the containing sgpd box, not on the fallback conformer.
        #expect(RawSampleGroupDescription.groupingType == FourCC(0))
    }

    @Test
    func rawPayloadRoundTripsVerbatim() {
        let payload = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x12, 0x34])
        let entry = RawSampleGroupDescription(payload: payload)
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        #expect(writer.data == payload)
    }
}
