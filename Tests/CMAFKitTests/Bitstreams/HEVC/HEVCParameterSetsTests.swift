// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

// MARK: - Shared fixtures

/// File-private fixture namespace shared by the two ``HEVCParameterSets``
/// test suites. Extracted from the suites themselves to keep each suite
/// body within the SwiftLint type_body_length budget.
private enum HEVCPSFixtures {

    static func defaultPTL(level: HEVCLevelIDC = .level4_1) -> HEVCProfileTierLevel {
        HEVCProfileTierLevel(
            generalProfile: HEVCProfileTierLevel.ProfileBlock(
                profileSpace: .zero,
                tierFlag: .main,
                profileIDC: .main,
                compatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0x6000_0000),
                constraintFlags: HEVCConstraintIndicatorFlags(
                    progressiveSourceFlag: true,
                    interlacedSourceFlag: false,
                    nonPackedConstraintFlag: true,
                    frameOnlyConstraintFlag: true
                )
            ),
            generalLevel: level
        )
    }

    static func minimalVPS(
        vpsID: UInt8 = 0,
        ptl: HEVCProfileTierLevel? = nil
    ) -> HEVCVideoParameterSet {
        HEVCVideoParameterSet(
            vpsID: vpsID,
            baseLayerInternalFlag: true,
            baseLayerAvailableFlag: true,
            maxLayersMinus1: 0,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: ptl ?? defaultPTL(),
            subLayerOrderingInfoPresentFlag: true,
            subLayerOrderingInfo: [
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: 5,
                    maxNumReorderPics: 0,
                    maxLatencyIncreasePlus1: 0
                )
            ],
            maxLayerID: 0
        )
    }

    static func minimalSPS(
        vpsID: UInt8 = 0,
        spsID: UInt32 = 0,
        ptl: HEVCProfileTierLevel? = nil
    ) -> HEVCSequenceParameterSet {
        HEVCSequenceParameterSet(
            vpsID: vpsID,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: ptl ?? defaultPTL(),
            spsID: spsID,
            chromaFormatIDC: .format420,
            picWidthInLumaSamples: 1920,
            picHeightInLumaSamples: 1080,
            conformanceWindow: nil,
            bitDepthYMinus8: 0,
            bitDepthCMinus8: 0,
            log2MaxPicOrderCntLsbMinus4: 4,
            subLayerOrderingInfoPresentFlag: true,
            subLayerOrderingInfo: [
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: 4,
                    maxNumReorderPics: 2,
                    maxLatencyIncreasePlus1: 0
                )
            ],
            log2MinLumaCodingBlockSizeMinus3: 0,
            log2DiffMaxMinLumaCodingBlockSize: 3,
            log2MinLumaTransformBlockSizeMinus2: 0,
            log2DiffMaxMinLumaTransformBlockSize: 3,
            maxTransformHierarchyDepthInter: 0,
            maxTransformHierarchyDepthIntra: 0,
            amplificationEnabledFlag: false,
            sampleAdaptiveOffsetEnabledFlag: false,
            pcmInfo: nil,
            shortTermRefPicSets: [],
            longTermRefPicsInfo: nil,
            spsTemporalMVPEnabledFlag: true,
            strongIntraSmoothingEnabledFlag: false,
            vuiParameters: nil
        )
    }

    static func minimalPPS(
        ppsID: UInt32 = 0,
        spsID: UInt32 = 0
    ) -> HEVCPictureParameterSet {
        HEVCPictureParameterSet(
            ppsID: ppsID,
            spsID: spsID,
            dependentSliceSegmentsEnabledFlag: false,
            outputFlagPresentFlag: false,
            numExtraSliceHeaderBits: 0,
            signDataHidingEnabledFlag: false,
            cabacInitPresentFlag: false,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            initQPMinus26: 0,
            constrainedIntraPredFlag: false,
            transformSkipEnabledFlag: false,
            cuQPDeltaEnabledFlag: false,
            cbQPOffset: 0,
            crQPOffset: 0,
            sliceChromaQPOffsetsPresentFlag: false,
            weightedPredFlag: false,
            weightedBipredFlag: false,
            transquantBypassEnabledFlag: false,
            entropyCodingSyncEnabledFlag: false,
            loopFilterAcrossSlicesEnabledFlag: true,
            listsModificationPresentFlag: false,
            log2ParallelMergeLevelMinus2: 0,
            sliceSegmentHeaderExtensionPresentFlag: false
        )
    }

    /// Wrap an RBSP body with the canonical 2-byte NAL header. Body bytes
    /// are passed verbatim (no emulation-prevention insertion).
    static func wrapNAL(rbsp: Data, nalType: UInt8) -> Data {
        var nal = Data()
        nal.append((nalType & 0x3F) << 1)
        nal.append(0x01)
        nal.append(rbsp)
        return nal
    }

    /// Wrap with NAL header + apply RBSP → EBSP emulation-prevention.
    static func wrapEBSP(rbsp: Data, nalType: UInt8) -> Data {
        var nal = Data()
        nal.append((nalType & 0x3F) << 1)
        nal.append(0x01)
        nal.append(NALRBSPDecoder.rbspToEBSP(rbsp))
        return nal
    }
}

