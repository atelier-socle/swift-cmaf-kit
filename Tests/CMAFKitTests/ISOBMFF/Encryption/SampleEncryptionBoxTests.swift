// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleEncryptionBox (senc)")
struct SampleEncryptionBoxTests {

    private static func makeIV8() -> Data {
        Data(repeating: 0x77, count: 8)
    }

    private static func makeIV16() -> Data {
        Data(repeating: 0x88, count: 16)
    }

    private func parseRoundTrip(
        _ box: SampleEncryptionBox,
        ivSize: TrackEncryptionBox.PerSampleIVSize
    ) async throws -> SampleEncryptionBox {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // Read the header manually since senc is not in the default registry.
        var reader = BinaryReader(writer.data)
        let boxReader = ISOBoxReader()
        let header = try boxReader.parseBoxHeader(&reader)
        #expect(header.type == SampleEncryptionBox.boxType)
        let bodySize = Int(header.size) - header.headerSize
        let body = try reader.readData(count: bodySize)
        var bodyReader = BinaryReader(body)
        let registry = await BoxRegistry.defaultRegistry()
        return try await SampleEncryptionBox.parse(
            reader: &bodyReader,
            header: header,
            registry: registry,
            ivSize: ivSize
        )
    }

    @Test
    func eightByteIVNoSubsamplesRoundTrip() async throws {
        let entries = [
            SampleEncryptionBox.SampleEncryptionEntry(initializationVector: Self.makeIV8()),
            SampleEncryptionBox.SampleEncryptionEntry(initializationVector: Self.makeIV8())
        ]
        let box = SampleEncryptionBox(samples: entries)
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        #expect(parsed == box)
    }

    @Test
    func sixteenByteIVRoundTrip() async throws {
        let entries = [
            SampleEncryptionBox.SampleEncryptionEntry(initializationVector: Self.makeIV16())
        ]
        let box = SampleEncryptionBox(samples: entries)
        let parsed = try await parseRoundTrip(box, ivSize: .sixteen)
        #expect(parsed == box)
    }

    @Test
    func emptyEntriesRoundTrip() async throws {
        let box = SampleEncryptionBox(samples: [])
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        #expect(parsed.samples.isEmpty)
    }

    @Test
    func subsamplesPartitionRoundTrip() async throws {
        let subs = [
            SampleEncryptionBox.SubsamplePartition(bytesOfClearData: 16, bytesOfProtectedData: 1024),
            SampleEncryptionBox.SubsamplePartition(bytesOfClearData: 4, bytesOfProtectedData: 512)
        ]
        let entry = SampleEncryptionBox.SampleEncryptionEntry(
            initializationVector: Self.makeIV8(),
            subsamples: subs
        )
        let box = SampleEncryptionBox(
            flags: SampleEncryptionBox.flagUseSubsamples,
            samples: [entry]
        )
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        #expect(parsed.samples.first?.subsamples?.count == 2)
        #expect(parsed.samples.first?.subsamples?[0].bytesOfClearData == 16)
        #expect(parsed.samples.first?.subsamples?[1].bytesOfProtectedData == 512)
    }

    @Test
    func zeroIVSizeWithEmptyIVs() async throws {
        let entry = SampleEncryptionBox.SampleEncryptionEntry(initializationVector: Data())
        let box = SampleEncryptionBox(samples: [entry])
        let parsed = try await parseRoundTrip(box, ivSize: .zero)
        #expect(parsed.samples.first?.initializationVector.isEmpty == true)
    }

    @Test
    func boxType() {
        #expect(SampleEncryptionBox.boxType == "senc")
    }

