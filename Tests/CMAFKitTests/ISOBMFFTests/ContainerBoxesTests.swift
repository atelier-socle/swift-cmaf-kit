// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for the 8 container boxes (moov, trak, mdia, minf, dinf, stbl,
// edts, udta) — ISO/IEC 14496-12 §8.2.1, §8.3.1, §8.4.1, §8.4.4, §8.7.1,
// §8.5.1, §8.6.5, §8.10.1.

import Foundation
import Testing

@testable import CMAFKit

// MARK: - MovieBox (moov)

@Suite("MovieBox")
struct MovieBoxTests {

    @Test
    func emptyMovieRoundTrip() async throws {
        let header = ISOBoxHeader(type: "moov", size: 8, headerSize: 8)
        let movie = MovieBox(header: header, children: [])
        var writer = BinaryWriter()
        movie.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieBox)
        #expect(parsed.children.isEmpty)
    }

    @Test
    func movieWithMvhdAndTrak() async throws {
        let mvhd = MovieHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: 5000,
            nextTrackID: 2
        )
        let trakHeader = ISOBoxHeader(type: "trak", size: 8, headerSize: 8)
        let trak = TrackBox(header: trakHeader, children: [])
        let movieHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let movie = MovieBox(header: movieHeader, children: [mvhd, trak])

        var writer = BinaryWriter()
        movie.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieBox)
        #expect(parsed.movieHeader?.timescale == 1000)
        #expect(parsed.tracks.count == 1)
    }

    @Test
    func unknownChildRoundTripsViaUnknownBox() async throws {
        let header = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let privHeader = ISOBoxHeader(type: "priv", size: 8, headerSize: 8)
        let priv = UnknownBox(actualType: "priv", header: privHeader, payload: Data())
        let movie = MovieBox(header: header, children: [priv])

        var w1 = BinaryWriter()
        movie.encode(to: &w1)
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
    func mvexAccessorReturnsUnknownBox() async throws {
        let header = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let mvexHeader = ISOBoxHeader(type: "mvex", size: 8, headerSize: 8)
        let mvex = UnknownBox(actualType: "mvex", header: mvexHeader, payload: Data())
        let movie = MovieBox(header: header, children: [mvex])
        #expect(movie.movieExtends != nil)
    }

    @Test
    func userDataAccessorReturnsUdta() {
        let movieHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let udtaHeader = ISOBoxHeader(type: "udta", size: 8, headerSize: 8)
        let udta = UserDataBox(header: udtaHeader, children: [])
        let movie = MovieBox(header: movieHeader, children: [udta])
        #expect(movie.userData != nil)
    }

    @Test
    func tracksOrderPreserved() {
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let trakHeader = ISOBoxHeader(type: "trak", size: 8, headerSize: 8)
        let t1 = TrackBox(header: trakHeader, children: [])
        let t2 = TrackBox(header: trakHeader, children: [])
        let t3 = TrackBox(header: trakHeader, children: [])
        let movie = MovieBox(header: moovHeader, children: [t1, t2, t3])
        #expect(movie.tracks.count == 3)
    }
}

// MARK: - TrackBox (trak)

@Suite("TrackBox")
struct TrackBoxTests {

    @Test
    func emptyTrackRoundTrip() async throws {
        let header = ISOBoxHeader(type: "trak", size: 8, headerSize: 8)
        let track = TrackBox(header: header, children: [])
        var writer = BinaryWriter()
        track.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackBox)
        #expect(parsed.children.isEmpty)
    }

    @Test
    func trackHeaderAccessorReturnsTkhd() {
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let tkhd = TrackHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            trackID: 1,
            duration: 0
        )
        let track = TrackBox(header: trakHeader, children: [tkhd])
        #expect(track.trackHeader?.trackID == 1)
    }

    @Test
    func mediaAccessorReturnsMdia() {
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 8, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [])
        let track = TrackBox(header: trakHeader, children: [mdia])
        #expect(track.media != nil)
    }

    @Test
    func editsAccessorReturnsEdts() {
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let edtsHeader = ISOBoxHeader(type: "edts", size: 8, headerSize: 8)
        let edts = EditBox(header: edtsHeader, children: [])
        let track = TrackBox(header: trakHeader, children: [edts])
        #expect(track.edits != nil)
    }

    @Test
    func childOrderPreservedAcrossRoundTrip() async throws {
        let trakHeader = ISOBoxHeader(type: "trak", size: 0, headerSize: 8)
        let tkhd = TrackHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            trackID: 7,
            duration: 0
        )
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 8, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [])
        let track = TrackBox(header: trakHeader, children: [tkhd, mdia])

        var writer = BinaryWriter()
        track.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackBox)
        #expect(parsed.children.count == 2)
        #expect(parsed.children[0] is TrackHeaderBox)
        #expect(parsed.children[1] is MediaBox)
    }

    @Test
    func absentAccessorsReturnNil() {
        let trakHeader = ISOBoxHeader(type: "trak", size: 8, headerSize: 8)
        let track = TrackBox(header: trakHeader, children: [])
        #expect(track.trackHeader == nil)
        #expect(track.media == nil)
        #expect(track.edits == nil)
    }
}

