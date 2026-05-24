// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

// MARK: - Shared fixtures

/// File-private fixtures shared across the 3 ``MVHEVCPackager`` test
/// suites. Extracted to keep each suite body within SwiftLint's
/// `type_body_length` budget.
private enum MVHEVCPackagerFixtures {

    static func record() -> HEVCDecoderConfigurationRecord {
        MultiLayerHEVCConfigurationTests.minimalHEVCRecord()
    }

    static func twoLayerConfig() -> MultiLayerHEVCConfiguration {
        MultiLayerHEVCConfiguration(
            baseLayer: record(),
            extensionLayer: record(),
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

    /// Synthesise a NAL unit with the given `nuh_layer_id` and a few
    /// payload bytes. NAL header bit layout per ITU-T H.265 §F.7.3.1.2:
    ///   byte0: forbidden(1) | nal_unit_type(6) | layer_id_high(1)
    ///   byte1: layer_id_low(5) | temporal_id_plus1(3)
    static func nalUnit(layerID: UInt8, nalType: UInt8 = 1, payload: [UInt8] = [0xAA, 0xBB]) -> Data {
        let byte0 = ((nalType & 0x3F) << 1) | ((layerID >> 5) & 0x01)
        let byte1 = ((layerID & 0x1F) << 3) | 0x01  // temporal_id_plus1 = 1
        var bytes = Data([byte0, byte1])
        bytes.append(contentsOf: payload)
        return bytes
    }

    static func timing(decodeTime: UInt64 = 0) -> CMAFSampleTiming {
        CMAFSampleTiming(decodeTime: decodeTime, durationInTimescale: 3_000)
    }
}

// MARK: - Lifecycle suite

@Suite("MVHEVCPackager — Lifecycle")
struct MVHEVCPackagerLifecycleTests {

    @Test
    func initWithTwoLayerConfigurationSucceeds() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let stopped = await packager.isStopped
        #expect(stopped == false)
        await packager.stop()
    }

    @Test
    func stopTransitionsToStoppedState() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        await packager.stop()
        let stopped = await packager.isStopped
        #expect(stopped == true)
    }

    @Test
    func processAccessUnitAfterStopThrows() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        await packager.stop()
        let nal = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        await #expect(throws: MVHEVCPackagerError.alreadyStopped) {
            _ = try await packager.processAccessUnit(
                [nal],
                timing: MVHEVCPackagerFixtures.timing(),
                format: .ebspWithPrefix
            )
        }
    }

    @Test
    func stopIsIdempotent() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        await packager.stop()
        await packager.stop()  // no crash, no error
        let stopped = await packager.isStopped
        #expect(stopped == true)
    }

    @Test
    func resetDoesNotStopActor() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        await packager.reset()
        let stopped = await packager.isStopped
        #expect(stopped == false)
        // processAccessUnit still works after reset
        let nal = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let outputs = try await packager.processAccessUnit(
            [nal],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        #expect(outputs.count == 1)
        await packager.stop()
    }

    @Test
    func heroLayerIDResolvedFromLeftEye() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig(),
            heroEye: .leftEye
        )
        #expect(packager.heroLayerID == 0)
        await packager.stop()
    }

    @Test
    func heroLayerIDResolvedFromRightEye() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig(),
            heroEye: .rightEye
        )
        #expect(packager.heroLayerID == 1)
        await packager.stop()
    }

    @Test
    func heroLayerIDIsNilWithNoneEye() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig(),
            heroEye: HeroEyeInformationBox.HeroEye.none
        )
        #expect(packager.heroLayerID == nil)
        await packager.stop()
    }

    @Test
    func heroLayerIDIsNilWithoutHint() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        #expect(packager.heroLayerID == nil)
        await packager.stop()
    }
}

// MARK: - Processing suite

@Suite("MVHEVCPackager — Processing")
struct MVHEVCPackagerProcessingTests {

