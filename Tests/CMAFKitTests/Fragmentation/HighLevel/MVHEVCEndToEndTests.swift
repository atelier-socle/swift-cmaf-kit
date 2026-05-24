// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MVHEVCEndToEndTests
//
// End-to-end integration test for the MV-HEVC stack: configuration →
// sample-entry composition → BoxRegistry round-trip → packager
// per-layer byte production.
//
// The synthetic-fixture portion of this test runs on every platform —
// it depends only on CMAFKit's own bitstream primitives.
//
// The full AVAssetWriter → ffprobe validation pipeline is gated by
// `canImport(AVFoundation)` AND `os(macOS) && !targetEnvironment(macCatalyst)`,
// because ffprobe is only available on the macOS runner image and
// AVAssetWriter is an Apple-platforms-only API. When the macOS path runs
// but ffprobe is absent, the test records a known issue rather than
// failing the build (the established 0.1.0 pattern for runtime-dependent
// validation hooks). A real AVAssetWriter-produced MV-HEVC fixture is
// deferred to the dedicated real-fixtures session per
// `Scripts/generate-mvhevc-fixture.swift`.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MV-HEVC end-to-end")
struct MVHEVCEndToEndTests {

    // MARK: - Fixtures (cross-platform)

    private static func twoLayerConfig() -> MultiLayerHEVCConfiguration {
        MultiLayerHEVCConfiguration(
            baseLayer: MultiLayerHEVCConfigurationTests.minimalHEVCRecord(),
            extensionLayer: MultiLayerHEVCConfigurationTests.minimalHEVCRecord(),
            layerIDs: [0, 1],
            temporalIDs: [0, 0],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: []),
                LayerDependency(layerID: 1, dependsOnLayerIDs: [0])
            ],
            viewIDs: [0, 1],
            outputLayerSetIDs: [0]
        )
    }

    private static func makeSampleEntry() -> MVHEVCSampleEntry {
        MVHEVCSampleEntry(
            visualFields: VisualSampleEntryFields(width: 4096, height: 2160),
            hvcCBase: MultiLayerHEVCConfigurationTests.minimalHEVCRecord(),
            hvcCExtension: MultiLayerHEVCConfigurationTests.minimalHEVCRecord(),
            vexu: ViewExtendedUsageBox(viewIdentifier: 0, usageFlags: 0x01),
            stri: StereoInformationBox(
                stereoArrangement: .stereoLayered,
                interaxialDistanceMillimeters: 63.0
            ),
            hero: HeroEyeInformationBox(heroEye: .leftEye),
            multiLayerConfiguration: twoLayerConfig()
        )
    }

    private static func nalUnit(layerID: UInt8, payload: [UInt8] = [0xAA, 0xBB]) -> Data {
        let byte0 = ((1 & 0x3F) << 1) | ((layerID >> 5) & 0x01)
        let byte1 = ((layerID & 0x1F) << 3) | 0x01
        return Data([byte0, byte1] + payload)
    }

    // MARK: - Cross-platform end-to-end

    /// Round-trip the full ``MVHEVCSampleEntry`` through the
    /// ``BoxRegistry`` and confirm every field survives.
    @Test
    func sampleEntryRoundTripThroughBoxRegistry() async throws {
        let original = Self.makeSampleEntry()
        var writer = BinaryWriter()
        original.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry)
        let recovered = try #require(parsed.first as? MVHEVCSampleEntry)
        #expect(recovered == original)
        #expect(recovered.visualFields.width == 4096)
        #expect(recovered.visualFields.height == 2160)
        #expect(recovered.vexu.viewIdentifier == 0)
        #expect(recovered.stri?.stereoArrangement == .stereoLayered)
        #expect(recovered.hero?.heroEye == .leftEye)
        #expect(recovered.multiLayerConfiguration?.layerIDs == [0, 1])
    }

    /// Drive the ``MVHEVCPackager`` with a 2-layer access unit and
    /// confirm the per-layer byte output is structurally correct.
    @Test
    func packagerProducesLengthPrefixedPerLayerBytes() async throws {
        let packager = MVHEVCPackager(
            configuration: Self.twoLayerConfig(),
            heroEye: .leftEye
        )
        let nal0 = Self.nalUnit(layerID: 0, payload: [0x11, 0x22, 0x33, 0x44])
        let nal1 = Self.nalUnit(layerID: 1, payload: [0x55, 0x66, 0x77, 0x88])
        let outputs = try await packager.processAccessUnit(
            [nal0, nal1],
            timing: CMAFSampleTiming(decodeTime: 0, durationInTimescale: 3_000),
            format: .ebspWithPrefix
        )
        #expect(outputs.count == 2)

        let layer0Output = try #require(outputs.first(where: { $0.layerID == 0 }))
        let layer1Output = try #require(outputs.first(where: { $0.layerID == 1 }))

        // Hero layer marking propagated.
        #expect(layer0Output.isHeroLayer == true)
        #expect(layer1Output.isHeroLayer == false)

        // Each NAL is 6 bytes (2-byte header + 4-byte payload). The
        // packager prepends a 4-byte length prefix (configuration
        // lengthSize = .fourBytes → 4 bytes).
        #expect(layer0Output.bytes.count == 4 + 6)
        #expect(layer1Output.bytes.count == 4 + 6)

        // Timing is forwarded verbatim.
        #expect(layer0Output.timing.decodeTime == 0)
        #expect(layer0Output.timing.durationInTimescale == 3_000)

        await packager.stop()
    }

    /// Confirm the packager + sample entry compose into a coherent
    /// `hvc2`-style track configuration that the
    /// ``SampleEntryComposer`` accepts.
    @Test
    func composerAcceptsHvc2TrackBackedByPackagerConfig() throws {
        let mvConfig = Self.twoLayerConfig()
        let track = CMAFTrackConfiguration(
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
                    configuration: mvConfig,
                    viewExtendedUsage: ViewExtendedUsageBox(
                        viewIdentifier: 0, usageFlags: 0x01
                    ),
                    stereoInformation: StereoInformationBox(
                        stereoArrangement: .stereoLayered
                    ),
                    heroEye: HeroEyeInformationBox(heroEye: .leftEye)
                ),
                frameRate: .init(numerator: 30, denominator: 1)
            )
        )
        let entry = try SampleEntryComposer.makeVideoSampleEntry(configuration: track)
        let mvhevc = try #require(entry as? MVHEVCSampleEntry)
        #expect(mvhevc.stri?.stereoArrangement == .stereoLayered)
        #expect(mvhevc.hero?.heroEye == .leftEye)
        #expect(mvhevc.multiLayerConfiguration != nil)
    }

    // MARK: - macOS-native ffprobe validation hook

    #if canImport(AVFoundation) && os(macOS) && !targetEnvironment(macCatalyst)
        /// Forward-looking ffprobe validation hook.
        ///
        /// When (a) AVFoundation is available, (b) we are on macOS native,
        /// and (c) `ffprobe` is reachable on `PATH`, this test would run
        /// an AVAssetWriter-produced MV-HEVC fixture through the packager
        /// + writer pipeline and assert ffprobe reports two HEVC streams.
        ///
        /// The AVAssetWriter HEVC stereo fixture itself is deferred to the
        /// dedicated real-fixtures session (see
        /// `Scripts/generate-mvhevc-fixture.swift`), so for now this test
        /// records a known issue when ffprobe is present and is otherwise a
        /// silent no-op.
        @Test
        func ffprobeValidationDeferredUntilRealFixtureSession() throws {
            let ffprobePath = Self.locateFfprobe()
            if ffprobePath == nil {
                // No ffprobe — silent skip; the test is informational.
                return
            }
            withKnownIssue(
                "MV-HEVC ffprobe E2E is deferred to the real-fixtures session (generate-mvhevc-fixture.swift stub)."
            ) {
                // Placeholder for the real AVAssetWriter → fMP4 → ffprobe
                // validation. The session that lands the real fixture
                // generator removes withKnownIssue and asserts on the
                // ffprobe -show_streams output.
                #expect(Bool(false))
            }
        }

        /// Locate `ffprobe` on the runner's PATH; returns nil if not present.
        private static func locateFfprobe() -> String? {
            let candidates = [
                "/opt/homebrew/bin/ffprobe",
                "/usr/local/bin/ffprobe",
                "/usr/bin/ffprobe"
            ]
            for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
            return nil
        }
    #endif
}
