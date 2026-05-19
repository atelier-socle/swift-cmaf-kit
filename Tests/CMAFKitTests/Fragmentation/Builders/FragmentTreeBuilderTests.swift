// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("FragmentInvariance")
struct FragmentInvarianceTests {

    private func makeSamples(
        durations: [UInt32],
        sizes: [UInt32],
        flags: [SampleFlags],
        ctsOffsets: [Int32]
    ) -> [FragmentSampleMetadata] {
        zip(zip(durations, sizes), zip(flags, ctsOffsets)).map { pair, fl in
            let (dur, size) = pair
            let (flag, cts) = fl
            return FragmentSampleMetadata(
                sampleSize: size,
                durationInTimescale: dur,
                compositionTimeOffset: cts,
                flags: flag
            )
        }
    }

    @Test
    func allEqualDurationsHoistsDefault() {
        let samples = makeSamples(
            durations: [3000, 3000, 3000],
            sizes: [100, 200, 300],
            flags: [.syncSample, .nonSyncSample, .nonSyncSample],
            ctsOffsets: [0, 0, 0]
        )
        let invariance = FragmentInvariance.scan(samples: samples)
        #expect(invariance.defaultSampleDuration == 3000)
        #expect(invariance.defaultSampleSize == nil)
    }

    @Test
    func allEqualSizesHoistsDefault() {
        let samples = makeSamples(
            durations: [1000, 2000, 3000],
            sizes: [500, 500, 500],
            flags: [.syncSample, .nonSyncSample, .nonSyncSample],
            ctsOffsets: [0, 0, 0]
        )
        let invariance = FragmentInvariance.scan(samples: samples)
        #expect(invariance.defaultSampleSize == 500)
        #expect(invariance.defaultSampleDuration == nil)
    }

    @Test
    func firstSampleFlagsDifferDetected() {
        let samples = makeSamples(
            durations: [3000, 3000, 3000, 3000],
            sizes: [100, 100, 100, 100],
            flags: [.syncSample, .nonSyncSample, .nonSyncSample, .nonSyncSample],
            ctsOffsets: [0, 0, 0, 0]
        )
        let invariance = FragmentInvariance.scan(samples: samples)
        #expect(invariance.firstSampleFlagsDiffer)
        #expect(invariance.defaultSampleFlags == SampleFlags.nonSyncSample.rawValue)
        #expect(invariance.firstSampleFlags == SampleFlags.syncSample.rawValue)
    }

    @Test
    func allFlagsEqualHoistsDefaultFlags() {
        let samples = makeSamples(
            durations: [3000, 3000, 3000],
            sizes: [100, 100, 100],
            flags: [.nonSyncSample, .nonSyncSample, .nonSyncSample],
            ctsOffsets: [0, 0, 0]
        )
        let invariance = FragmentInvariance.scan(samples: samples)
        #expect(invariance.firstSampleFlagsDiffer == false)
        #expect(invariance.defaultSampleFlags == SampleFlags.nonSyncSample.rawValue)
    }

    @Test
    func ctsOffsetsDetected() {
        let samples = makeSamples(
            durations: [3000, 3000, 3000],
            sizes: [100, 100, 100],
            flags: [.syncSample, .nonSyncSample, .nonSyncSample],
            ctsOffsets: [0, 1000, -500]
        )
        let invariance = FragmentInvariance.scan(samples: samples)
        #expect(invariance.anyCompositionOffsetNonZero)
        #expect(invariance.anyCompositionOffsetNegative)
    }

    @Test
    func emptySamplesYieldsAllNil() {
        let invariance = FragmentInvariance.scan(samples: [])
        #expect(invariance.defaultSampleDuration == nil)
        #expect(invariance.defaultSampleSize == nil)
        #expect(invariance.defaultSampleFlags == nil)
        #expect(invariance.firstSampleFlagsDiffer == false)
    }
}

@Suite("FragmentTreeBuilder")
struct FragmentTreeBuilderTests {

    private func makeSamples(count: Int, syncFirst: Bool = true) -> [FragmentSampleMetadata] {
        (0..<count).map { i in
            FragmentSampleMetadata(
                sampleSize: 100,
                durationInTimescale: 3000,
                compositionTimeOffset: 0,
                flags: i == 0 && syncFirst ? .syncSample : .nonSyncSample
            )
        }
    }

    @Test
    func moofComposesWithMfhdAndTraf() async throws {
        let (moof, _) = FragmentTreeBuilder.makeMovieFragment(
            trackID: 1,
            sequenceNumber: 1,
            baseMediaDecodeTime: 0,
            samples: makeSamples(count: 10),
            dataOffsetFromMoof: 100
        )
        let mfhd = moof.children.compactMap { $0 as? MovieFragmentHeaderBox }.first
        let traf = moof.children.compactMap { $0 as? TrackFragmentBox }.first
        #expect(mfhd?.sequenceNumber == 1)
        #expect(traf != nil)
    }

    @Test
    func trafCarriesTfhdTfdtTrun() throws {
        let (moof, _) = FragmentTreeBuilder.makeMovieFragment(
            trackID: 1,
            sequenceNumber: 1,
            baseMediaDecodeTime: 90_000,
            samples: makeSamples(count: 5),
            dataOffsetFromMoof: 100
        )
        let traf = try #require(moof.children.compactMap { $0 as? TrackFragmentBox }.first)
        let tfhd = traf.children.compactMap { $0 as? TrackFragmentHeaderBox }.first
        let tfdt = traf.children.compactMap { $0 as? TrackFragmentDecodeTimeBox }.first
        let trun = traf.children.compactMap { $0 as? TrackRunBox }.first
        #expect(tfhd?.trackID == 1)
        #expect(tfdt?.baseMediaDecodeTime == 90_000)
        #expect(trun != nil)
    }

    @Test
    func uniformDurationHoistedToTfhd() throws {
        let (moof, invariance) = FragmentTreeBuilder.makeMovieFragment(
            trackID: 1,
            sequenceNumber: 1,
            baseMediaDecodeTime: 0,
            samples: makeSamples(count: 5),
            dataOffsetFromMoof: 100
        )
        #expect(invariance.defaultSampleDuration == 3000)
        let traf = try #require(moof.children.compactMap { $0 as? TrackFragmentBox }.first)
        let tfhd = try #require(traf.children.compactMap { $0 as? TrackFragmentHeaderBox }.first)
        #expect(tfhd.defaultSampleDuration == 3000)
    }

    @Test
    func firstSampleFlagsPresentWhenLeadIsSync() async throws {
        let (moof, _) = FragmentTreeBuilder.makeMovieFragment(
            trackID: 1,
            sequenceNumber: 1,
            baseMediaDecodeTime: 0,
            samples: makeSamples(count: 5, syncFirst: true),
            dataOffsetFromMoof: 100
        )
        let traf = try #require(moof.children.compactMap { $0 as? TrackFragmentBox }.first)
        let trun = try #require(traf.children.compactMap { $0 as? TrackRunBox }.first)
        #expect(trun.firstSampleFlags == SampleFlags.syncSample.rawValue)
    }

    @Test
    func moofRoundTripsThroughRegistry() async throws {
        let (moof, _) = FragmentTreeBuilder.makeMovieFragment(
            trackID: 1,
            sequenceNumber: 7,
            baseMediaDecodeTime: 270_000,
            samples: makeSamples(count: 3),
            dataOffsetFromMoof: 100
        )
        var writer = BinaryWriter()
        moof.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentBox)
        let mfhd = parsed.children.compactMap { $0 as? MovieFragmentHeaderBox }.first
        #expect(mfhd?.sequenceNumber == 7)
    }
}