    @Test
    func processSingleAU2LayersOneNalEach() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        defer { Task { await packager.stop() } }
        let nal0 = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let nal1 = MVHEVCPackagerFixtures.nalUnit(layerID: 1)
        let outputs = try await packager.processAccessUnit(
            [nal0, nal1],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        #expect(outputs.count == 2)
        #expect(outputs[0].layerID == 0)
        #expect(outputs[1].layerID == 1)
        await packager.stop()
    }

    @Test
    func processAUWithMultiNalPerLayer() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let layer0NALs = (0..<3).map {
            MVHEVCPackagerFixtures.nalUnit(layerID: 0, payload: [UInt8($0), 0x42])
        }
        let layer1NALs = (0..<2).map {
            MVHEVCPackagerFixtures.nalUnit(layerID: 1, payload: [UInt8($0), 0x99])
        }
        let interleaved = [layer0NALs[0], layer1NALs[0], layer0NALs[1], layer0NALs[2], layer1NALs[1]]
        let outputs = try await packager.processAccessUnit(
            interleaved,
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        #expect(outputs.count == 2)
        // Layer 0 should have 3 NAL units concatenated; layer 1 should have 2.
        // Each NAL is 4 bytes (2-byte header + 2-byte payload) + 4-byte length prefix.
        #expect(outputs[0].bytes.count == 3 * (4 + 4))
        #expect(outputs[1].bytes.count == 2 * (4 + 4))
        await packager.stop()
    }

    @Test
    func processAUWithOnlyBaseLayerOmitsExtension() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let outputs = try await packager.processAccessUnit(
            [nal],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        #expect(outputs.count == 1)
        #expect(outputs[0].layerID == 0)
        await packager.stop()
    }

    @Test
    func layerIDExtractionCorrectness() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal0 = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let nal1 = MVHEVCPackagerFixtures.nalUnit(layerID: 1)
        let outputs = try await packager.processAccessUnit(
            [nal0, nal1],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        #expect(outputs.map(\.layerID) == [0, 1])
        await packager.stop()
    }

