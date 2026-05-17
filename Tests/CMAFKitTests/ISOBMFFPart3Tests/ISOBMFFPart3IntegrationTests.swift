// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Integration tests for fragment-level, indexing, random-access,
// sample-group, sample-auxiliary, and edit-list boxes — exercise full
// subtrees.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ISOBMFF Part 3 integration")
struct ISOBMFFPart3IntegrationTests {

    /// Builds a minimal fragmented `moof` containing one `traf` with
    /// `tfhd` + `tfdt` + `trun`.
    private func buildMinimalMoof() -> MovieFragmentBox {
        let mfhd = MovieFragmentHeaderBox(sequenceNumber: 1)
        let tfhd = TrackFragmentHeaderBox(
            trackID: 1,
            defaultSampleDuration: 1024,
            defaultSampleSize: 512
        )
        let tfdt = TrackFragmentDecodeTimeBox(baseMediaDecodeTime: 0)
        let trunTable = TrackRunTable(
            entries: [
                TrackRunEntry(sampleSize: 510),
                TrackRunEntry(sampleSize: 520)
            ],
            perSampleFlags: TrackRunTable.flagSampleSize,
            version: 1
        )
        let trun = TrackRunBox(dataOffset: 100, table: trunTable)
        let trafHeader = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
        let traf = TrackFragmentBox(header: trafHeader, children: [tfhd, tfdt, trun])
        let moofHeader = ISOBoxHeader(type: "moof", size: 0, headerSize: 8)
        return MovieFragmentBox(header: moofHeader, children: [mfhd, traf])
    }

    @Test
    func minimalMoofRoundTrip() async throws {
        let moof = buildMinimalMoof()
        var w1 = BinaryWriter()
        moof.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)

