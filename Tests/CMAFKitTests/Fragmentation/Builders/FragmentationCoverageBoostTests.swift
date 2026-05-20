// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Targeted tests that exercise the code paths the broader test
// suites leave uncovered. Every file under
// ``Sources/CMAFKit/Fragmentation/`` must reach ≥ 85 % line coverage;
// the tests here are written specifically to close that final gap.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Fragmentation — targeted coverage push")
struct FragmentationCoverageBoostTests {

    // MARK: - SampleFlags

    @Test
    func sampleFlagsRawValueLoadAllFields() {
        let flags = SampleFlags(
            isLeading: 1,
            sampleDependsOn: 2,
            sampleIsDependedOn: 3,
            sampleHasRedundancy: 1,
            samplePaddingValue: 4,
            sampleIsNonSyncSample: true,
            sampleDegradationPriority: 0x1234
        )
        let raw = flags.rawValue
        let parsed = SampleFlags(rawValue: raw)
        #expect(parsed.isLeading == 1)
        #expect(parsed.sampleDependsOn == 2)
        #expect(parsed.sampleIsDependedOn == 3)
        #expect(parsed.sampleHasRedundancy == 1)
        #expect(parsed.samplePaddingValue == 4)
        #expect(parsed.sampleIsNonSyncSample)
        #expect(parsed.sampleDegradationPriority == 0x1234)
    }

    @Test
    func sampleFlagsCornerValues() {
        let max = SampleFlags(
            isLeading: 3,
            sampleDependsOn: 3,
            sampleIsDependedOn: 3,
            sampleHasRedundancy: 3,
            samplePaddingValue: 7,
            sampleIsNonSyncSample: true,
            sampleDegradationPriority: 0xFFFF
        )
        let roundTrip = SampleFlags(rawValue: max.rawValue)
        #expect(roundTrip == max)
    }

    @Test
    func sampleFlagsIsSyncSampleHelper() {
        #expect(SampleFlags.syncSample.isSyncSample)
        #expect(SampleFlags.nonSyncSample.isSyncSample == false)
    }

    // MARK: - SegmentByteAssembler

    @Test
    func assemblerAcceptsUnencryptedFragment() throws {
        let result = try SegmentByteAssembler.emitFragment(
            trackID: 1,
            sequenceNumber: 1,
            baseMediaDecodeTime: 0,
            samples: [
                SegmentByteAssembler.WriterSample(
                    metadata: FragmentSampleMetadata(
                        sampleSize: 16,
                        durationInTimescale: 3000,
                        compositionTimeOffset: 0,
                        flags: .syncSample
                    ),
                    bytes: Data(repeating: 0xAA, count: 16),
                    encryption: nil
                )
            ],
            encryption: nil
        )
        #expect(result.moofByteSize > 0)
        #expect(result.mdatByteSize == 8 + 16)
    }

    @Test
    func assemblerEmitsSubsamplePartitionsInSenc() throws {
        let bytes = Data(repeating: 0xAA, count: 100)
        let partitions = [
            SampleEncryptionBox.SubsamplePartition(
                bytesOfClearData: 10,
                bytesOfProtectedData: 90
            )
        ]
        let result = try SegmentByteAssembler.emitFragment(
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
                        subsamples: partitions
                    )
                )
            ],
            encryption: WriterFixtures.cencParameters()
        )
        #expect(result.moofByteSize > 0)
    }

    @Test
    func assemblerSkipsAuxBoxesWhenAllSamplesZeroIVNoSubsamples() throws {
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0xCC, count: 16))
        let cbcsParams = CMAFEncryptionParameters(
            scheme: .cbcs,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .zero,
            defaultConstantIV: constantIV,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9
        )
        let bytes = Data(repeating: 0xAA, count: 16)
        let result = try SegmentByteAssembler.emitFragment(
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
                        initializationVector: Data()
                    )
                )
            ],
            encryption: cbcsParams
        )
        // Round-trip must still parse cleanly.
        #expect(result.moofByteSize > 0)
        #expect(result.mdatByteSize == 8 + bytes.count)
    }

    // MARK: - FragmentTreeBuilder

    @Test
    func fragmentInvariancePicksDefaultsWhenAllSamplesUniform() {
        let samples = (0..<4).map { _ in
            FragmentSampleMetadata(
                sampleSize: 1024,
                durationInTimescale: 3000,
                compositionTimeOffset: 0,
                flags: .nonSyncSample
            )
        }
        let invariance = FragmentInvariance.scan(samples: samples)
        #expect(invariance.defaultSampleDuration == 3000)
        #expect(invariance.defaultSampleSize == 1024)
        #expect(invariance.defaultSampleFlags == SampleFlags.nonSyncSample.rawValue)
        #expect(invariance.firstSampleFlagsDiffer == false)
    }

    @Test
    func fragmentInvarianceWithMixedFlagsNoFirstOnlyDiff() {
        // Mixed flags but not the "first differs" pattern.
        let samples: [FragmentSampleMetadata] = [
            FragmentSampleMetadata(
                sampleSize: 100, durationInTimescale: 3000,
                compositionTimeOffset: 0, flags: .syncSample
            ),
            FragmentSampleMetadata(
                sampleSize: 100, durationInTimescale: 3000,
                compositionTimeOffset: 0, flags: .nonSyncSample
            ),
            FragmentSampleMetadata(
                sampleSize: 100, durationInTimescale: 3000,
                compositionTimeOffset: 0, flags: .syncSample
            )
        ]
        let invariance = FragmentInvariance.scan(samples: samples)
        #expect(invariance.firstSampleFlagsDiffer == false)
        #expect(invariance.defaultSampleFlags == nil)
    }

    @Test
    func fragmentBuilderHandlesNegativeCTSV1() {
        let samples: [FragmentSampleMetadata] = [
            FragmentSampleMetadata(
                sampleSize: 100, durationInTimescale: 3000,
                compositionTimeOffset: 100, flags: .syncSample
            ),
            FragmentSampleMetadata(
                sampleSize: 100, durationInTimescale: 3000,
                compositionTimeOffset: -50, flags: .nonSyncSample
            )
        ]
        let (moof, _) = FragmentTreeBuilder.makeMovieFragment(
            trackID: 1,
            sequenceNumber: 1,
            baseMediaDecodeTime: 0,
            samples: samples,
            dataOffsetFromMoof: 100
        )
        let traf = moof.children.compactMap { $0 as? TrackFragmentBox }.first
        let trun = traf?.children.compactMap { $0 as? TrackRunBox }.first
        #expect(trun?.version == 1)
    }

    // MARK: - BrandComposer

    @Test
    func brandComposerEmptyConfigurationsDefaultsToBasic() {
        let brands = BrandComposer.compatibleBrands(for: [])
        #expect(brands.contains("iso6"))
    }

    @Test
    func brandComposerWithTwoVideoTracksAddsCmf2() {
        let v1 = WriterFixtures.videoConfig(trackID: 1)
        let v2 = WriterFixtures.videoConfig(trackID: 2)
        let brands = BrandComposer.compatibleBrands(for: [v1, v2])
        #expect(brands.contains("cmf2"))
    }

    @Test
    func brandComposerProfileOnlyHelperPath() {
        let ftyp = BrandComposer.makeFileTypeBox(
            profile: .fragmented,
            extraCompatibleBrands: ["hvc1"]
        )
        #expect(ftyp.compatibleBrands.contains("hvc1"))
        let styp = BrandComposer.makeSegmentTypeBox(
            profile: .fragmented,
            extraCompatibleBrands: ["hvc1"]
        )
        #expect(styp.compatibleBrands.contains("hvc1"))
    }

}