    @Test
    func isHeroLayerLeftEyeMarksBaseLayer() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig(),
            heroEye: .leftEye
        )
        let nal0 = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let nal1 = MVHEVCPackagerFixtures.nalUnit(layerID: 1)
        let outputs = try await packager.processAccessUnit(
            [nal0, nal1],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        #expect(outputs.first(where: { $0.layerID == 0 })?.isHeroLayer == true)
        #expect(outputs.first(where: { $0.layerID == 1 })?.isHeroLayer == false)
        await packager.stop()
    }

    @Test
    func isHeroLayerRightEyeMarksExtensionLayer() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig(),
            heroEye: .rightEye
        )
        let nal0 = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let nal1 = MVHEVCPackagerFixtures.nalUnit(layerID: 1)
        let outputs = try await packager.processAccessUnit(
            [nal0, nal1],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        #expect(outputs.first(where: { $0.layerID == 0 })?.isHeroLayer == false)
        #expect(outputs.first(where: { $0.layerID == 1 })?.isHeroLayer == true)
        await packager.stop()
    }

    @Test
    func isHeroLayerAlwaysFalseWithoutHint() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal0 = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let nal1 = MVHEVCPackagerFixtures.nalUnit(layerID: 1)
        let outputs = try await packager.processAccessUnit(
            [nal0, nal1],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        #expect(outputs.allSatisfy { $0.isHeroLayer == false })
        await packager.stop()
    }

    @Test
    func lengthPrefixingMatchesConfigurationLengthSize() async throws {
        // Default lengthSize = .fourBytes → 4-byte prefix before each NAL
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal = MVHEVCPackagerFixtures.nalUnit(layerID: 0, payload: [0xCA, 0xFE, 0xBA, 0xBE])
        // NAL = 2-byte header + 4-byte payload = 6 bytes
        let outputs = try await packager.processAccessUnit(
            [nal],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        let bytes = outputs[0].bytes
        // 4-byte prefix should encode the value 6 big-endian
        #expect(bytes.count == 4 + 6)
        #expect(bytes[bytes.startIndex] == 0x00)
        #expect(bytes[bytes.startIndex + 1] == 0x00)
        #expect(bytes[bytes.startIndex + 2] == 0x00)
        #expect(bytes[bytes.startIndex + 3] == 0x06)
        await packager.stop()
    }

    @Test
    func unexpectedLayerIDThrows() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        // Layer 5 is not in [0, 1] → throws unexpectedLayerID
        let nal = MVHEVCPackagerFixtures.nalUnit(layerID: 5)
        await #expect(throws: MVHEVCPackagerError.unexpectedLayerID(5)) {
            _ = try await packager.processAccessUnit(
                [nal],
                timing: MVHEVCPackagerFixtures.timing(),
                format: .ebspWithPrefix
            )
        }
        await packager.stop()
    }

    @Test
    func truncatedNALThrows() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let truncated = Data([0x40])  // 1 byte — needs ≥ 2 for header
        await #expect(throws: MVHEVCPackagerError.self) {
            _ = try await packager.processAccessUnit(
                [truncated],
                timing: MVHEVCPackagerFixtures.timing(),
                format: .ebspWithPrefix
            )
        }
        await packager.stop()
    }

    @Test
    func processRawRBSPFormat() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let outputs = try await packager.processAccessUnit(
            [nal],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .rawRBSP
        )
        #expect(outputs.count == 1)
        await packager.stop()
    }

    @Test
    func processLengthPrefixed4ByteFormat() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let inner = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        var prefixed = Data()
        let length = UInt32(inner.count).bigEndian
        withUnsafeBytes(of: length) { prefixed.append(contentsOf: $0) }
        prefixed.append(inner)
        let outputs = try await packager.processAccessUnit(
            [prefixed],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .lengthPrefixed(prefixBytes: 4)
        )
        #expect(outputs.count == 1)
        await packager.stop()
    }

    @Test
    func processLengthPrefixed1ByteFormat() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let inner = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        var prefixed = Data([UInt8(inner.count)])
        prefixed.append(inner)
        let outputs = try await packager.processAccessUnit(
            [prefixed],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .lengthPrefixed(prefixBytes: 1)
        )
        #expect(outputs.count == 1)
        await packager.stop()
    }

    @Test
    func processAnnexB3ByteStartCode() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal0 = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let nal1 = MVHEVCPackagerFixtures.nalUnit(layerID: 1)
        var stream = Data()
        for nal in [nal0, nal1] {
            stream.append(contentsOf: [0x00, 0x00, 0x01])
            stream.append(nal)
        }
        let outputs = try await packager.processAccessUnit(
            [stream],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .annexB
        )
        #expect(outputs.count == 2)
        await packager.stop()
    }

    @Test
    func processAnnexB4ByteStartCode() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal0 = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let nal1 = MVHEVCPackagerFixtures.nalUnit(layerID: 1)
        var stream = Data()
        for nal in [nal0, nal1] {
            stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
            stream.append(nal)
        }
        let outputs = try await packager.processAccessUnit(
            [stream],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .annexB
        )
        #expect(outputs.count == 2)
        await packager.stop()
    }

    @Test
    func invalidLengthPrefixSizeThrows() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        await #expect(throws: MVHEVCPackagerError.self) {
            _ = try await packager.processAccessUnit(
                [nal],
                timing: MVHEVCPackagerFixtures.timing(),
                format: .lengthPrefixed(prefixBytes: 3)
            )
        }
        await packager.stop()
    }

    @Test
    func annexBWithoutStartCodeThrows() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        await #expect(throws: MVHEVCPackagerError.self) {
            _ = try await packager.processAccessUnit(
                [Data([0xAA, 0xBB, 0xCC])],
                timing: MVHEVCPackagerFixtures.timing(),
                format: .annexB
            )
        }
        await packager.stop()
    }

    @Test
    func truncatedLengthPrefixThrows() async {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        await #expect(throws: MVHEVCPackagerError.self) {
            _ = try await packager.processAccessUnit(
                [Data([0x00, 0x01])],
                timing: MVHEVCPackagerFixtures.timing(),
                format: .lengthPrefixed(prefixBytes: 4)
            )
        }
        await packager.stop()
    }

    @Test
    func lengthPrefixedNALPreservesContent() async throws {
        // Verify the length prefix encodes the actual NAL byte count
        // and the NAL bytes are appended verbatim.
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal = MVHEVCPackagerFixtures.nalUnit(
            layerID: 0, payload: [0xCA, 0xFE, 0xBA, 0xBE]
        )
        let outputs = try await packager.processAccessUnit(
            [nal],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        let bytes = outputs[0].bytes
        let nalStart = bytes.startIndex.advanced(by: 4)
        #expect(bytes.subdata(in: nalStart..<bytes.endIndex) == nal)
        await packager.stop()
    }
}

