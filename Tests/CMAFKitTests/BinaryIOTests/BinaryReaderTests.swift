// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for BinaryReader — big-endian primitives, fixed-point, matrix,
// language code per ISO/IEC 14496-12 §4.2, §8.3, §8.4.2.3.

import Foundation
import Testing

@testable import CMAFKit

@Suite("BinaryReader")
struct BinaryReaderTests {

    // MARK: Unsigned integers

    @Test
    func readUInt8() throws {
        var reader = BinaryReader(Data([0x01, 0x7F, 0xFF, 0x00]))
        #expect(try reader.readUInt8() == 0x01)
        #expect(try reader.readUInt8() == 0x7F)
        #expect(try reader.readUInt8() == 0xFF)
        #expect(try reader.readUInt8() == 0x00)
        #expect(reader.offset == 4)
    }

    @Test
    func readUInt16BigEndian() throws {
        var reader = BinaryReader(Data([0x12, 0x34, 0xFF, 0xFE]))
        #expect(try reader.readUInt16() == 0x1234)
        #expect(try reader.readUInt16() == 0xFFFE)
    }

    @Test
    func readUInt24BigEndian() throws {
        var reader = BinaryReader(Data([0x12, 0x34, 0x56]))
        #expect(try reader.readUInt24() == 0x0012_3456)
    }

    @Test
    func readUInt32BigEndian() throws {
        var reader = BinaryReader(Data([0xDE, 0xAD, 0xBE, 0xEF]))
        #expect(try reader.readUInt32() == 0xDEAD_BEEF)
    }