    @Test
    func versionMustBeZero() async throws {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "senc", version: 1, flags: 0) { body in
            body.writeUInt32(0)
        }
        var reader = BinaryReader(writer.data)
        let boxReader = ISOBoxReader()
        let header = try boxReader.parseBoxHeader(&reader)
        let bodySize = Int(header.size) - header.headerSize
        let body = try reader.readData(count: bodySize)
        var bodyReader = BinaryReader(body)
        let registry = await BoxRegistry.defaultRegistry()
        await #expect(throws: ISOBoxError.self) {
            _ = try await SampleEncryptionBox.parse(
                reader: &bodyReader,
                header: header,
                registry: registry,
                ivSize: .eight
            )
        }
    }

    @Test
    func notInDefaultRegistry() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "senc")
        #expect(parser == nil)
    }

    @Test
    func useSubsamplesFlagBitMatchesStandard() {
        #expect(SampleEncryptionBox.flagUseSubsamples == 0x0000_0002)
    }

    @Test
    func multipleSamplesByteForByteRoundTrip() async throws {
        let entries = (0..<10).map { i in
            SampleEncryptionBox.SampleEncryptionEntry(
                initializationVector: Data(repeating: UInt8(i + 1), count: 8)
            )
        }
        let box = SampleEncryptionBox(samples: entries)
        var w1 = BinaryWriter()
        box.encode(to: &w1)
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func subsampleEqualityComparesFields() {
        let a = SampleEncryptionBox.SubsamplePartition(
            bytesOfClearData: 16,
            bytesOfProtectedData: 1024
        )
        let b = SampleEncryptionBox.SubsamplePartition(
            bytesOfClearData: 16,
            bytesOfProtectedData: 1024
        )
        let c = SampleEncryptionBox.SubsamplePartition(
            bytesOfClearData: 16,
            bytesOfProtectedData: 2048
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func entryEqualityComparesFields() {
        let a = SampleEncryptionBox.SampleEncryptionEntry(
            initializationVector: Data(repeating: 0x01, count: 8)
        )
        let b = SampleEncryptionBox.SampleEncryptionEntry(
            initializationVector: Data(repeating: 0x01, count: 8)
        )
        let c = SampleEncryptionBox.SampleEncryptionEntry(
            initializationVector: Data(repeating: 0x02, count: 8)
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func multipleEntriesWithSubsamples() async throws {
        let subs1 = [
            SampleEncryptionBox.SubsamplePartition(bytesOfClearData: 8, bytesOfProtectedData: 1000)
        ]
        let subs2 = [
            SampleEncryptionBox.SubsamplePartition(bytesOfClearData: 16, bytesOfProtectedData: 2000),
            SampleEncryptionBox.SubsamplePartition(bytesOfClearData: 4, bytesOfProtectedData: 100)
        ]
        let entries = [
            SampleEncryptionBox.SampleEncryptionEntry(
                initializationVector: Data(repeating: 0xAA, count: 8),
                subsamples: subs1
            ),
            SampleEncryptionBox.SampleEncryptionEntry(
                initializationVector: Data(repeating: 0xBB, count: 8),
                subsamples: subs2
            )
        ]
        let box = SampleEncryptionBox(
            flags: SampleEncryptionBox.flagUseSubsamples,
            samples: entries
        )
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        #expect(parsed.samples.count == 2)
        #expect(parsed.samples[0].subsamples?.count == 1)
        #expect(parsed.samples[1].subsamples?.count == 2)
    }

    @Test
    func encodedSizeWithoutSubsamples() {
        let entries = (0..<5).map { i in
            SampleEncryptionBox.SampleEncryptionEntry(
                initializationVector: Data(repeating: UInt8(i), count: 8)
            )
        }
        let box = SampleEncryptionBox(samples: entries)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // 8 hdr + 4 fullBox + 4 sampleCount + 5 entries × 8 bytes IV = 56
        #expect(writer.data.count == 56)
    }

    @Test
    func zeroSubsamplesWithFlagSet() async throws {
        let entry = SampleEncryptionBox.SampleEncryptionEntry(
            initializationVector: Self.makeIV8(),
            subsamples: []
        )
        let box = SampleEncryptionBox(
            flags: SampleEncryptionBox.flagUseSubsamples,
            samples: [entry]
        )
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        #expect(parsed.samples.first?.subsamples?.isEmpty == true)
    }

    @Test
    func subsampleWithZeroClearData() async throws {
        let entry = SampleEncryptionBox.SampleEncryptionEntry(
            initializationVector: Self.makeIV8(),
            subsamples: [
                SampleEncryptionBox.SubsamplePartition(
                    bytesOfClearData: 0,
                    bytesOfProtectedData: 4096
                )
            ]
        )
        let box = SampleEncryptionBox(
            flags: SampleEncryptionBox.flagUseSubsamples,
            samples: [entry]
        )
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        #expect(parsed.samples.first?.subsamples?[0].bytesOfClearData == 0)
    }

    @Test
    func subsampleWithZeroProtectedData() async throws {
        let entry = SampleEncryptionBox.SampleEncryptionEntry(
            initializationVector: Self.makeIV8(),
            subsamples: [
                SampleEncryptionBox.SubsamplePartition(
                    bytesOfClearData: 32,
                    bytesOfProtectedData: 0
                )
            ]
        )
        let box = SampleEncryptionBox(
            flags: SampleEncryptionBox.flagUseSubsamples,
            samples: [entry]
        )
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        #expect(parsed.samples.first?.subsamples?[0].bytesOfProtectedData == 0)
    }

    @Test
    func subsampleMaximumValues() async throws {
        let entry = SampleEncryptionBox.SampleEncryptionEntry(
            initializationVector: Self.makeIV8(),
            subsamples: [
                SampleEncryptionBox.SubsamplePartition(
                    bytesOfClearData: UInt16.max,
                    bytesOfProtectedData: UInt32.max
                )
            ]
        )
        let box = SampleEncryptionBox(
            flags: SampleEncryptionBox.flagUseSubsamples,
            samples: [entry]
        )
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        let partition = try #require(parsed.samples.first?.subsamples?[0])
        #expect(partition.bytesOfClearData == UInt16.max)
        #expect(partition.bytesOfProtectedData == UInt32.max)
    }

    @Test
    func subsampleCodableRoundTrip() throws {
        let partition = SampleEncryptionBox.SubsamplePartition(
            bytesOfClearData: 32,
            bytesOfProtectedData: 4096
        )
        let encoded = try JSONEncoder().encode(partition)
        let decoded = try JSONDecoder().decode(
            SampleEncryptionBox.SubsamplePartition.self,
            from: encoded
        )
        #expect(decoded == partition)
    }

    @Test
    func multipleSampleHashStability() {
        let entries = (0..<5).map { i in
            SampleEncryptionBox.SampleEncryptionEntry(
                initializationVector: Data(repeating: UInt8(i + 1), count: 8)
            )
        }
        let box1 = SampleEncryptionBox(samples: entries)
        let box2 = SampleEncryptionBox(samples: entries)
        var set: Set<SampleEncryptionBox> = [box1]
        set.insert(box2)
        #expect(set.count == 1)
    }

    @Test
    func flagsArePreservedOnRoundTrip() async throws {
        let box = SampleEncryptionBox(
            flags: SampleEncryptionBox.flagUseSubsamples | 0x80,
            samples: [
                SampleEncryptionBox.SampleEncryptionEntry(
                    initializationVector: Self.makeIV8(),
                    subsamples: []
                )
            ]
        )
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        #expect(parsed.flags == box.flags)
    }

    @Test
    func largeSampleCountStableEncoding() async throws {
        let entries = (0..<100).map { _ in
            SampleEncryptionBox.SampleEncryptionEntry(
                initializationVector: Data(repeating: 0xFF, count: 8)
            )
        }
        let box = SampleEncryptionBox(samples: entries)
        let parsed = try await parseRoundTrip(box, ivSize: .eight)
        #expect(parsed.samples.count == 100)
    }

    @Test
    func sixteenByteIVWithSubsamples() async throws {
        let entry = SampleEncryptionBox.SampleEncryptionEntry(
            initializationVector: Self.makeIV16(),
            subsamples: [
                SampleEncryptionBox.SubsamplePartition(
                    bytesOfClearData: 16,
                    bytesOfProtectedData: 8000
                )
            ]
        )
        let box = SampleEncryptionBox(
            flags: SampleEncryptionBox.flagUseSubsamples,
            samples: [entry]
        )
        let parsed = try await parseRoundTrip(box, ivSize: .sixteen)
        #expect(parsed.samples.first?.initializationVector.count == 16)
        #expect(parsed.samples.first?.subsamples?.count == 1)
    }
}
