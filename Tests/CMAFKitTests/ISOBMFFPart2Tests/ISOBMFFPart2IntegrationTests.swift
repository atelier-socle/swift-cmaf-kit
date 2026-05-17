// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Integration tests for the Part 2 box types — exercise full subtrees.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ISOBMFF Part 2 integration")
struct ISOBMFFPart2IntegrationTests {

    /// Builds the synthetic `stbl` used by ``completeStblRoundTrip``.
    private func buildCompleteStbl() -> SampleTableBox {
        let stsd = SampleDescriptionBox(entries: [
            RawSampleEntry(format: "mp4a", dataReferenceIndex: 1, payload: Data([0x01, 0x02]))
        ])
        let stts = TimeToSampleBox(
            table: TimeToSampleTable(entries: [
                TimeToSampleEntry(sampleCount: 100, sampleDelta: 1024)
            ]))
        let ctts = CompositionOffsetBox(
            version: 1,
            table: CompositionOffsetTable(
                entries: [CompositionOffsetEntry(sampleCount: 5, sampleOffset: -100)],
                version: 1
            ))
        let stsc = SampleToChunkBox(
            table: SampleToChunkTable(entries: [
                SampleToChunkEntry(firstChunk: 1, samplesPerChunk: 10, sampleDescriptionIndex: 1)
            ]))
        let stsz = SampleSizeBox(table: SampleSizeTable(sizes: [100, 200, 300]))
        let stz2 = CompactSampleSizeBox(
            table: CompactSampleSizeTable(sizes: [10, 20, 30], fieldSize: .eightBits))
        let stco = ChunkOffsetBox(table: ChunkOffsetTable(offsets: [0x1000, 0x2000]))
        let co64 = ChunkLargeOffsetBox(table: ChunkLargeOffsetTable(offsets: [0x10000_0000]))
        let stss = SyncSampleBox(table: SyncSampleTable(sampleNumbers: [1, 25]))
        let sdtp = SampleDependencyTypeBox(
            table: SampleDependencyTable(entries: [
                SampleDependencyEntry(
                    isLeading: .notLeading,
                    dependsOn: .no,
                    isDependedOn: .yes,
                    hasRedundancy: .no)
            ]))
        let padb = PaddingBitsBox(table: PaddingBitsTable(values: [3, 5]))
        let header = ISOBoxHeader(type: "stbl", size: 0, headerSize: 8)
        return SampleTableBox(
            header: header,
            children: [stsd, stts, ctts, stsc, stsz, stz2, stco, co64, stss, sdtp, padb])
    }

    @Test
    func completeStblRoundTrip() async throws {
        let stbl = buildCompleteStbl()
        var w1 = BinaryWriter()
        stbl.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)