// MARK: - MediaBox (mdia)

@Suite("MediaBox")
struct MediaBoxTests {

    @Test
    func emptyRoundTrip() async throws {
        let header = ISOBoxHeader(type: "mdia", size: 8, headerSize: 8)
        let mdia = MediaBox(header: header, children: [])
        var writer = BinaryWriter()
        mdia.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is MediaBox)
    }

    @Test
    func mediaHeaderAccessor() {
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let mdhd = MediaHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 48_000,
            duration: 0,
            language: "und"
        )
        let mdia = MediaBox(header: mdiaHeader, children: [mdhd])
        #expect(mdia.mediaHeader?.timescale == 48_000)
    }

    @Test
    func handlerReferenceAccessor() {
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let hdlr = HandlerReferenceBox(handlerType: HandlerReferenceBox.typeAudio, name: "")
        let mdia = MediaBox(header: mdiaHeader, children: [hdlr])
        #expect(mdia.handlerReference?.handlerType == "soun")
    }

    @Test
    func mediaInformationAccessor() {
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let minfHeader = ISOBoxHeader(type: "minf", size: 8, headerSize: 8)
        let minf = MediaInformationBox(header: minfHeader, children: [])
        let mdia = MediaBox(header: mdiaHeader, children: [minf])
        #expect(mdia.mediaInformation != nil)
    }

    @Test
    func roundTripWithChildren() async throws {
        let mdhd = MediaHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 90_000,
            duration: 1_800_000,
            language: "eng"
        )
        let hdlr = HandlerReferenceBox(handlerType: HandlerReferenceBox.typeVideo, name: "VideoHandler")
        let mdiaHeader = ISOBoxHeader(type: "mdia", size: 0, headerSize: 8)
        let mdia = MediaBox(header: mdiaHeader, children: [mdhd, hdlr])

        var writer = BinaryWriter()
        mdia.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MediaBox)
        #expect(parsed.mediaHeader?.timescale == 90_000)
        #expect(parsed.handlerReference?.name == "VideoHandler")
    }

    @Test
    func absentAccessorsReturnNil() {
        let header = ISOBoxHeader(type: "mdia", size: 8, headerSize: 8)
        let mdia = MediaBox(header: header, children: [])
        #expect(mdia.mediaHeader == nil)
        #expect(mdia.handlerReference == nil)
        #expect(mdia.mediaInformation == nil)
    }
}

// MARK: - MediaInformationBox (minf)

@Suite("MediaInformationBox")
struct MediaInformationBoxTests {

    @Test
    func emptyRoundTrip() async throws {
        let header = ISOBoxHeader(type: "minf", size: 8, headerSize: 8)
        let minf = MediaInformationBox(header: header, children: [])
        var writer = BinaryWriter()
        minf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is MediaInformationBox)
    }

    @Test
    func dataInformationAccessor() {
        let header = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        let dinfHeader = ISOBoxHeader(type: "dinf", size: 8, headerSize: 8)
        let dinf = DataInformationBox(header: dinfHeader, children: [])
        let minf = MediaInformationBox(header: header, children: [dinf])
        #expect(minf.dataInformation != nil)
    }

    @Test
    func sampleTableAccessor() {
        let header = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        let stblHeader = ISOBoxHeader(type: "stbl", size: 8, headerSize: 8)
        let stbl = SampleTableBox(header: stblHeader, children: [])
        let minf = MediaInformationBox(header: header, children: [stbl])
        #expect(minf.sampleTable != nil)
    }

    @Test
    func mediaHeaderChildPicksVmhd() async throws {
        // The accessor matches on the on-wire FourCC, so an UnknownBox
        // stand-in still resolves; the production path now produces a
        // typed VideoMediaHeaderBox and the accessor resolves equivalently.
        let header = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        let vmhdHeader = ISOBoxHeader(type: "vmhd", size: 8, headerSize: 8)
        let vmhd = UnknownBox(actualType: "vmhd", header: vmhdHeader, payload: Data())
        let minf = MediaInformationBox(header: header, children: [vmhd])
        #expect(minf.mediaHeaderChild != nil)
    }

    @Test
    func mediaHeaderChildReturnsNilWhenAbsent() {
        let header = ISOBoxHeader(type: "minf", size: 8, headerSize: 8)
        let minf = MediaInformationBox(header: header, children: [])
        #expect(minf.mediaHeaderChild == nil)
    }

    @Test
    func roundTripWithUnknownChildren() async throws {
        let header = ISOBoxHeader(type: "minf", size: 0, headerSize: 8)
        let stblHeader = ISOBoxHeader(type: "stbl", size: 8, headerSize: 8)
        let dinfHeader = ISOBoxHeader(type: "dinf", size: 8, headerSize: 8)
        let stbl = SampleTableBox(header: stblHeader, children: [])
        let dinf = DataInformationBox(header: dinfHeader, children: [])
        let minf = MediaInformationBox(header: header, children: [dinf, stbl])

        var w1 = BinaryWriter()
        minf.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes {
            box.encode(to: &w2)
        }
        #expect(w1.data == w2.data)
    }
}