    @Test
    func readUInt64BigEndian() throws {
        var reader = BinaryReader(Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]))
        #expect(try reader.readUInt64() == 0x0102_0304_0506_0708)
    }

    // MARK: Signed integers

    @Test
    func readInt16SignExtension() throws {
        var reader = BinaryReader(Data([0xFF, 0xFE, 0x00, 0x01]))
        #expect(try reader.readInt16() == -2)
        #expect(try reader.readInt16() == 1)
    }

    @Test
    func readInt32SignExtension() throws {
        // 0xFFFFFFFF = -1, 0x80000000 = Int32.min
        var reader = BinaryReader(Data([0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00, 0x00, 0x00]))
        #expect(try reader.readInt32() == -1)
        #expect(try reader.readInt32() == Int32.min)
    }

    // MARK: Fixed-point

    @Test
    func readFixed8_8() throws {
        // 0x0100 = 1.0 in 8.8 fixed point
        var reader = BinaryReader(Data([0x01, 0x00, 0xFF, 0x00, 0x00, 0x80]))
        #expect(try reader.readFixed8_8() == 1.0)
        #expect(try reader.readFixed8_8() == -1.0)
        #expect(try reader.readFixed8_8() == 0.5)
    }

    @Test
    func readFixed16_16Identity() throws {
        // 0x00010000 = 1.0 in 16.16 fixed point
        var reader = BinaryReader(Data([0x00, 0x01, 0x00, 0x00]))
        #expect(try reader.readFixed16_16() == 1.0)
    }

    @Test
    func readFixed2_30Identity() throws {
        // 0x40000000 = 1.0 in 2.30 fixed point
        var reader = BinaryReader(Data([0x40, 0x00, 0x00, 0x00]))
        #expect(try reader.readFixed2_30() == 1.0)
    }

    @Test
    func readFixed2_30Zero() throws {
        var reader = BinaryReader(Data([0x00, 0x00, 0x00, 0x00]))
        #expect(try reader.readFixed2_30() == 0.0)
    }

    @Test
    func readFixed2_30NegativeOne() throws {
        // 0xC0000000 = -1.0 in 2.30 fixed point (two's complement Int32 = -0x40000000)
        var reader = BinaryReader(Data([0xC0, 0x00, 0x00, 0x00]))
        #expect(try reader.readFixed2_30() == -1.0)
    }

    // MARK: Matrix

    @Test
    func readMatrix3x3IdentityISO() throws {
        // Standard ISO/IEC 14496-12 §8.3 identity matrix:
        // 6 elements 16.16 fixed, last 3 elements 2.30 fixed.
        // [1.0, 0, 0, 0, 1.0, 0, 0, 0, 1.0]
        let bytes: [UInt8] = [
            0x00, 0x01, 0x00, 0x00,  // 1.0 (16.16)
            0x00, 0x00, 0x00, 0x00,  // 0.0
            0x00, 0x00, 0x00, 0x00,  // 0.0
            0x00, 0x00, 0x00, 0x00,  // 0.0
            0x00, 0x01, 0x00, 0x00,  // 1.0 (16.16)
            0x00, 0x00, 0x00, 0x00,  // 0.0
            0x00, 0x00, 0x00, 0x00,  // 0.0 (2.30)
            0x00, 0x00, 0x00, 0x00,  // 0.0
            0x40, 0x00, 0x00, 0x00  // 1.0 (2.30)
        ]
        var reader = BinaryReader(Data(bytes))
        let matrix = try reader.readMatrix3x3()
        #expect(matrix == [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])
    }

    @Test
    func readMatrix3x3Rotation90() throws {
        // 90° rotation: [0, 1, 0, -1, 0, 0, 0, 0, 1]
        let bytes: [UInt8] = [
            0x00, 0x00, 0x00, 0x00,  // 0
            0x00, 0x01, 0x00, 0x00,  // 1
            0x00, 0x00, 0x00, 0x00,  // 0
            0xFF, 0xFF, 0x00, 0x00,  // -1
            0x00, 0x00, 0x00, 0x00,  // 0
            0x00, 0x00, 0x00, 0x00,  // 0
            0x00, 0x00, 0x00, 0x00,  // 0 (2.30)
            0x00, 0x00, 0x00, 0x00,  // 0
            0x40, 0x00, 0x00, 0x00  // 1.0
        ]
        var reader = BinaryReader(Data(bytes))
        let matrix = try reader.readMatrix3x3()
        #expect(matrix == [0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0])
    }

    // MARK: FourCC

    @Test
    func readFourCC() throws {
        var reader = BinaryReader(Data([0x66, 0x74, 0x79, 0x70, 0x6D, 0x6F, 0x6F, 0x76]))
        #expect(try reader.readFourCC() == "ftyp")
        #expect(try reader.readFourCC() == "moov")
    }

    @Test
    func readFourCCRejectsNonASCII() {
        var reader = BinaryReader(Data([0xFE, 0x74, 0x79, 0x70]))
        do {
            _ = try reader.readFourCC()
            Issue.record("expected invalidFourCC throw")
        } catch let err as BinaryIOError {
            if case let .invalidFourCC(bytes) = err {
                #expect(bytes == [0xFE, 0x74, 0x79, 0x70])
            } else {
                Issue.record("wrong case: \(err)")
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    // MARK: Strings

    @Test
    func readStringUTF8() throws {
        let bytes = Array("hello".utf8)
        var reader = BinaryReader(Data(bytes))
        #expect(try reader.readString(length: bytes.count) == "hello")
    }

    @Test
    func readStringASCII() throws {
        var reader = BinaryReader(Data([0x41, 0x42, 0x43]))
        #expect(try reader.readString(length: 3, encoding: .ascii) == "ABC")
    }

    @Test
    func readNullTerminatedString() throws {
        var reader = BinaryReader(Data([0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0xAA]))
        #expect(try reader.readNullTerminatedString() == "hello")
        // Terminator was consumed; one byte remains.
        #expect(reader.remaining == 1)
    }

    // MARK: UUID

    @Test
    func readUUIDRoundTrip() throws {
        let knownUUID = try #require(UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF"))
        let bytes = withUnsafeBytes(of: knownUUID.uuid) { Array($0) }
        var reader = BinaryReader(Data(bytes))
        let decoded = try reader.readUUID()
        #expect(decoded == knownUUID)
    }

    // MARK: Language code

    @Test
    func readLanguageCodeEng() throws {
        // 'e'=5, 'n'=14, 'g'=7 → packed (5<<10) | (14<<5) | 7 = 0x15C7
        var reader = BinaryReader(Data([0x15, 0xC7]))
        #expect(try reader.readLanguageCode() == "eng")
    }

    @Test
    func readLanguageCodeFra() throws {
        // 'f'=6, 'r'=18, 'a'=1 → (6<<10) | (18<<5) | 1 = 0x1A41
        var reader = BinaryReader(Data([0x1A, 0x41]))
        #expect(try reader.readLanguageCode() == "fra")
    }

    @Test
    func readLanguageCodeUnd() throws {
        // 'u'=21, 'n'=14, 'd'=4 → (21<<10) | (14<<5) | 4 = 0x55C4
        var reader = BinaryReader(Data([0x55, 0xC4]))
        #expect(try reader.readLanguageCode() == "und")
    }

    // MARK: Data / Bytes / skip / peek / readToEnd

    @Test
    func readDataExact() throws {
        var reader = BinaryReader(Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE]))
        let slice = try reader.readData(count: 3)
        #expect(Array(slice) == [0xAA, 0xBB, 0xCC])
        #expect(reader.offset == 3)
    }

    @Test
    func readBytesExact() throws {
        var reader = BinaryReader(Data([0x11, 0x22, 0x33]))
        let bytes = try reader.readBytes(count: 3)
        #expect(bytes == [0x11, 0x22, 0x33])
    }

    @Test
    func insufficientDataThrows() {
        var reader = BinaryReader(Data([0x01, 0x02]))
        do {
            _ = try reader.readUInt32()
            Issue.record("expected insufficientData throw")
        } catch let err as BinaryIOError {
            if case let .insufficientData(expected, available) = err {
                #expect(expected == 4)
                #expect(available == 2)
            } else {
                Issue.record("wrong case")
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func skipAdvancesOffset() throws {
        var reader = BinaryReader(Data([0xAA, 0xBB, 0xCC, 0xDD]))
        try reader.skip(2)
        #expect(reader.offset == 2)
        #expect(try reader.readUInt8() == 0xCC)
    }

    @Test
    func peekDoesNotAdvance() throws {
        let reader = BinaryReader(Data([0xAA, 0xBB, 0xCC]))
        let snapshot = try reader.peek(2)
        #expect(Array(snapshot) == [0xAA, 0xBB])
        #expect(reader.offset == 0)
    }

    @Test
    func peekPastEndThrows() {
        let reader = BinaryReader(Data([0xAA, 0xBB]))
        do {
            _ = try reader.peek(5)
            Issue.record("expected insufficientData throw")
        } catch let err as BinaryIOError {
            if case let .insufficientData(expected, available) = err {
                #expect(expected == 5)
                #expect(available == 2)
            } else {
                Issue.record("wrong case")
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func readToEndConsumesRest() {
        var reader = BinaryReader(Data([0x01, 0x02, 0x03, 0x04]), offset: 1)
        let rest = reader.readToEnd()
        #expect(Array(rest) == [0x02, 0x03, 0x04])
        #expect(reader.remaining == 0)
    }

    @Test
    func remainingBookkeeping() throws {
        var reader = BinaryReader(Data([0x01, 0x02, 0x03, 0x04, 0x05]))
        #expect(reader.remaining == 5)
        _ = try reader.readUInt16()
        #expect(reader.remaining == 3)
        _ = try reader.readUInt8()
        #expect(reader.remaining == 2)
    }

    // MARK: Sendability

    @Test
    func sendableAcrossActorHop() async throws {
        actor Holder {
            var received: Data = .init()
            func store(_ data: Data) { received = data }
        }
        let reader = BinaryReader(Data([0x01, 0x02, 0x03]))
        let holder = Holder()
        await holder.store(reader.data)
        let echoed = await holder.received
        #expect(Array(echoed) == [0x01, 0x02, 0x03])
    }
}
