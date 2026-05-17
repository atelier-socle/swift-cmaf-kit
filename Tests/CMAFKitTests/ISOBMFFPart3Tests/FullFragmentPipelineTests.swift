// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests that drive a complete fragmented presentation through encode →
// decode → encode and verify the resulting bytes match the inputs.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Full fragment pipeline")
struct FullFragmentPipelineTests {

    @Test
    func styleMoovWithMvexFollowedByMoof() async throws {
        // moov(mvex(mehd, trex)) ... moof(mfhd, traf(tfhd, tfdt, trun))
        let mehd = MovieExtendsHeaderBox(fragmentDuration: 1_000_000)
        let trex = TrackExtendsBox(trackID: 1, defaultSampleDuration: 1024)
        let mvexHeader = ISOBoxHeader(type: "mvex", size: 0, headerSize: 8)
        let mvex = MovieExtendsBox(header: mvexHeader, children: [mehd, trex])
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let moov = MovieBox(header: moovHeader, children: [mvex])

        let mfhd = MovieFragmentHeaderBox(sequenceNumber: 1)
        let tfhd = TrackFragmentHeaderBox(trackID: 1)
        let tfdt = TrackFragmentDecodeTimeBox(baseMediaDecodeTime: 0)
        let trun = TrackRunBox(
            dataOffset: 100,
            table: TrackRunTable(
                entries: [TrackRunEntry(sampleSize: 512)],
                perSampleFlags: TrackRunTable.flagSampleSize,
                version: 1
            )
        )
        let trafHeader = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
        let traf = TrackFragmentBox(header: trafHeader, children: [tfhd, tfdt, trun])
        let moofHeader = ISOBoxHeader(type: "moof", size: 0, headerSize: 8)
        let moof = MovieFragmentBox(header: moofHeader, children: [mfhd, traf])

        var w1 = BinaryWriter()
        moov.encode(to: &w1)
        moof.encode(to: &w1)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        #expect(boxes.count == 2)
        let parsedMoov = try #require(boxes[0] as? MovieBox)
        let parsedMoof = try #require(boxes[1] as? MovieFragmentBox)
        #expect(parsedMoov.movieExtends != nil)
        #expect(parsedMoof.movieFragmentHeader?.sequenceNumber == 1)

        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
    }

    @Test
    func segmentWithStypAndSidxAndMoofAndMdat() async throws {
        // styp + sidx + moof + mdat — a typical CMAF segment shape.
        let styp = SegmentTypeBox(majorBrand: "msdh", minorVersion: 0, compatibleBrands: ["msdh", "msix"])
        let sidx = SegmentIndexBox(
            referenceID: 1,
            timescale: 90_000,
            earliestPresentationTime: 0,
            firstOffset: 0,
            table: SegmentIndexTable(entries: [
                SegmentIndexEntry(
                    referenceType: false, referencedSize: 1024,
                    subsegmentDuration: 90_000, startsWithSAP: true,
                    sapType: 1, sapDeltaTime: 0
                )
            ])
        )
        let mfhd = MovieFragmentHeaderBox(sequenceNumber: 1)
        let tfhd = TrackFragmentHeaderBox(trackID: 1)
        let tfdt = TrackFragmentDecodeTimeBox(baseMediaDecodeTime: 0)
        let trun = TrackRunBox(
            table: TrackRunTable(
                entries: [TrackRunEntry(sampleDuration: 1024)],
                perSampleFlags: TrackRunTable.flagSampleDuration,
                version: 1
            )
        )
        let trafHeader = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
        let traf = TrackFragmentBox(header: trafHeader, children: [tfhd, tfdt, trun])
        let moofHeader = ISOBoxHeader(type: "moof", size: 0, headerSize: 8)
        let moof = MovieFragmentBox(header: moofHeader, children: [mfhd, traf])
        let mdat = MediaDataBox(data: Data(repeating: 0xAA, count: 256))

        var w1 = BinaryWriter()
        styp.encode(to: &w1)
        sidx.encode(to: &w1)
        moof.encode(to: &w1)
        mdat.encode(to: &w1)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        #expect(boxes.count == 4)
        #expect(boxes[0] is SegmentTypeBox)
        #expect(boxes[1] is SegmentIndexBox)
        #expect(boxes[2] is MovieFragmentBox)
        #expect(boxes[3] is MediaDataBox)

        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
    }