// MARK: - DataInformationBox / SampleTableBox / EditBox / UserDataBox

@Suite("DataInformationBox")
struct DataInformationBoxTests {

    @Test
    func emptyRoundTrip() async throws {
        let header = ISOBoxHeader(type: "dinf", size: 8, headerSize: 8)
        let dinf = DataInformationBox(header: header, children: [])
        var writer = BinaryWriter()
        dinf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is DataInformationBox)
    }

    @Test
    func unknownChildRoundTrip() async throws {
        // Use a FourCC with no registered parser so the child round-trips
        // via UnknownBox. (`dref` is now a typed box.)
        let header = ISOBoxHeader(type: "dinf", size: 0, headerSize: 8)
        let unkHeader = ISOBoxHeader(type: "wxyz", size: 8, headerSize: 8)
        let unk = UnknownBox(actualType: "wxyz", header: unkHeader, payload: Data())
        let dinf = DataInformationBox(header: header, children: [unk])
        var w1 = BinaryWriter()
        dinf.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
    }
}

@Suite("SampleTableBox")
struct SampleTableBoxTests {

    @Test
    func emptyRoundTrip() async throws {
        let header = ISOBoxHeader(type: "stbl", size: 8, headerSize: 8)
        let stbl = SampleTableBox(header: header, children: [])
        var writer = BinaryWriter()
        stbl.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is SampleTableBox)
    }

    @Test
    func multipleUnknownChildrenRoundTrip() async throws {
        // Use FourCCs with no registered parser so the children round-trip
        // via UnknownBox. (`stsd`, `stts`, `stsz` are now typed boxes.)
        let header = ISOBoxHeader(type: "stbl", size: 0, headerSize: 8)
        let h1 = ISOBoxHeader(type: "wxy1", size: 8, headerSize: 8)
        let h2 = ISOBoxHeader(type: "wxy2", size: 8, headerSize: 8)
        let h3 = ISOBoxHeader(type: "wxy3", size: 8, headerSize: 8)
        let children: [any ISOBox] = [
            UnknownBox(actualType: "wxy1", header: h1, payload: Data()),
            UnknownBox(actualType: "wxy2", header: h2, payload: Data()),
            UnknownBox(actualType: "wxy3", header: h3, payload: Data())
        ]
        let stbl = SampleTableBox(header: header, children: children)
        var w1 = BinaryWriter()
        stbl.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
    }
}

@Suite("EditBox")
struct EditBoxTests {

    @Test
    func emptyRoundTrip() async throws {
        let header = ISOBoxHeader(type: "edts", size: 8, headerSize: 8)
        let edts = EditBox(header: header, children: [])
        var writer = BinaryWriter()
        edts.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is EditBox)
    }

    @Test
    func unknownElstChildRoundTrip() async throws {
        let header = ISOBoxHeader(type: "edts", size: 0, headerSize: 8)
        let elstHeader = ISOBoxHeader(type: "elst", size: 12, headerSize: 8)
        let elst = UnknownBox(actualType: "elst", header: elstHeader, payload: Data([0x00, 0x00, 0x00, 0x00]))
        let edts = EditBox(header: header, children: [elst])
        var w1 = BinaryWriter()
        edts.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
    }
}

@Suite("UserDataBox")
struct UserDataBoxTests {

    @Test
    func emptyRoundTrip() async throws {
        let header = ISOBoxHeader(type: "udta", size: 8, headerSize: 8)
        let udta = UserDataBox(header: header, children: [])
        var writer = BinaryWriter()
        udta.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is UserDataBox)
    }

    @Test
    func arbitraryChildPreserved() async throws {
        let header = ISOBoxHeader(type: "udta", size: 0, headerSize: 8)
        let cprtHeader = ISOBoxHeader(type: "cprt", size: 10, headerSize: 8)
        let cprt = UnknownBox(actualType: "cprt", header: cprtHeader, payload: Data([0xCC, 0xDD]))
        let udta = UserDataBox(header: header, children: [cprt])
        var w1 = BinaryWriter()
        udta.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
    }
}
