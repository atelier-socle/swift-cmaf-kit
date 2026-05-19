// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("TrackEncryptionBox (tenc)")
struct TrackEncryptionBoxTests {

    private static func makeKID() -> KeyIdentifier {
        KeyIdentifier(rawBytes: Data(repeating: 0x33, count: 16))
    }

    private func roundTrip(_ box: TrackEncryptionBox) async throws -> TrackEncryptionBox {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? TrackEncryptionBox)
    }

    // MARK: - Version 0 (no pattern, no constantIV combined)

    @Test
    func v0ProtectedRoundTrip() async throws {
        let box = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.version == 0)
        #expect(parsed.defaultIsProtected)
        #expect(parsed.defaultPerSampleIVSize == .eight)
    }

    @Test
    func v0UnprotectedRoundTrip() async throws {
        let box = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: false,
            defaultPerSampleIVSize: .zero,
            defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0x00, count: 16))
        )
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.defaultIsProtected == false)
    }

    @Test
    func v0SixteenByteIVRoundTrip() async throws {
        let box = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .sixteen,
            defaultKID: Self.makeKID()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.defaultPerSampleIVSize == .sixteen)
    }

    @Test
    func v0WithConstantIV() async throws {
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0xCC, count: 8))
        let box = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .zero,
            defaultKID: Self.makeKID(),
            defaultConstantIV: constantIV
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.defaultConstantIV == constantIV)
    }

    // MARK: - Version 1 (pattern + constantIV)

    @Test
    func v1PatternRoundTrip() async throws {
        let box = TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.version == 1)
        #expect(parsed.defaultCryptByteBlock == 1)
        #expect(parsed.defaultSkipByteBlock == 9)
    }

    @Test
    func v1CbcsConstantIVRoundTrip() async throws {
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0x42, count: 16))
        let box = TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .zero,
            defaultKID: Self.makeKID(),
            defaultConstantIV: constantIV
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.defaultConstantIV?.rawBytes.count == 16)
    }

    @Test
    func v1MaximumBlockValues() async throws {
        let box = TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: 0x0F,
            defaultSkipByteBlock: 0x0F,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.defaultCryptByteBlock == 0x0F)
        #expect(parsed.defaultSkipByteBlock == 0x0F)
    }

    @Test
    func v1ZeroBlockFields() async throws {
        let box = TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: 0,
            defaultSkipByteBlock: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.defaultCryptByteBlock == 0)
    }

    // MARK: - PerSampleIVSize enum

    @Test
    func perSampleIVSizeRawValues() {
        #expect(TrackEncryptionBox.PerSampleIVSize.zero.rawValue == 0)
        #expect(TrackEncryptionBox.PerSampleIVSize.eight.rawValue == 8)
        #expect(TrackEncryptionBox.PerSampleIVSize.sixteen.rawValue == 16)
    }

    @Test
    func perSampleIVSizeInitFromRawZeroEightSixteen() throws {
        #expect(try TrackEncryptionBox.PerSampleIVSize(rawValue: 0) == .zero)
        #expect(try TrackEncryptionBox.PerSampleIVSize(rawValue: 8) == .eight)
        #expect(try TrackEncryptionBox.PerSampleIVSize(rawValue: 16) == .sixteen)
    }

    @Test
    func perSampleIVSizeRejectsUnknownRaw() {
        #expect(throws: ISOBoxError.self) {
            _ = try TrackEncryptionBox.PerSampleIVSize(rawValue: 4)
        }
        #expect(throws: ISOBoxError.self) {
            _ = try TrackEncryptionBox.PerSampleIVSize(rawValue: 12)
        }
        #expect(throws: ISOBoxError.self) {
            _ = try TrackEncryptionBox.PerSampleIVSize(rawValue: 255)
        }
    }

    // MARK: - On-wire policing

    @Test
    func unknownVersionRejected() async {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "tenc", version: 2, flags: 0) { body in
            body.writeUInt8(0)
            body.writeUInt8(0)
            body.writeUInt8(1)
            body.writeUInt8(8)
            body.writeData(Data(repeating: 0xAA, count: 16))
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func v0NonZeroReservedSecondByteRejected() async {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "tenc", version: 0, flags: 0) { body in
            body.writeUInt8(0)
            body.writeUInt8(0xFF)  // must be zero on v0
            body.writeUInt8(1)
            body.writeUInt8(8)
            body.writeData(Data(repeating: 0xAA, count: 16))
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func nonZeroFirstReservedByteRejected() async {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "tenc", version: 1, flags: 0) { body in
            body.writeUInt8(1)  // must be zero
            body.writeUInt8(0)
            body.writeUInt8(1)
            body.writeUInt8(8)
            body.writeData(Data(repeating: 0xAA, count: 16))
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func unknownIVSizeRejected() async {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "tenc", version: 0, flags: 0) { body in
            body.writeUInt8(0)
            body.writeUInt8(0)
            body.writeUInt8(1)
            body.writeUInt8(7)  // not 0/8/16
            body.writeData(Data(repeating: 0xAA, count: 16))
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    // MARK: - Other invariants

    @Test
    func boxType() {
        #expect(TrackEncryptionBox.boxType == "tenc")
    }

    @Test
    func registryParserIsRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "tenc")
        #expect(parser != nil)
    }

    @Test
    func defaultKIDPreservedExactly() async throws {
        let bytes = Data((0..<16).map { UInt8($0) })
        let box = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: KeyIdentifier(rawBytes: bytes)
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.defaultKID.rawBytes == bytes)
    }

    @Test
    func patternFieldsPackedInNibbles() async throws {
        let box = TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: 0x0A,
            defaultSkipByteBlock: 0x05,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // Header(8) + version(1) + flags(3) + reserved(1) + nibblePack(1) = byte index 13.
        #expect(writer.data[13] == 0xA5)
    }

    @Test
    func zeroKIDAccepted() async throws {
        let box = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: false,
            defaultPerSampleIVSize: .zero,
            defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0, count: 16))
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.defaultKID.rawBytes == Data(repeating: 0, count: 16))
    }

    @Test
    func encodedV0Size() {
        let box = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // 8 hdr + 4 fullBox + 1 reserved + 1 reserved + 1 isProtected + 1 ivSize + 16 KID = 32
        #expect(writer.data.count == 32)
    }

    @Test
    func encodedV1WithConstantIV16Size() throws {
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0x42, count: 16))
        let box = TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .zero,
            defaultKID: Self.makeKID(),
            defaultConstantIV: constantIV
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // 32 v0-base + 1 length-byte + 16 IV = 49
        #expect(writer.data.count == 49)
    }

    @Test
    func roundTripV0WithoutConstantIV() async throws {
        let box = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.defaultConstantIV == nil)
    }

    @Test
    func encoderDecoderMatchOnPatternBoundaries() async throws {
        // crypt=15, skip=15 — max nibble values.
        let box = TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: 15,
            defaultSkipByteBlock: 15,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.defaultCryptByteBlock == 15)
        #expect(parsed.defaultSkipByteBlock == 15)
    }

    @Test
    func flagsArePreserved() async throws {
        let box = TrackEncryptionBox(
            version: 0,
            flags: 0x0000_FFFF,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.flags == 0x0000_FFFF)
    }

    @Test
    func equalityRequiresAllFieldsMatch() {
        let a = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        let b = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: Self.makeKID()
        )
        let c = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .sixteen,
            defaultKID: Self.makeKID()
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func v1WithoutPatternStillRoundTrips() async throws {
        let box = TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: 0,
            defaultSkipByteBlock: 0,
            defaultIsProtected: false,
            defaultPerSampleIVSize: .zero,
            defaultKID: Self.makeKID()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
    }
}
