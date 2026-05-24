// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// PCMConfigurationBox (pcmC) round-trip + validation per ISO/IEC
// 23003-5 §5.

import Foundation
import Testing

@testable import CMAFKit

@Suite("PCMConfigurationBox — round-trip")
struct PCMConfigurationBoxRoundTripTests {

    @Test func littleEndian16BitRoundTrips() async throws {
        try await assertRoundTrip(
            PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 16))
    }

    @Test func bigEndian24BitRoundTrips() async throws {
        try await assertRoundTrip(
            PCMConfigurationBox(endianness: .bigEndian, pcmSampleSize: 24))
    }

    @Test func littleEndian32BitFloatRoundTrips() async throws {
        try await assertRoundTrip(
            PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 32))
    }

    @Test func littleEndian64BitFloatRoundTrips() async throws {
        try await assertRoundTrip(
            PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 64))
    }

    private func assertRoundTrip(
        _ box: PCMConfigurationBox,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(
            boxes.first as? PCMConfigurationBox, sourceLocation: sourceLocation)
        #expect(parsed == box, sourceLocation: sourceLocation)
    }
}

@Suite("PCMConfigurationBox — validation")
struct PCMConfigurationBoxValidationTests {

    @Test func integerAccepts8_16_24_32() throws {
        for size: UInt8 in [8, 16, 24, 32] {
            try PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: size)
                .validate(codecKind: .integer)
        }
    }

    @Test func integerRejects64Bit() {
        let box = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 64)
        #expect(throws: PCMConfigurationBoxError.self) {
            try box.validate(codecKind: .integer)
        }
    }

    @Test func integerRejects16BitOddSize() {
        let box = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 12)
        #expect(throws: PCMConfigurationBoxError.self) {
            try box.validate(codecKind: .integer)
        }
    }

    @Test func floatAccepts32And64() throws {
        for size: UInt8 in [32, 64] {
            try PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: size)
                .validate(codecKind: .floatingPoint)
        }
    }

    @Test func floatRejects16Bit() {
        // IEEE 754 binary16 (half precision) is NOT a CMAF-standard
        // form per ISO/IEC 23003-5.
        let box = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 16)
        #expect(throws: PCMConfigurationBoxError.self) {
            try box.validate(codecKind: .floatingPoint)
        }
    }

    @Test func floatRejects24Bit() {
        let box = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 24)
        #expect(throws: PCMConfigurationBoxError.self) {
            try box.validate(codecKind: .floatingPoint)
        }
    }
}

@Suite("PCMConfigurationBox — endianness encoding")
struct PCMConfigurationBoxEndiannessTests {

    @Test func littleEndianSetsFormatFlagsBit0() async throws {
        let box = PCMConfigurationBox(endianness: .littleEndian, pcmSampleSize: 16)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // Body byte layout after the 8-byte box header + 4-byte FullBox
        // version/flags: format_flags (byte 12), pcmSampleSize (byte 13).
        #expect(writer.data[12] & 0x01 == 0x01)
        #expect(writer.data[13] == 16)
    }

    @Test func bigEndianClearsFormatFlagsBit0() async throws {
        let box = PCMConfigurationBox(endianness: .bigEndian, pcmSampleSize: 24)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(writer.data[12] & 0x01 == 0x00)
        #expect(writer.data[13] == 24)
    }
}

@Suite("PCMConfigurationBox — parse rejects non-zero version / flags")
struct PCMConfigurationBoxParseRejectsTests {

    @Test func parseRejectsNonZeroVersion() async throws {
        // Hand-craft a pcmC body with version=1 (must be 0 per
        // ISO/IEC 23003-5 §5).
        let box = PCMConfigurationBox(
            endianness: .littleEndian, pcmSampleSize: 16,
            version: 1, flags: 0)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test func parseRejectsNonZeroFlags() async throws {
        let box = PCMConfigurationBox(
            endianness: .littleEndian, pcmSampleSize: 16,
            version: 0, flags: 0x000001)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }
}
