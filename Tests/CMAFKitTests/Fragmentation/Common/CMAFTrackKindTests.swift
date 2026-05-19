// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFTrackKind + codec enums")
struct CMAFTrackKindTests {

    @Test
    func handlerTypesMatchStandard() {
        #expect(CMAFTrackKind.video.handlerType == "vide")
        #expect(CMAFTrackKind.audio.handlerType == "soun")
        #expect(CMAFTrackKind.subtitle.handlerType == "subt")
        #expect(CMAFTrackKind.metadata.handlerType == "meta")
    }

    @Test
    func videoCodecFourCCs() {
        #expect(VideoCodec.avc1.sampleEntryFourCC == "avc1")
        #expect(VideoCodec.avc3.sampleEntryFourCC == "avc3")
        #expect(VideoCodec.hvc1.sampleEntryFourCC == "hvc1")
        #expect(VideoCodec.hev1.sampleEntryFourCC == "hev1")
        #expect(VideoCodec.dvh1.sampleEntryFourCC == "dvh1")
        #expect(VideoCodec.dvhe.sampleEntryFourCC == "dvhe")
        #expect(VideoCodec.vp08.sampleEntryFourCC == "vp08")
        #expect(VideoCodec.vp09.sampleEntryFourCC == "vp09")
        #expect(VideoCodec.av01.sampleEntryFourCC == "av01")
        #expect(VideoCodec.mp4v.sampleEntryFourCC == "mp4v")
    }

    @Test
    func audioCodecFourCCs() {
        #expect(AudioCodec.mp4a.sampleEntryFourCC == "mp4a")
        #expect(AudioCodec.ac3.sampleEntryFourCC == "ac-3")
        #expect(AudioCodec.ec3.sampleEntryFourCC == "ec-3")
        #expect(AudioCodec.ac4.sampleEntryFourCC == "ac-4")
        #expect(AudioCodec.opus.sampleEntryFourCC == "Opus")
        #expect(AudioCodec.flac.sampleEntryFourCC == "fLaC")
        #expect(AudioCodec.mpegHMain.sampleEntryFourCC == "mhm1")
        #expect(AudioCodec.mpegHMultiStream.sampleEntryFourCC == "mhm2")
    }

    @Test
    func subtitleCodecFourCCs() {
        #expect(SubtitleCodec.webVTT.sampleEntryFourCC == "wvtt")
        #expect(SubtitleCodec.imsc1Text.sampleEntryFourCC == "stpp")
        #expect(SubtitleCodec.imsc1Image.sampleEntryFourCC == "stpp")
    }

    @Test
    func enumsCodableRoundTrip() throws {
        for kind in CMAFTrackKind.allCases {
            let enc = try JSONEncoder().encode(kind)
            #expect(try JSONDecoder().decode(CMAFTrackKind.self, from: enc) == kind)
        }
        for codec in VideoCodec.allCases {
            let enc = try JSONEncoder().encode(codec)
            #expect(try JSONDecoder().decode(VideoCodec.self, from: enc) == codec)
        }
        for codec in AudioCodec.allCases {
            let enc = try JSONEncoder().encode(codec)
            #expect(try JSONDecoder().decode(AudioCodec.self, from: enc) == codec)
        }
    }
}
