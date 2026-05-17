// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for EncodedFrame — value-type sample carrier.

import Foundation
import Testing

@testable import CMAFKit

@Suite("EncodedFrame")
struct EncodedFrameTests {

    @Test
    func memberwiseInitPopulatesFields() {
        let dts = MediaTimestamp(value: 0, timescale: 90_000)
        let pts = MediaTimestamp(value: 100, timescale: 90_000)
        let duration = MediaTimestamp(value: 3_000, timescale: 90_000)
        let frame = EncodedFrame(
            codec: .h264,
            data: Data([0x01, 0x02, 0x03]),
            isKeyframe: true,
            decodingTime: dts,
            presentationTime: pts,
            duration: duration
        )
        #expect(frame.codec == .h264)
        #expect(Array(frame.data) == [0x01, 0x02, 0x03])
        #expect(frame.isKeyframe == true)
        #expect(frame.decodingTime == dts)
        #expect(frame.presentationTime == pts)
        #expect(frame.duration == duration)
        #expect(frame.dependencyInfo == nil)
        #expect(frame.hdrMetadata == nil)
    }

    @Test
    func optionalMetadataAttached() {
        let ts = MediaTimestamp(value: 0, timescale: 90_000)
        let dep = SampleDependencyInfo(
            dependsOn: .no,
            isDependedOn: .yes,
            hasRedundancy: .no
        )
        let hdr = HDRMetadata(
            dynamicRange: .hdr10,
            colorPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709,
            fullRange: false
        )
        let frame = EncodedFrame(
            codec: .h265,
            data: Data(),
            isKeyframe: true,
            decodingTime: ts,
            presentationTime: ts,
            duration: ts,
            dependencyInfo: dep,
            hdrMetadata: hdr
        )
        #expect(frame.dependencyInfo == dep)
        #expect(frame.hdrMetadata == hdr)
    }

    @Test
    func sendableAcrossActorHop() async {
        actor Holder {
            var frame: EncodedFrame?
            func store(_ frame: EncodedFrame) { self.frame = frame }
        }
        let ts = MediaTimestamp(value: 0, timescale: 90_000)
        let original = EncodedFrame(
            codec: .aac(.lc),
            data: Data([0xFF, 0xF1]),
            isKeyframe: false,
            decodingTime: ts,
            presentationTime: ts,
            duration: ts
        )
        let holder = Holder()
        await holder.store(original)
        let echoed = await holder.frame
        #expect(echoed?.codec == .aac(.lc))
        #expect(Array(echoed?.data ?? Data()) == [0xFF, 0xF1])
    }
}