// MARK: - Multi-AU suite

@Suite("MVHEVCPackager — Multi-AU")
struct MVHEVCPackagerMultiAUTests {

    @Test
    func sequentialAUsWithMonotonicDecodeTime() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        let outputs1 = try await packager.processAccessUnit(
            [nal],
            timing: MVHEVCPackagerFixtures.timing(decodeTime: 0),
            format: .ebspWithPrefix
        )
        let outputs2 = try await packager.processAccessUnit(
            [nal],
            timing: MVHEVCPackagerFixtures.timing(decodeTime: 3_000),
            format: .ebspWithPrefix
        )
        #expect(outputs1[0].timing.decodeTime == 0)
        #expect(outputs2[0].timing.decodeTime == 3_000)
        await packager.stop()
    }

    @Test
    func resetBetweenAUsAllowsNewProcessing() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal0 = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        _ = try await packager.processAccessUnit(
            [nal0],
            timing: MVHEVCPackagerFixtures.timing(),
            format: .ebspWithPrefix
        )
        await packager.reset()
        // After reset the packager continues to accept access units
        let outputs = try await packager.processAccessUnit(
            [nal0],
            timing: MVHEVCPackagerFixtures.timing(decodeTime: 90_000),
            format: .ebspWithPrefix
        )
        #expect(outputs.count == 1)
        #expect(outputs[0].timing.decodeTime == 90_000)
        await packager.stop()
    }

    @Test
    func multiAUWithVaryingNALCountPerLayer() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        // AU 1 — base layer only (1 NAL)
        let outputs1 = try await packager.processAccessUnit(
            [MVHEVCPackagerFixtures.nalUnit(layerID: 0)],
            timing: MVHEVCPackagerFixtures.timing(decodeTime: 0),
            format: .ebspWithPrefix
        )
        #expect(outputs1.count == 1)
        // AU 2 — both layers (3 + 2 NALs)
        let nalsAU2: [Data] = [
            MVHEVCPackagerFixtures.nalUnit(layerID: 0, payload: [0x01]),
            MVHEVCPackagerFixtures.nalUnit(layerID: 0, payload: [0x02]),
            MVHEVCPackagerFixtures.nalUnit(layerID: 1, payload: [0x03]),
            MVHEVCPackagerFixtures.nalUnit(layerID: 0, payload: [0x04]),
            MVHEVCPackagerFixtures.nalUnit(layerID: 1, payload: [0x05])
        ]
        let outputs2 = try await packager.processAccessUnit(
            nalsAU2,
            timing: MVHEVCPackagerFixtures.timing(decodeTime: 3_000),
            format: .ebspWithPrefix
        )
        #expect(outputs2.count == 2)
        await packager.stop()
    }

    @Test
    func finalStopAfterMultipleAUsCompletesCleanly() async throws {
        let packager = MVHEVCPackager(
            configuration: MVHEVCPackagerFixtures.twoLayerConfig()
        )
        let nal = MVHEVCPackagerFixtures.nalUnit(layerID: 0)
        for i in 0..<5 {
            _ = try await packager.processAccessUnit(
                [nal],
                timing: MVHEVCPackagerFixtures.timing(decodeTime: UInt64(i * 3_000)),
                format: .ebspWithPrefix
            )
        }
        await packager.stop()
        let stopped = await packager.isStopped
        #expect(stopped == true)
    }
}