// MARK: - Happy paths and toHvcCArrays

@Suite("HEVCParameterSets")
struct HEVCParameterSetsTests {

    @Test
    func extractFromRawRBSPSingleVPSSPSPPS() throws {
        let vpsNAL = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let spsNAL = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let ppsNAL = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)

        let sets = try HEVCParameterSets.extract(
            from: [vpsNAL, spsNAL, ppsNAL], format: .rawRBSP
        )
        #expect(sets.videoParameterSets.count == 1)
        #expect(sets.sequenceParameterSets.count == 1)
        #expect(sets.pictureParameterSets.count == 1)
        #expect(sets.videoParameterSets[0].vpsID == 0)
        #expect(sets.sequenceParameterSets[0].spsID == 0)
        #expect(sets.pictureParameterSets[0].ppsID == 0)
    }

    @Test
    func extractFromEBSPWithPrefix() throws {
        let vpsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let spsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let ppsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)

        let sets = try HEVCParameterSets.extract(
            from: [vpsNAL, spsNAL, ppsNAL], format: .ebspWithPrefix
        )
        #expect(sets.videoParameterSets.count == 1)
        #expect(sets.sequenceParameterSets.count == 1)
        #expect(sets.pictureParameterSets.count == 1)
    }

    @Test
    func extractFromLengthPrefixed4ByteISOBMFFForm() throws {
        let vpsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let spsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let ppsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)

        func prefix(_ payload: Data) -> Data {
            var out = Data()
            let n = UInt32(payload.count).bigEndian
            withUnsafeBytes(of: n) { out.append(contentsOf: $0) }
            out.append(payload)
            return out
        }

        let sets = try HEVCParameterSets.extract(
            from: [vpsNAL, spsNAL, ppsNAL].map(prefix),
            format: .lengthPrefixed(prefixBytes: 4)
        )
        #expect(sets.videoParameterSets.count == 1)
    }

    @Test
    func extractFromLengthPrefixed1Byte() throws {
        let vpsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let spsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let ppsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)

        func prefix(_ payload: Data) -> Data {
            var out = Data()
            out.append(UInt8(min(payload.count, 0xFF)))
            out.append(payload)
            return out
        }

        let sets = try HEVCParameterSets.extract(
            from: [vpsNAL, spsNAL, ppsNAL].map(prefix),
            format: .lengthPrefixed(prefixBytes: 1)
        )
        #expect(sets.videoParameterSets.count == 1)
    }

    @Test
    func extractFromLengthPrefixed2Bytes() throws {
        let vpsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let spsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let ppsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)

        func prefix(_ payload: Data) -> Data {
            var out = Data()
            let n = UInt16(payload.count).bigEndian
            withUnsafeBytes(of: n) { out.append(contentsOf: $0) }
            out.append(payload)
            return out
        }

        let sets = try HEVCParameterSets.extract(
            from: [vpsNAL, spsNAL, ppsNAL].map(prefix),
            format: .lengthPrefixed(prefixBytes: 2)
        )
        #expect(sets.videoParameterSets.count == 1)
    }

    @Test
    func extractFromAnnexB000001StartCode() throws {
        let vpsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let spsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let ppsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)

        var stream = Data()
        for nal in [vpsNAL, spsNAL, ppsNAL] {
            stream.append(contentsOf: [0x00, 0x00, 0x01])
            stream.append(nal)
        }
        let sets = try HEVCParameterSets.extract(from: [stream], format: .annexB)
        #expect(sets.videoParameterSets.count == 1)
    }

    @Test
    func extractFromAnnexB00000001StartCode() throws {
        let vpsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let spsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let ppsNAL = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)

        var stream = Data()
        for nal in [vpsNAL, spsNAL, ppsNAL] {
            stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
            stream.append(nal)
        }
        let sets = try HEVCParameterSets.extract(from: [stream], format: .annexB)
        #expect(sets.videoParameterSets.count == 1)
    }

    @Test
    func extractMultiplePerType() throws {
        let vps0 = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS(vpsID: 0).encode(), nalType: 32)
        let vps1 = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS(vpsID: 1).encode(), nalType: 32)
        let sps0 = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS(spsID: 0).encode(), nalType: 33)
        let sps1 = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS(spsID: 1).encode(), nalType: 33)
        let pps0 = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalPPS(ppsID: 0).encode(), nalType: 34)
        let pps1 = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalPPS(ppsID: 1).encode(), nalType: 34)

        let sets = try HEVCParameterSets.extract(
            from: [vps0, vps1, sps0, sps1, pps0, pps1], format: .rawRBSP
        )
        #expect(sets.videoParameterSets.count == 2)
        #expect(sets.sequenceParameterSets.count == 2)
        #expect(sets.pictureParameterSets.count == 2)
    }

    @Test
    func extractSkipsNonParameterSetNALs() throws {
        let vpsNAL = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let spsNAL = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let ppsNAL = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)
        // IDR VCL NAL unit (type 19) — must be silently skipped.
        let vclNAL = Data([UInt8(19 << 1), 0x01, 0xAA, 0xBB, 0xCC])

        let sets = try HEVCParameterSets.extract(
            from: [vclNAL, vpsNAL, vclNAL, spsNAL, vclNAL, ppsNAL], format: .rawRBSP
        )
        #expect(sets.videoParameterSets.count == 1)
        #expect(sets.sequenceParameterSets.count == 1)
        #expect(sets.pictureParameterSets.count == 1)
    }

    @Test
    func toHvcCArraysVPSSPSPPSOrder() throws {
        let sets = HEVCParameterSets(
            videoParameterSets: [HEVCPSFixtures.minimalVPS()],
            sequenceParameterSets: [HEVCPSFixtures.minimalSPS()],
            pictureParameterSets: [HEVCPSFixtures.minimalPPS()]
        )
        let arrays = sets.toHvcCArrays()
        #expect(arrays.count == 3)
        #expect(arrays[0].nalUnitType == .vpsNUT)
        #expect(arrays[1].nalUnitType == .spsNUT)
        #expect(arrays[2].nalUnitType == .ppsNUT)
    }

    @Test
    func toHvcCArraysArrayCompletenessDefaultTrue() throws {
        let sets = HEVCParameterSets(
            videoParameterSets: [HEVCPSFixtures.minimalVPS()],
            sequenceParameterSets: [HEVCPSFixtures.minimalSPS()],
            pictureParameterSets: [HEVCPSFixtures.minimalPPS()]
        )
        for array in sets.toHvcCArrays() {
            #expect(array.arrayCompleteness == true)
        }
    }

    @Test
    func toHvcCArraysRoundTripsThroughExtract() throws {
        let original = HEVCParameterSets(
            videoParameterSets: [HEVCPSFixtures.minimalVPS()],
            sequenceParameterSets: [HEVCPSFixtures.minimalSPS()],
            pictureParameterSets: [HEVCPSFixtures.minimalPPS()]
        )
        let arrays = original.toHvcCArrays()
        let flatNALs = arrays.flatMap { $0.parameterSets.map(\.rbspBytes) }
        let reExtracted = try HEVCParameterSets.extract(
            from: flatNALs, format: .ebspWithPrefix
        )
        #expect(reExtracted == original)
    }

    @Test
    func toHvcCArraysSkipsEmptyGroups() throws {
        let onlyVPS = HEVCParameterSets(
            videoParameterSets: [HEVCPSFixtures.minimalVPS()],
            sequenceParameterSets: [],
            pictureParameterSets: []
        )
        let arrays = onlyVPS.toHvcCArrays()
        #expect(arrays.count == 1)
        #expect(arrays[0].nalUnitType == .vpsNUT)
    }

    @Test
    func equatableSameInputSameInstance() throws {
        let a = HEVCParameterSets(
            videoParameterSets: [HEVCPSFixtures.minimalVPS()],
            sequenceParameterSets: [HEVCPSFixtures.minimalSPS()],
            pictureParameterSets: [HEVCPSFixtures.minimalPPS()]
        )
        let b = HEVCParameterSets(
            videoParameterSets: [HEVCPSFixtures.minimalVPS()],
            sequenceParameterSets: [HEVCPSFixtures.minimalSPS()],
            pictureParameterSets: [HEVCPSFixtures.minimalPPS()]
        )
        #expect(a == b)
    }

    @Test
    func hashableSameInputSameHash() throws {
        let a = HEVCParameterSets(
            videoParameterSets: [HEVCPSFixtures.minimalVPS()],
            sequenceParameterSets: [HEVCPSFixtures.minimalSPS()],
            pictureParameterSets: [HEVCPSFixtures.minimalPPS()]
        )
        let b = HEVCParameterSets(
            videoParameterSets: [HEVCPSFixtures.minimalVPS()],
            sequenceParameterSets: [HEVCPSFixtures.minimalSPS()],
            pictureParameterSets: [HEVCPSFixtures.minimalPPS()]
        )
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }
}

