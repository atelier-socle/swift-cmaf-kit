// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFInitSegmentWriter — edit list")
struct CMAFInitSegmentWriterEditListTests {

    @Test
    func opusPrimingAutoEmitsEditList() async throws {
        let priming = AudioPriming(preSkip: 312)
        let writer = try CMAFInitSegmentWriter(
            configurations: [
                WriterFixtures.audioConfig(priming: priming)
            ]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let editBox = trak.children
            .compactMap { $0 as? EditBox }
            .first
        let elst = editBox?.children.compactMap { $0 as? EditListBox }.first
        let firstEntry = elst?.table.first
        #expect(firstEntry?.mediaTime == 312)
    }

    @Test
    func aacHeAACPrimingAutoEmits() async throws {
        let priming = AudioPriming(preSkip: 2112)
        let writer = try CMAFInitSegmentWriter(
            configurations: [
                WriterFixtures.audioConfig(priming: priming)
            ]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let editBox = trak.children
            .compactMap { $0 as? EditBox }
            .first
        let elst = editBox?.children.compactMap { $0 as? EditListBox }.first
        let firstEntry = elst?.table.first
        #expect(firstEntry?.mediaTime == 2112)
    }

    @Test
    func zeroPreSkipDoesNotEmitEditList() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.audioConfig(priming: AudioPriming(preSkip: 0))]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let hasEditBox = trak.children.contains(where: { $0 is EditBox })
        #expect(hasEditBox == false)
    }

    @Test
    func videoTrackWithoutEditList() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.videoConfig()]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let hasEditBox = trak.children.contains(where: { $0 is EditBox })
        #expect(hasEditBox == false)
    }

    @Test
    func explicitEditListOverridesAutoEmission() async throws {
        let explicit = EditListBox(
            version: 1,
            table: EditListTable(
                entries: [
                    EditListEntry(
                        segmentDuration: 1000,
                        mediaTime: -1,
                        mediaRateInteger: 1,
                        mediaRateFraction: 0
                    )
                ],
                version: 1
            )
        )
        var audio = WriterFixtures.audioConfig(priming: AudioPriming(preSkip: 312))
        audio = CMAFTrackConfiguration(
            trackID: audio.trackID,
            kind: audio.kind,
            profile: audio.profile,
            timescale: audio.timescale,
            language: audio.language,
            videoFields: nil,
            audioFields: audio.audioFields,
            subtitleFields: nil,
            metadataFields: nil,
            editList: explicit,
            encryptionParameters: nil,
            defaultSampleFlags: audio.defaultSampleFlags
        )
        let writer = try CMAFInitSegmentWriter(configurations: [audio])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let edts = try #require(trak.children.compactMap { $0 as? EditBox }.first)
        let elst = try #require(edts.children.compactMap { $0 as? EditListBox }.first)
        // Explicit edit list wins over auto-generated one.
        #expect(elst.table.first?.mediaTime == -1)
    }
}
