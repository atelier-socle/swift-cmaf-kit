// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFMediaSegmentWriter — encryption")
struct CMAFMediaSegmentWriterEncryptionTests {

    @Test
    func cencEncryptedFragmentEmitsSenc() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(
                encrypted: WriterFixtures.cencParameters()
            ),
            fragmentBoundary: .sampleCount(3)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<3 {
            emitted += try await writer.appendSample(
                WriterFixtures.encryptedVideoSample(),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        let moof = try #require(boxes.compactMap { $0 as? MovieFragmentBox }.first)
        let traf = try #require(
            moof.children.compactMap { $0 as? TrackFragmentBox }.first
        )
        // senc is registered nowhere by design — it appears as an
        // ISOBoxOpaque inside traf. Confirm structurally.
        let hasSenc = traf.children.contains {
            if let unknown = $0 as? UnknownBox { return unknown.actualType == "senc" }
            return false
        }
        let hasSaiz = traf.children.contains {
            if let f = $0 as? SampleAuxiliaryInformationSizesBox { return f.sampleCount > 0 }
            return false
        }
        let hasSaio = traf.children.contains {
            $0 is SampleAuxiliaryInformationOffsetsBox
        }
        #expect(hasSenc)
        #expect(hasSaiz)
        #expect(hasSaio)
    }

    @Test
    func mismatchedIVSizeThrows() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(
                encrypted: WriterFixtures.cencParameters()  // declares IV size 8
            ),
            fragmentBoundary: .sampleCount(2)
        )
        await #expect(throws: CMAFWriterError.self) {
            _ = try await writer.appendSample(
                WriterFixtures.encryptedVideoSample(ivSize: 16),  // wrong size
                toTrack: 1
            )
        }
    }

    @Test
    func missingEncryptionMetadataThrows() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(
                encrypted: WriterFixtures.cencParameters()
            ),
            fragmentBoundary: .sampleCount(2)
        )
        await #expect(throws: CMAFWriterError.self) {
            _ = try await writer.appendSample(
                WriterFixtures.videoSample(),  // no encryption metadata
                toTrack: 1
            )
        }
    }

    @Test
    func cbcsPatternRoundTrip() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(
                encrypted: try WriterFixtures.cbcsParameters()
            ),
            fragmentBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            // cbcs uses ivSize = 0 with constantIV.
            emitted += try await writer.appendSample(
                CMAFSampleInput(
                    bytes: Data(repeating: 0xCC, count: 512),
                    durationInTimescale: 3000,
                    flags: .syncSample,
                    encryption: CMAFSampleInput.EncryptionMetadata(
                        initializationVector: Data()
                    )
                ),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        #expect(boxes.contains { $0 is MovieFragmentBox })
        #expect(boxes.contains { $0 is MediaDataBox })
    }

    @Test
    func subsamplePartitionMismatchThrows() async throws {
        // We feed via the assembler directly to exercise the validation.
        let bytes = Data(repeating: 0xAA, count: 100)
        let badSubsamples = [
            SampleEncryptionBox.SubsamplePartition(
                bytesOfClearData: 10,
                bytesOfProtectedData: 50
            )
        ]
        #expect(throws: SegmentByteAssemblerError.self) {
            _ = try SegmentByteAssembler.emitFragment(
                trackID: 1,
                sequenceNumber: 1,
                baseMediaDecodeTime: 0,
                samples: [
                    SegmentByteAssembler.WriterSample(
                        metadata: FragmentSampleMetadata(
                            sampleSize: UInt32(bytes.count),
                            durationInTimescale: 3000,
                            compositionTimeOffset: 0,
                            flags: .syncSample
                        ),
                        bytes: bytes,
                        encryption: CMAFSampleInput.EncryptionMetadata(
                            initializationVector: Data(repeating: 0x11, count: 8),
                            subsamples: badSubsamples
                        )
                    )
                ],
                encryption: WriterFixtures.cencParameters()
            )
        }
    }

    @Test
    func saioOffsetsRoundTripExactly() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(
                encrypted: WriterFixtures.cencParameters()
            ),
            fragmentBoundary: .sampleCount(3)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<3 {
            emitted += try await writer.appendSample(
                WriterFixtures.encryptedVideoSample(),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        let moof = try #require(boxes.compactMap { $0 as? MovieFragmentBox }.first)
        let traf = try #require(
            moof.children.compactMap { $0 as? TrackFragmentBox }.first
        )
        let saio = try #require(
            traf.children.compactMap { $0 as? SampleAuxiliaryInformationOffsetsBox }.first
        )
        // Offsets must be strictly increasing.
        let offsets = Array(saio.table)
        #expect(offsets.count == 3)
        #expect(offsets[0] < offsets[1])
        #expect(offsets[1] < offsets[2])
    }
}