// MARK: - Error paths

@Suite("HEVCParameterSets errors")
struct HEVCParameterSetsErrorsTests {

    @Test
    func extractDuplicateVPSThrows() throws {
        let vps0a = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS(vpsID: 3).encode(), nalType: 32)
        let vps0b = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS(vpsID: 3).encode(), nalType: 32)
        #expect(throws: HEVCParameterSetsError.duplicateParameterSet(type: .vpsNUT, id: 3)) {
            _ = try HEVCParameterSets.extract(from: [vps0a, vps0b], format: .rawRBSP)
        }
    }

    @Test
    func extractDuplicateSPSThrows() throws {
        let vps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let sps0a = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS(spsID: 5).encode(), nalType: 33)
        let sps0b = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS(spsID: 5).encode(), nalType: 33)
        #expect(throws: HEVCParameterSetsError.duplicateParameterSet(type: .spsNUT, id: 5)) {
            _ = try HEVCParameterSets.extract(from: [vps, sps0a, sps0b], format: .rawRBSP)
        }
    }

    @Test
    func extractDuplicatePPSThrows() throws {
        let vps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let sps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let pps0a = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalPPS(ppsID: 7).encode(), nalType: 34)
        let pps0b = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalPPS(ppsID: 7).encode(), nalType: 34)
        #expect(throws: HEVCParameterSetsError.duplicateParameterSet(type: .ppsNUT, id: 7)) {
            _ = try HEVCParameterSets.extract(from: [vps, sps, pps0a, pps0b], format: .rawRBSP)
        }
    }

    @Test
    func extractConflictingPTLThrows() throws {
        // Same vpsID on both VPS and SPS, but different PTL (different level).
        let vpsLowLevel = HEVCPSFixtures.minimalVPS(
            vpsID: 0, ptl: HEVCPSFixtures.defaultPTL(level: .level3)
        )
        let spsHighLevel = HEVCPSFixtures.minimalSPS(
            vpsID: 0, ptl: HEVCPSFixtures.defaultPTL(level: .level5_1)
        )
        let vps = HEVCPSFixtures.wrapNAL(rbsp: vpsLowLevel.encode(), nalType: 32)
        let sps = HEVCPSFixtures.wrapNAL(rbsp: spsHighLevel.encode(), nalType: 33)
        let pps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)
        #expect(throws: HEVCParameterSetsError.self) {
            _ = try HEVCParameterSets.extract(from: [vps, sps, pps], format: .rawRBSP)
        }
    }

    @Test
    func extractMissingVPSThrows() throws {
        let sps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        let pps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)
        #expect(throws: HEVCParameterSetsError.missingMandatoryParameterSet(type: .vpsNUT)) {
            _ = try HEVCParameterSets.extract(from: [sps, pps], format: .rawRBSP)
        }
    }

    @Test
    func extractMissingSPSThrows() throws {
        let vps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let pps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalPPS().encode(), nalType: 34)
        #expect(throws: HEVCParameterSetsError.missingMandatoryParameterSet(type: .spsNUT)) {
            _ = try HEVCParameterSets.extract(from: [vps, pps], format: .rawRBSP)
        }
    }

    @Test
    func extractMissingPPSThrows() throws {
        let vps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let sps = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        #expect(throws: HEVCParameterSetsError.missingMandatoryParameterSet(type: .ppsNUT)) {
            _ = try HEVCParameterSets.extract(from: [vps, sps], format: .rawRBSP)
        }
    }

    @Test
    func extractTruncatedHeaderThrows() throws {
        let truncated = Data([0x40])
        #expect(throws: HEVCParameterSetsError.self) {
            _ = try HEVCParameterSets.extract(from: [truncated], format: .rawRBSP)
        }
    }

    @Test
    func extractInvalidLengthPrefixSizeThrows() throws {
        let vps = HEVCPSFixtures.wrapEBSP(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        #expect(throws: HEVCParameterSetsError.self) {
            _ = try HEVCParameterSets.extract(
                from: [vps], format: .lengthPrefixed(prefixBytes: 3)
            )
        }
    }

    @Test
    func extractTruncatedLengthPrefixedBufferThrows() throws {
        // Buffer too short to hold the 4-byte length prefix.
        let tooShort = Data([0x00, 0x01])
        #expect(throws: HEVCParameterSetsError.self) {
            _ = try HEVCParameterSets.extract(
                from: [tooShort], format: .lengthPrefixed(prefixBytes: 4)
            )
        }
    }

    @Test
    func extractAnnexBWithoutStartCodeThrows() throws {
        let noStartCode = Data([0x00, 0xAA, 0xBB])
        #expect(throws: HEVCParameterSetsError.self) {
            _ = try HEVCParameterSets.extract(from: [noStartCode], format: .annexB)
        }
    }

    @Test
    func extractMalformedVPSRBSPThrows() throws {
        // Valid VPS NAL header (0x40 0x01) + garbage body that cannot parse.
        var garbage = Data()
        garbage.append(0x40)
        garbage.append(0x01)
        garbage.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        #expect(throws: HEVCParameterSetsError.self) {
            _ = try HEVCParameterSets.extract(from: [garbage], format: .rawRBSP)
        }
    }

    @Test
    func extractMalformedSPSRBSPThrows() throws {
        let validVPS = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        var sps = Data()
        sps.append(0x42)
        sps.append(0x01)
        sps.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        #expect(throws: HEVCParameterSetsError.self) {
            _ = try HEVCParameterSets.extract(from: [validVPS, sps], format: .rawRBSP)
        }
    }

    @Test
    func extractMalformedPPSRBSPThrows() throws {
        let validVPS = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalVPS().encode(), nalType: 32)
        let validSPS = HEVCPSFixtures.wrapNAL(rbsp: HEVCPSFixtures.minimalSPS().encode(), nalType: 33)
        var pps = Data()
        pps.append(0x44)
        pps.append(0x01)
        pps.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        #expect(throws: HEVCParameterSetsError.self) {
            _ = try HEVCParameterSets.extract(
                from: [validVPS, validSPS, pps], format: .rawRBSP
            )
        }
    }
}
