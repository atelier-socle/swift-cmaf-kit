// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for ISOBoxReader.parseBoxHeader — ISO/IEC 14496-12 §4.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ISOBoxHeader parsing")
struct ISOBoxHeaderParsingTests {

    @Test
    func standardHeaderEightBytes() throws {
        // size=16, type='ftyp'
        let bytes = Data(hex: "00 00 00 10 66 74 79 70")
        var reader = BinaryReader(bytes)
        let isoReader = ISOBoxReader()
        let header = try isoReader.parseBoxHeader(&reader)
        #expect(header.type == "ftyp")
        #expect(header.size == 16)
        #expect(header.headerSize == 8)
        #expect(header.userType == nil)
    }

    @Test
    func largesizeHeaderSixteenBytes() throws {
        // size=1 sentinel, type='mdat', largesize=0x100000020
        let bytes = Data(
            hex: """
                00 00 00 01 6D 64 61 74
                00 00 00 01 00 00 00 20
                """)
        var reader = BinaryReader(bytes)
        let isoReader = ISOBoxReader()
        let header = try isoReader.parseBoxHeader(&reader)
        #expect(header.type == "mdat")
        #expect(header.size == 0x1_0000_0020)
        #expect(header.headerSize == 16)
    }

    @Test
    func uuidHeaderTwentyFourBytes() throws {
        let uuid = try #require(UUID(uuidString: "01234567-89AB-CDEF-FEDC-BA9876543210"))
        var writer = BinaryWriter()
        writer.writeUInt32(40)  // size
        writer.writeFourCC("uuid")
        writer.writeUUID(uuid)
        // Padding to make size match
        writer.writeZeros(16)

        var reader = BinaryReader(writer.data)
        let isoReader = ISOBoxReader()
        let header = try isoReader.parseBoxHeader(&reader)
        #expect(header.type == "uuid")
        #expect(header.size == 40)
        #expect(header.headerSize == 24)
        #expect(header.userType == uuid)
    }

    @Test
    func throwsOnSizeSmallerThanHeader() {
        // size=4 < header=8
        let bytes = Data(hex: "00 00 00 04 66 74 79 70")
        var reader = BinaryReader(bytes)
        let isoReader = ISOBoxReader()
        #expect(throws: ISOBoxError.self) {
            _ = try isoReader.parseBoxHeader(&reader)
        }
    }

    @Test
    func throwsOnTruncatedHeader() {
        let bytes = Data(hex: "00 00")  // only 2 bytes
        var reader = BinaryReader(bytes)
        let isoReader = ISOBoxReader()
        #expect(throws: BinaryIOError.self) {
            _ = try isoReader.parseBoxHeader(&reader)
        }
    }

    @Test
    func sizeZeroExtendsToEnd() throws {
        // size=0 means "to end of buffer"; remaining bytes after header.
        // Buffer: size(4)=0, type(4)='free', body(8 bytes of payload).
        let bytes = Data(hex: "00 00 00 00 66 72 65 65 AA BB CC DD EE FF 00 11")
        var reader = BinaryReader(bytes)
        let isoReader = ISOBoxReader()
        let header = try isoReader.parseBoxHeader(&reader)
        #expect(header.type == "free")
        // size resolves to total buffer size = 16.
        #expect(header.size == 16)
        #expect(header.headerSize == 8)
    }

    @Test
    func headerForFreeAndSkip() throws {
        let freeBytes = Data(hex: "00 00 00 08 66 72 65 65")
        let skipBytes = Data(hex: "00 00 00 08 73 6B 69 70")
        let isoReader = ISOBoxReader()
        var r1 = BinaryReader(freeBytes)
        var r2 = BinaryReader(skipBytes)
        let h1 = try isoReader.parseBoxHeader(&r1)
        let h2 = try isoReader.parseBoxHeader(&r2)
        #expect(h1.type == "free")
        #expect(h2.type == "skip")
    }

    @Test
    func resolvesAdvanceCorrectly() throws {
        // Two back-to-back boxes; verify offset advances exactly past the first header.
        let bytes = Data(
            hex: """
                00 00 00 08 66 72 65 65
                00 00 00 08 73 6B 69 70
                """)
        var reader = BinaryReader(bytes)
        let isoReader = ISOBoxReader()
        _ = try isoReader.parseBoxHeader(&reader)
        #expect(reader.offset == 8)
    }
}
