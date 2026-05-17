// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for ISOBox / ISOFullBox / ISOContainerBox protocols + findChild helpers.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ISOBox protocols")
struct ISOBoxProtocolTests {

    @Test
    func boxTypeStaticProperty() {
        #expect(FileTypeBox.boxType == "ftyp")
        #expect(MovieBox.boxType == "moov")
        #expect(MediaDataBox.boxType == "mdat")
        #expect(SchemeTypeBox.boxType == "schm")
    }

    @Test
    func findChildReturnsFirstMatch() {
        let header = ISOBoxHeader(type: "moov", size: 8, headerSize: 8)
        let mvhd = MovieHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: 0,
            nextTrackID: 2
        )
        let movie = MovieBox(header: header, children: [mvhd])
        let retrieved = movie.findChild(MovieHeaderBox.self)
        #expect(retrieved?.timescale == 1000)
    }

    @Test
    func findChildReturnsNilWhenAbsent() {
        let header = ISOBoxHeader(type: "moov", size: 8, headerSize: 8)
        let movie = MovieBox(header: header, children: [])
        let retrieved = movie.findChild(MovieHeaderBox.self)
        #expect(retrieved == nil)
    }

    @Test
    func findChildrenReturnsAllMatches() {
        let header = ISOBoxHeader(type: "moov", size: 8, headerSize: 8)
        let trakHeader = ISOBoxHeader(type: "trak", size: 8, headerSize: 8)
        let track1 = TrackBox(header: trakHeader, children: [])
        let track2 = TrackBox(header: trakHeader, children: [])
        let movie = MovieBox(header: header, children: [track1, track2])
        let tracks = movie.findChildren(TrackBox.self)
        #expect(tracks.count == 2)
    }
}
