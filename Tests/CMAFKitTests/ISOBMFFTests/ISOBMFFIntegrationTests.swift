// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Integration tests — exercise the full ISOBMFF chain end-to-end.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ISOBMFF integration")
struct ISOBMFFIntegrationTests {

    @Test
    func minimalMovieTreeRoundTrip() async throws {
        // Build: moov → mvhd + (trak → tkhd + (mdia → mdhd + hdlr + minf))
        let mvhd = MovieHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: 60_000,
            nextTrackID: 2
        )
        let mdhd = MediaHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 48_000,
            duration: 2_880_000,
            language: "eng"
        )
        let hdlr = HandlerReferenceBox(handlerType: HandlerReferenceBox.typeAudio, name: "AudioHandler")
        let minfHeader = ISOBoxHeader(type: "minf", size: 8, headerSize: 8)
        let minf = MediaInformationBox(header: minfHeader, children: [])
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [mdhd, hdlr, minf])
        let tkhd = TrackHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            trackID: 1,
            duration: 60_000
        )
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let trak = TrackBox(header: trakHeader, children: [tkhd, mdia])
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let moov = MovieBox(header: moovHeader, children: [mvhd, trak])

        var writer = BinaryWriter()
        moov.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsedMoov = try #require(boxes.first as? MovieBox)
        #expect(parsedMoov.movieHeader?.timescale == 1000)
        let firstTrack = try #require(parsedMoov.tracks.first)
        #expect(firstTrack.trackHeader?.trackID == 1)
        let parsedMedia = try #require(firstTrack.media)
        #expect(parsedMedia.mediaHeader?.timescale == 48_000)
        #expect(parsedMedia.handlerReference?.handlerType == "soun")
    }

    @Test
    func pathBasedLookupResolvesHandler() async throws {
        let mdhd = MediaHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 48_000,
            duration: 0,
            language: "und"
        )
        let hdlr = HandlerReferenceBox(handlerType: HandlerReferenceBox.typeAudio, name: "Found")
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [mdhd, hdlr])
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let trak = TrackBox(header: trakHeader, children: [mdia])
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let moov = MovieBox(header: moovHeader, children: [trak])

        var writer = BinaryWriter()
        moov.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)

        let result = reader.findBox(at: "moov/trak/mdia/hdlr", in: boxes)
        let typedHdlr = try #require(result as? HandlerReferenceBox)
        #expect(typedHdlr.name == "Found")
    }

    @Test
    func movieWithUnknownGrandchildRoundTrip() async throws {
        // Build a movie whose mvhd has an extra unknown sibling.
        let mvhd = MovieHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: 0,
            nextTrackID: 2
        )
        let extraHeader = ISOBoxHeader(type: "xxxx", size: 10, headerSize: 8)
        let extra = UnknownBox(actualType: "xxxx", header: extraHeader, payload: Data([0xAA, 0xBB]))
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let moov = MovieBox(header: moovHeader, children: [mvhd, extra])

        var w1 = BinaryWriter()
        moov.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes {
            box.encode(to: &w2)
        }
        #expect(w1.data == w2.data)
    }

    @Test
    func ftypMoovOrderingRoundTrip() async throws {
        let ftyp = FileTypeBox(
            majorBrand: "isom",
            minorVersion: 0x200,
            compatibleBrands: ["isom", "cmfc"]
        )
        let mvhd = MovieHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: 0,
            nextTrackID: 2
        )
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let moov = MovieBox(header: moovHeader, children: [mvhd])

        var writer = BinaryWriter()
        ftyp.encode(to: &writer)
        moov.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.count == 2)
        let parsedFtyp = try #require(boxes[0] as? FileTypeBox)
        #expect(parsedFtyp.majorBrand == "isom")
        let parsedMoov = try #require(boxes[1] as? MovieBox)
        #expect(parsedMoov.movieHeader?.timescale == 1000)
    }

    @Test
    func sinfInsideSyntheticProtectedTrack() async throws {
        // Build a trak whose media is associated with a sinf carrying
        // frma + schm + (schi with an UnknownBox stand-in for tenc).
        let frma = OriginalFormatBox(dataFormat: "avc1")
        let schm = SchemeTypeBox(schemeType: "cenc", schemeVersion: 0x0001_0000)
        let tencHeader = ISOBoxHeader(type: "tenc", size: 16, headerSize: 8)
        let tenc = UnknownBox(
            actualType: "tenc",
            header: tencHeader,
            payload: Data([0x00, 0x00, 0x01, 0x08, 0x10, 0x11, 0x12, 0x13])
        )
        let schiHeader = ISOBoxHeader(type: "schi", size: 0, headerSize: 8)
        let schi = SchemeInformationBox(header: schiHeader, children: [tenc])
        let sinfHeader = ISOBoxHeader(type: "sinf", size: 0, headerSize: 8)
        let sinf = ProtectionSchemeInfoBox(header: sinfHeader, children: [frma, schm, schi])

        let stblHeader = ISOBoxHeader(type: "stbl", size: 0, headerSize: 8)
        let stbl = SampleTableBox(header: stblHeader, children: [sinf])
        let minfHeader = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        let minf = MediaInformationBox(header: minfHeader, children: [stbl])
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [minf])
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let trak = TrackBox(header: trakHeader, children: [mdia])

        var writer = BinaryWriter()
        trak.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)

        let result = reader.findBox(at: "trak/mdia/minf/stbl/sinf/schm", in: boxes)
        let parsedSchm = try #require(result as? SchemeTypeBox)
        #expect(parsedSchm.schemeType == "cenc")
    }
}
