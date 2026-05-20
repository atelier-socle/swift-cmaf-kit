// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFProfileConformance — brand emission per profile")
struct CMAFProfileConformanceTests {

    private func emitAndParseFtyp(profile: CMAFProfile) async throws -> FileTypeBox {
        let track = WriterFixtures.videoConfig(profile: profile)
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        return try #require(boxes.first as? FileTypeBox)
    }

    @Test
    func basicProfileEmitsCmfc() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .basic)
        #expect(ftyp.majorBrand == "cmfc")
    }

    @Test
    func multiStreamProfileEmitsCmf2() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .multiStream)
        #expect(ftyp.majorBrand == "cmf2")
    }

    @Test
    func fragmentedProfileEmitsCmff() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .fragmented)
        #expect(ftyp.majorBrand == "cmff")
    }

    @Test
    func lowLatencyProfileEmitsCmfl() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .lowLatency)
        #expect(ftyp.majorBrand == "cmfl")
    }

    @Test
    func segmentedProfileEmitsCmfs() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .segmented)
        #expect(ftyp.majorBrand == "cmfs")
    }

    @Test
    func dashProfileEmitsCmfd() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .dash)
        #expect(ftyp.majorBrand == "cmfd")
    }

    @Test
    func hlsProfileEmitsCmfh() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .hls)
        #expect(ftyp.majorBrand == "cmfh")
    }

    @Test
    func everyProfileIncludesIso6AndCmfc() async throws {
        for profile in CMAFProfile.allCases {
            let ftyp = try await emitAndParseFtyp(profile: profile)
            #expect(ftyp.compatibleBrands.contains("iso6"), "missing iso6 for \(profile)")
            #expect(ftyp.compatibleBrands.contains("cmfc"), "missing cmfc for \(profile)")
        }
    }

    @Test
    func basicProfileCompatibleBrandsExact() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .basic)
        #expect(ftyp.compatibleBrands.contains("iso6"))
        #expect(ftyp.compatibleBrands.contains("cmfc"))
        #expect(ftyp.compatibleBrands.contains("avc1"))
    }

    @Test
    func dashProfileCompatibleBrandsIncludeDash() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .dash)
        #expect(ftyp.compatibleBrands.contains("dash"))
        #expect(ftyp.compatibleBrands.contains("msdh"))
        #expect(ftyp.compatibleBrands.contains("cmfd"))
    }

    @Test
    func hlsProfileCompatibleBrandsIncludeCmfh() async throws {
        let ftyp = try await emitAndParseFtyp(profile: .hls)
        #expect(ftyp.compatibleBrands.contains("cmfh"))
    }

    @Test
    func brandsAreDeterministic() async throws {
        let track = WriterFixtures.videoConfig()
        let writer1 = try CMAFInitSegmentWriter(configurations: [track])
        let writer2 = try CMAFInitSegmentWriter(configurations: [track])
        #expect(try writer1.emit() == writer2.emit())
    }

    @Test
    func profileMismatchAcrossTracksRejected() {
        #expect(throws: CMAFWriterError.self) {
            _ = try CMAFInitSegmentWriter(configurations: [
                WriterFixtures.videoConfig(trackID: 1, profile: .basic),
                WriterFixtures.audioConfig(trackID: 2, profile: .hls)
            ])
        }
    }

    @Test
    func encryptedTrackAddsIso7Brand() async throws {
        let track = WriterFixtures.videoConfig(encrypted: WriterFixtures.cencParameters())
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let ftyp = try #require(boxes.first as? FileTypeBox)
        #expect(ftyp.compatibleBrands.contains("iso7"))
    }

    @Test
    func multiTrackAddsCmf2Brand() async throws {
        let writer = try CMAFInitSegmentWriter(configurations: [
            WriterFixtures.audioConfig(trackID: 1),
            WriterFixtures.audioConfig(trackID: 2)
        ])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let ftyp = try #require(boxes.first as? FileTypeBox)
        #expect(ftyp.compatibleBrands.contains("cmf2"))
    }
}