    @Test
    func mfraIndexAtEndOfFile() async throws {
        let tfra = TrackFragmentRandomAccessBox(
            trackID: 1,
            table: TrackFragmentRandomAccessTable(entries: [
                TrackFragmentRandomAccessEntry(
                    time: 0, moofOffset: 0x1000,
                    trafNumber: 1, trunNumber: 1, sampleNumber: 1
                ),
                TrackFragmentRandomAccessEntry(
                    time: 90_000, moofOffset: 0x2000,
                    trafNumber: 1, trunNumber: 1, sampleNumber: 1
                )
            ])
        )
        let mfraHeader = ISOBoxHeader(type: "mfra", size: 0, headerSize: 8)
        // mfra wraps the tfra and the mfro trailer.
        let mfraInner = MovieFragmentRandomAccessBox(header: mfraHeader, children: [tfra])
        var probeWriter = BinaryWriter()
        mfraInner.encode(to: &probeWriter)
        let totalMfraSize = UInt32(probeWriter.data.count + 16)  // + mfro size
        let mfro = MovieFragmentRandomAccessOffsetBox(mfraSize: totalMfraSize)
        let mfra = MovieFragmentRandomAccessBox(header: mfraHeader, children: [tfra, mfro])

        var w1 = BinaryWriter()
        mfra.encode(to: &w1)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentRandomAccessBox)
        #expect(parsed.trackFragmentRandomAccess.count == 1)
        #expect(parsed.movieFragmentRandomAccessOffset?.mfraSize == totalMfraSize)
    }

    @Test
    func trafCarriesAuxAndGroupsAndRuns() async throws {
        let tfhd = TrackFragmentHeaderBox(trackID: 1)
        let saiz = SampleAuxiliaryInformationSizesBox(
            constantSize: 16, sampleCount: 5,
            perSampleSizes: SampleInfoSizeTable(sizes: [])
        )
        let saio = SampleAuxiliaryInformationOffsetsBox(
            table: AuxInfoOffsetsTable(offsets: [0x1000])
        )
        let sbgp = SampleToGroupBox(
            groupingType: "roll",
            table: SampleToGroupTable(entries: [
                SampleToGroupEntry(sampleCount: 5, groupDescriptionIndex: 1)
            ])
        )
        let sgpd = SampleGroupDescriptionBox(
            groupingType: "roll",
            defaultSampleDescriptionIndex: 0,
            entries: [RollSampleGroupDescription(rollDistance: -1)]
        )
        let trun = TrackRunBox(
            table: TrackRunTable(
                entries: [TrackRunEntry(sampleSize: 16)],
                perSampleFlags: TrackRunTable.flagSampleSize,
                version: 1
            )
        )
        let trafHeader = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
        let traf = TrackFragmentBox(
            header: trafHeader,
            children: [
                tfhd, saiz, saio, sbgp, sgpd, trun
            ])

        var w1 = BinaryWriter()
        traf.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentBox)
        #expect(parsed.sampleAuxiliaryInformationSizes.count == 1)
        #expect(parsed.sampleAuxiliaryInformationOffsets.count == 1)
        #expect(parsed.sampleToGroups.count == 1)
        #expect(parsed.sampleGroupDescriptions.count == 1)
        #expect(parsed.trackRuns.count == 1)

        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func trakWithEditListAtFrontOfTimeline() async throws {
        // trak(edts(elst), tkhd, mdia(...))
        let elst = EditListBox(
            table: EditListTable(entries: [
                EditListEntry(segmentDuration: 1024, mediaTime: -1),
                EditListEntry(segmentDuration: 4096, mediaTime: 0)
            ]))
        let edtsHeader = ISOBoxHeader(type: "edts", size: 0, headerSize: 8)
        let edts = EditBox(header: edtsHeader, children: [elst])
        let tkhd = TrackHeaderBox(creationTime: 0, modificationTime: 0, trackID: 1, duration: 0)
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let trak = TrackBox(header: trakHeader, children: [tkhd, edts])

        var w1 = BinaryWriter()
        trak.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? TrackBox)
        let parsedEdts = try #require(parsed.findChild(EditBox.self))
        #expect(parsedEdts.editList?.table.count == 2)
        #expect(parsedEdts.editList?.table[0].isEmptyEdit == true)
    }

    @Test
    func cencSeigGroupDescriptionRoundTrip() async throws {
        let kid = try #require(UUID(uuidString: "12345678-1234-5678-1234-567812345678"))
        let sgpd = SampleGroupDescriptionBox(
            groupingType: "seig",
            defaultSampleDescriptionIndex: 1,
            entries: [
                CENCSampleGroupDescription(
                    cryptByteBlock: 1,
                    skipByteBlock: 9,
                    isProtected: 1,
                    perSampleIVSize: 0,
                    kid: kid,
                    constantIV: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
                )
            ]
        )
        var writer = BinaryWriter()
        sgpd.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        let entry = try #require(parsed.entries.first as? CENCSampleGroupDescription)
        #expect(entry.kid == kid)
        #expect(entry.cryptByteBlock == 1)
        #expect(entry.skipByteBlock == 9)
        #expect(entry.constantIV.count == 8)
    }

    @Test
    func emptyPdinRoundTrips() async throws {
        let original = ProgressiveDownloadInformationBox(
            table: ProgressiveDownloadTable(entries: [])
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ProgressiveDownloadInformationBox)
        #expect(parsed.table.count == 0)
    }

    @Test
    func ssixEmptyTableRoundTrips() async throws {
        let original = SubsegmentIndexBox(
            subsegmentCount: 0,
            table: SubsegmentIndexTable(entries: [])
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SubsegmentIndexBox)
        #expect(parsed.subsegmentCount == 0)
        #expect(parsed.table.count == 0)
    }
}