        let parsedStbl = try #require(boxes.first as? SampleTableBox)
        #expect(parsedStbl.sampleDescription != nil)
        #expect(parsedStbl.timeToSample?.table.count == 1)
        #expect(parsedStbl.compositionOffset?.version == 1)
        #expect(parsedStbl.sampleToChunk?.table.count == 1)
        #expect(parsedStbl.sampleSize?.table.count == 3)
        #expect(parsedStbl.compactSampleSize?.table.fieldSize == .eightBits)
        #expect(parsedStbl.chunkOffset?.table.count == 2)
        #expect(parsedStbl.chunkLargeOffset?.table[0] == 0x10000_0000)
        #expect(parsedStbl.syncSample?.table.count == 2)
        #expect(parsedStbl.sampleDependencyType?.table.count == 1)
        #expect(parsedStbl.paddingBits?.table.count == 2)
    }

    @Test
    func audioTrackBranchRoundTrip() async throws {
        // mdia → minf → smhd + dinf(dref(url self-contained)) + stbl(stsd(mp4a) + stts + stsc + stsz + stco)
        let smhd = SoundMediaHeaderBox()
        let dref = DataReferenceBox(entries: [
            DataEntryURLBox(selfContained: true, location: "")
        ])
        let dinfHeader = ISOBoxHeader(type: "dinf", size: 0, headerSize: 8)
        let dinf = DataInformationBox(header: dinfHeader, children: [dref])

        let stsd = SampleDescriptionBox(entries: [
            RawSampleEntry(format: "mp4a", dataReferenceIndex: 1, payload: Data([0xAA]))
        ])
        let stts = TimeToSampleBox(
            table: TimeToSampleTable(entries: [
                TimeToSampleEntry(sampleCount: 1000, sampleDelta: 1024)
            ]))
        let stsc = SampleToChunkBox(
            table: SampleToChunkTable(entries: [
                SampleToChunkEntry(firstChunk: 1, samplesPerChunk: 10, sampleDescriptionIndex: 1)
            ]))
        let stsz = SampleSizeBox(table: SampleSizeTable(count: 1000, constantSize: 128))
        let stco = ChunkOffsetBox(table: ChunkOffsetTable(offsets: [0x1000]))
        let stblHeader = ISOBoxHeader(type: "stbl", size: 0, headerSize: 8)
        let stbl = SampleTableBox(header: stblHeader, children: [stsd, stts, stsc, stsz, stco])

        let minfHeader = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        let minf = MediaInformationBox(header: minfHeader, children: [smhd, dinf, stbl])
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [minf])

        var w1 = BinaryWriter()
        mdia.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)

        let parsedMdia = try #require(boxes.first as? MediaBox)
        let parsedMinf = try #require(parsedMdia.mediaInformation)
        #expect(parsedMinf.soundMediaHeader != nil)
        #expect(parsedMinf.dataInformation?.dataReference != nil)
        #expect(parsedMinf.sampleTable?.sampleSize?.table.constantSize == 128)
    }

    @Test
    func videoTrackWithVmhdInFullTree() async throws {
        let vmhd = VideoMediaHeaderBox()
        let minfHeader = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        let minf = MediaInformationBox(header: minfHeader, children: [vmhd])
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [minf])
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let trak = TrackBox(header: trakHeader, children: [mdia])
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let moov = MovieBox(header: moovHeader, children: [trak])

        var writer = BinaryWriter()
        moov.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsedMoov = try #require(boxes.first as? MovieBox)
        let parsedVmhd = parsedMoov.tracks.first?.media?.mediaInformation?.videoMediaHeader
        #expect(parsedVmhd != nil)
    }

    @Test
    func pathLookupResolvesStsd() async throws {
        let stsd = SampleDescriptionBox(entries: [])
        let stblHeader = ISOBoxHeader(type: "stbl", size: 0, headerSize: 8)
        let stbl = SampleTableBox(header: stblHeader, children: [stsd])
        let minfHeader = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        let minf = MediaInformationBox(header: minfHeader, children: [stbl])
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [minf])
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let trak = TrackBox(header: trakHeader, children: [mdia])
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let moov = MovieBox(header: moovHeader, children: [trak])

        var writer = BinaryWriter()
        moov.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)

        let result = reader.findBox(at: "moov/trak/mdia/minf/stbl/stsd", in: boxes)
        #expect(result is SampleDescriptionBox)
    }

    @Test
    func cttsV1NegativeOffsetRoundTripsThroughTrak() async throws {
        let ctts = CompositionOffsetBox(
            version: 1,
            table: CompositionOffsetTable(
                entries: [CompositionOffsetEntry(sampleCount: 1, sampleOffset: -512)],
                version: 1
            ))
        let stblHeader = ISOBoxHeader(type: "stbl", size: 0, headerSize: 8)
        let stbl = SampleTableBox(header: stblHeader, children: [ctts])
        let minfHeader = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        let minf = MediaInformationBox(header: minfHeader, children: [stbl])
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [minf])

        var writer = BinaryWriter()
        mdia.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsedMdia = try #require(boxes.first as? MediaBox)
        let parsedCtts = parsedMdia.mediaInformation?.sampleTable?.compositionOffset
        #expect(parsedCtts?.table[0].sampleOffset == -512)
    }

    @Test
    func stsdWithTwoRawSampleEntries() async throws {
        let stsd = SampleDescriptionBox(entries: [
            RawSampleEntry(format: "abcd", dataReferenceIndex: 1, payload: Data([0x01])),
            RawSampleEntry(format: "efgh", dataReferenceIndex: 1, payload: Data([0x02]))
        ])
        var writer = BinaryWriter()
        stsd.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleDescriptionBox)
        #expect(parsed.entries.count == 2)
        let first = try #require(parsed.entries[0] as? RawSampleEntry)
        let second = try #require(parsed.entries[1] as? RawSampleEntry)
        #expect(first.format == "abcd")
        #expect(second.format == "efgh")
    }

    @Test
    func drefWithThreeMixedEntries() async throws {
        let dref = DataReferenceBox(entries: [
            DataEntryURLBox(selfContained: true, location: ""),
            DataEntryURLBox(selfContained: false, location: "file:///media.mp4"),
            DataEntryURNBox(selfContained: false, name: "urn:example", location: "x")
        ])
        var w1 = BinaryWriter()
        dref.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
        let parsed = try #require(boxes.first as? DataReferenceBox)
        #expect(parsed.entries.count == 3)
    }
}
