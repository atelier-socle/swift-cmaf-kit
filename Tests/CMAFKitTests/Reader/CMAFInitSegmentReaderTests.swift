// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFInitSegmentReader — round-trip with writer")
struct CMAFInitSegmentReaderTests {

    @Test
    func videoOnlyInitSegmentRoundTrip() async throws {
        let track = WriterFixtures.videoConfig()
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let recovered = reader.tracks()
        #expect(recovered.count == 1)
        #expect(recovered[0].trackID == track.trackID)
        #expect(recovered[0].kind == .video)
        #expect(recovered[0].videoFields?.codec == .avc1)
        #expect(reader.majorBrand() == "cmfc")
    }

    @Test
    func audioOnlyInitSegmentRoundTrip() async throws {
        let track = WriterFixtures.audioConfig()
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let recovered = reader.tracks()
        #expect(recovered.count == 1)
        #expect(recovered[0].kind == .audio)
        #expect(recovered[0].audioFields?.codec == .mp4a)
    }

    @Test
    func twoTrackInitSegmentRoundTrip() async throws {
        let video = WriterFixtures.videoConfig(trackID: 1)
        let audio = WriterFixtures.audioConfig(trackID: 2)
        let writer = try CMAFInitSegmentWriter(configurations: [video, audio])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let recovered = reader.tracks()
        #expect(recovered.count == 2)
        let kinds = Set(recovered.map { $0.kind })
        #expect(kinds == [.video, .audio])
    }

    @Test
    func cencEncryptedTrackRoundTrip() async throws {
        let track = WriterFixtures.videoConfig(encrypted: WriterFixtures.cencParameters())
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let recovered = try #require(reader.tracks().first)
        #expect(recovered.encryptionParameters?.scheme == .cenc)
        #expect(
            recovered.encryptionParameters?.defaultKID.rawBytes
                == WriterFixtures.makeKID().rawBytes)
    }

    @Test
    func cbcsEncryptedTrackRoundTrip() async throws {
        let params = try WriterFixtures.cbcsParameters()
        let track = WriterFixtures.videoConfig(encrypted: params)
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let recovered = try #require(reader.tracks().first)
        #expect(recovered.encryptionParameters?.scheme == .cbcs)
        #expect(recovered.encryptionParameters?.defaultConstantIV != nil)
    }

    @Test
    func psshBoxesRecovered() async throws {
        let widevine = try #require(
            UUID(uuidString: "EDEF8BA9-79D6-4ACE-A3C8-27DCD51D21ED")
        )
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1, systemID: widevine, keyIdentifiers: [], data: Data([0xCA])
        )
        let enc = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .eight,
            psshBoxes: [pssh]
        )
        let track = WriterFixtures.videoConfig(encrypted: enc)
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let recoveredPSSHs = reader.protectionSystemSpecificHeaders()
        #expect(recoveredPSSHs.count == 1)
        #expect(recoveredPSSHs[0].systemID == widevine)
    }

    @Test
    func movieTimescaleRecovered() async throws {
        let track = WriterFixtures.videoConfig()
        let writer = try CMAFInitSegmentWriter(
            configurations: [track],
            movieTimescale: 600
        )
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        #expect(reader.movieTimescale() == 600)
    }

    @Test
    func dashProfileRoundTrip() async throws {
        let track = WriterFixtures.videoConfig(profile: .dash)
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        #expect(reader.majorBrand() == "cmfd")
        #expect(reader.tracks().first?.profile == .dash)
    }

    @Test
    func lowLatencyProfileRoundTrip() async throws {
        let track = WriterFixtures.videoConfig(profile: .lowLatency)
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        #expect(reader.majorBrand() == "cmfl")
        #expect(reader.tracks().first?.profile == .lowLatency)
    }

    @Test
    func compatibleBrandsRoundTrip() async throws {
        let track = WriterFixtures.videoConfig(encrypted: WriterFixtures.cencParameters())
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let brands = reader.compatibleBrands()
        #expect(brands.contains("iso6"))
        #expect(brands.contains("cmfc"))
        #expect(brands.contains("avc1"))
        #expect(brands.contains("iso7"))
    }

    @Test
    func missingMoovThrows() async {
        let ftyp = FileTypeBox(
            majorBrand: "cmfc",
            minorVersion: 0,
            compatibleBrands: ["iso6", "cmfc"]
        )
        var writer = BinaryWriter()
        ftyp.encode(to: &writer)
        await #expect(throws: CMAFReaderError.self) {
            _ = try await CMAFInitSegmentReader(bytes: writer.data)
        }
    }
}
