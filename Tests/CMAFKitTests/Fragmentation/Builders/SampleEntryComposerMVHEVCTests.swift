// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

/// Tests for the Session 3 enum extensions and `SampleEntryComposer`
/// `.hvc2` dispatch:
///
/// - `EncodedCodec.mvHEVC` / `.mvHEVC10` cases construct + hash.
/// - `VideoCodec.hvc2` is in `CaseIterable.allCases` and its
///   `sampleEntryFourCC` is `"hvc2"`.
/// - `VideoCodecConfiguration.mvHEVC(...)` constructs and `boxType` is
///   `"hvcC"` (the base-layer primary box).
/// - `SampleEntryComposer.makeVideoSampleEntry` dispatches `.hvc2` to
///   `MVHEVCSampleEntry` and throws on codec / config mismatch.
/// - `BoxRegistry.default` resolves `hvc2`.
@Suite("MV-HEVC enum + dispatch wiring")
struct SampleEntryComposerMVHEVCTests {

    // MARK: - Fixtures

    private static func makeMVConfig() -> MultiLayerHEVCConfiguration {
        MultiLayerHEVCConfiguration(
            baseLayer: MultiLayerHEVCConfigurationTests.minimalHEVCRecord(),
            extensionLayer: MultiLayerHEVCConfigurationTests.minimalHEVCRecord(),
            layerIDs: [0, 1],
            temporalIDs: [0, 0],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: []),
                LayerDependency(layerID: 1, dependsOnLayerIDs: [0])
            ],
            viewIDs: [0, 1]
        )
    }

    private static func makeVexu() -> ViewExtendedUsageBox {
        ViewExtendedUsageBox(viewIdentifier: 0, usageFlags: 0x01)
    }

    private static func makeHvc2Track() -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 4096,
                height: 2160,
                codec: .hvc2,
                codecConfiguration: .mvHEVC(
                    configuration: makeMVConfig(),
                    viewExtendedUsage: makeVexu(),
                    stereoInformation: nil,
                    heroEye: nil
                ),
                frameRate: .init(numerator: 30, denominator: 1)
            )
        )
    }

    // MARK: - EncodedCodec extensions

    @Test
    func encodedCodecMVHEVCConstructsAndEquates() {
        let codec1 = EncodedCodec.mvHEVC
        let codec2 = EncodedCodec.mvHEVC
        #expect(codec1 == codec2)
        #expect(EncodedCodec.mvHEVC != EncodedCodec.mvHEVC10)
        #expect(EncodedCodec.mvHEVC != EncodedCodec.h265MultiLayer)
    }

    @Test
    func encodedCodecMVHEVC10ConstructsAndHashes() {
        var hasher = Hasher()
        EncodedCodec.mvHEVC10.hash(into: &hasher)
        _ = hasher.finalize()  // smoke: no crash
        #expect(EncodedCodec.mvHEVC10 == EncodedCodec.mvHEVC10)
    }

    // MARK: - VideoCodec extension

    @Test
    func videoCodecHvc2IsCaseIterable() {
        #expect(VideoCodec.allCases.contains(.hvc2))
    }

    @Test
    func videoCodecHvc2SampleEntryFourCCIsHvc2() {
        #expect(VideoCodec.hvc2.sampleEntryFourCC == "hvc2")
    }

    // MARK: - VideoCodecConfiguration extension

    @Test
    func videoCodecConfigurationMVHEVCConstructs() {
        let config = VideoCodecConfiguration.mvHEVC(
            configuration: Self.makeMVConfig(),
            viewExtendedUsage: Self.makeVexu(),
            stereoInformation: nil,
            heroEye: nil
        )
        // boxType for mvHEVC returns hvcC (the base-layer primary box)
        #expect(config.boxType == "hvcC")
    }

    // MARK: - SampleEntryComposer dispatch

    @Test
    func composerDispatchesHvc2ToMVHEVCSampleEntry() throws {
        let track = Self.makeHvc2Track()
        let entry = try SampleEntryComposer.makeVideoSampleEntry(configuration: track)
        #expect(entry is MVHEVCSampleEntry)
        let mvhevc = try #require(entry as? MVHEVCSampleEntry)
        #expect(mvhevc.visualFields.width == 4096)
        #expect(mvhevc.visualFields.height == 2160)
    }

    @Test
    func composerThrowsOnHvc2WithNonMVHEVCConfig() throws {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920,
                height: 1080,
                codec: .hvc2,
                // Wrong arm — .hvc2 expects .mvHEVC, supply .hevc instead
                codecConfiguration: .hevc(
                    MultiLayerHEVCConfigurationTests.minimalHEVCRecord()
                ),
                frameRate: .init(numerator: 30, denominator: 1)
            )
        )
        #expect(throws: CMAFWriterError.self) {
            _ = try SampleEntryComposer.makeVideoSampleEntry(configuration: track)
        }
    }

    // MARK: - BoxRegistry

    @Test
    func boxRegistryResolvesHvc2() async throws {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "hvc2")
        #expect(parser != nil)
    }
}