        let parsedMoof = try #require(boxes.first as? MovieFragmentBox)
        #expect(parsedMoof.movieFragmentHeader?.sequenceNumber == 1)
        let traf = try #require(parsedMoof.trackFragments.first)
        #expect(traf.trackFragmentHeader?.trackID == 1)
        #expect(traf.trackFragmentDecodeTime?.baseMediaDecodeTime == 0)
        #expect(traf.trackRuns.count == 1)
        #expect(traf.trackRuns[0].table.count == 2)
    }

    @Test
    func multiTrafMoofRoundTrip() async throws {
        func makeTraf(trackID: UInt32, decodeTime: UInt64) -> TrackFragmentBox {
            let tfhd = TrackFragmentHeaderBox(trackID: trackID)
            let tfdt = TrackFragmentDecodeTimeBox(baseMediaDecodeTime: decodeTime)
            let trun = TrackRunBox(
                table: TrackRunTable(entries: [], perSampleFlags: 0, version: 1)
            )
            let header = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
            return TrackFragmentBox(header: header, children: [tfhd, tfdt, trun])
        }
        let mfhd = MovieFragmentHeaderBox(sequenceNumber: 42)
        let traf1 = makeTraf(trackID: 1, decodeTime: 0)
        let traf2 = makeTraf(trackID: 2, decodeTime: 1024)
        let moofHeader = ISOBoxHeader(type: "moof", size: 0, headerSize: 8)
        let moof = MovieFragmentBox(header: moofHeader, children: [mfhd, traf1, traf2])

        var w1 = BinaryWriter()
        moof.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentBox)
        #expect(parsed.trackFragments.count == 2)
        #expect(parsed.trackFragments[0].trackFragmentHeader?.trackID == 1)
        #expect(parsed.trackFragments[1].trackFragmentDecodeTime?.baseMediaDecodeTime == 1024)
    }

    @Test
    func mvexUnderMoovRoundTrip() async throws {
        let trex1 = TrackExtendsBox(trackID: 1, defaultSampleDuration: 1024)
        let trex2 = TrackExtendsBox(trackID: 2, defaultSampleSize: 1500)
        let mvexHeader = ISOBoxHeader(type: "mvex", size: 0, headerSize: 8)
        let mvex = MovieExtendsBox(header: mvexHeader, children: [trex1, trex2])
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let moov = MovieBox(header: moovHeader, children: [mvex])

        var writer = BinaryWriter()
        moov.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsedMoov = try #require(boxes.first as? MovieBox)
        let parsedMvex = try #require(parsedMoov.movieExtends)
        #expect(parsedMvex.trackExtends.count == 2)
        #expect(parsedMvex.trackExtends[0].trackID == 1)
        #expect(parsedMvex.trackExtends[1].defaultSampleSize == 1500)
    }

    @Test
    func mvexWithMehdAndMultipleTrexRoundTrip() async throws {
        let mehd = MovieExtendsHeaderBox(fragmentDuration: 1_000_000)
        let trex = TrackExtendsBox(trackID: 1)
        let mvexHeader = ISOBoxHeader(type: "mvex", size: 0, headerSize: 8)
        let mvex = MovieExtendsBox(header: mvexHeader, children: [mehd, trex])

        var writer = BinaryWriter()
        mvex.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieExtendsBox)
        #expect(parsed.movieExtendsHeader?.fragmentDuration == 1_000_000)
        #expect(parsed.trackExtends.count == 1)
    }

    @Test
    func mfraFullTreeRoundTrip() async throws {
        let tfra = TrackFragmentRandomAccessBox(
            trackID: 1,
            table: TrackFragmentRandomAccessTable(entries: [
                TrackFragmentRandomAccessEntry(
                    time: 0, moofOffset: 1024,
                    trafNumber: 1, trunNumber: 1, sampleNumber: 1
                )
            ])
        )
        let mfro = MovieFragmentRandomAccessOffsetBox(mfraSize: 100)
        let mfraHeader = ISOBoxHeader(type: "mfra", size: 0, headerSize: 8)
        let mfra = MovieFragmentRandomAccessBox(header: mfraHeader, children: [tfra, mfro])

        var writer = BinaryWriter()
        mfra.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentRandomAccessBox)
        #expect(parsed.trackFragmentRandomAccess.count == 1)
        #expect(parsed.movieFragmentRandomAccessOffset != nil)
    }

    @Test
    func sampleGroupsUnderTraf() async throws {
        let sbgp = SampleToGroupBox(
            groupingType: "roll",
            table: SampleToGroupTable(entries: [
                SampleToGroupEntry(sampleCount: 10, groupDescriptionIndex: 1)
            ])
        )
        let sgpd = SampleGroupDescriptionBox(
            groupingType: "roll",
            defaultSampleDescriptionIndex: 0,
            entries: [RollSampleGroupDescription(rollDistance: -10)]
        )
        let tfhd = TrackFragmentHeaderBox(trackID: 1)
        let trafHeader = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
        let traf = TrackFragmentBox(header: trafHeader, children: [tfhd, sbgp, sgpd])

        var writer = BinaryWriter()
        traf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentBox)
        #expect(parsed.sampleToGroups.count == 1)
        #expect(parsed.sampleGroupDescriptions.count == 1)
        #expect(parsed.sampleToGroups[0].groupingType == "roll")
        let entry = try #require(parsed.sampleGroupDescriptions[0].entries.first as? RollSampleGroupDescription)
        #expect(entry.rollDistance == -10)
    }

    @Test
    func saiSizesAndOffsetsPairUnderTraf() async throws {
        let saiz = SampleAuxiliaryInformationSizesBox(
            constantSize: 16,
            sampleCount: 10,
            perSampleSizes: SampleInfoSizeTable(sizes: [])
        )
        let saio = SampleAuxiliaryInformationOffsetsBox(
            table: AuxInfoOffsetsTable(offsets: [0x1000])
        )
        let tfhd = TrackFragmentHeaderBox(trackID: 1)
        let trafHeader = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
        let traf = TrackFragmentBox(header: trafHeader, children: [tfhd, saiz, saio])

        var writer = BinaryWriter()
        traf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentBox)
        #expect(parsed.sampleAuxiliaryInformationSizes.count == 1)
        #expect(parsed.sampleAuxiliaryInformationOffsets.count == 1)
        #expect(parsed.sampleAuxiliaryInformationSizes[0].constantSize == 16)
    }

    @Test
    func editListUnderEdtsUnderTrak() async throws {
        let elst = EditListBox(
            table: EditListTable(entries: [
                EditListEntry(segmentDuration: 1024, mediaTime: -1),
                EditListEntry(segmentDuration: 4096, mediaTime: 0)
            ]))
        let edtsHeader = ISOBoxHeader(type: "edts", size: 0, headerSize: 8)
        let edts = EditBox(header: edtsHeader, children: [elst])
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let trak = TrackBox(header: trakHeader, children: [edts])

        var writer = BinaryWriter()
        trak.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackBox)
        let parsedEdts = try #require(parsed.findChild(EditBox.self))
        let parsedElst = try #require(parsedEdts.editList)
        #expect(parsedElst.table.count == 2)
        #expect(parsedElst.table[0].isEmptyEdit == true)
        #expect(parsedElst.table[1].isEmptyEdit == false)
    }
}
