// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCVideoParameterSet")
struct HEVCVideoParameterSetTests {

    private static func defaultPTL(
        level: HEVCLevelIDC = .level4_1,
        subLayerCount: Int = 0
    ) -> HEVCProfileTierLevel {
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
            generalLevel: level,
            subLayers: Array(repeating: HEVCProfileTierLevel.SubLayerEntry(), count: subLayerCount)
        )
    }

    @Test
    func minimalVPSRoundTrip() throws {
        let vps = HEVCVideoParameterSet(
            vpsID: 0,
            baseLayerInternalFlag: true,
            baseLayerAvailableFlag: true,
            maxLayersMinus1: 0,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: Self.defaultPTL(),
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
        let encoded = vps.encode()
        let decoded = try HEVCVideoParameterSet.parse(rbsp: encoded)
        #expect(decoded == vps)
    }

    @Test
    func vpsWithSubLayersRoundTrip() throws {
        let vps = HEVCVideoParameterSet(
            vpsID: 0,
            baseLayerInternalFlag: true,
            baseLayerAvailableFlag: true,
            maxLayersMinus1: 0,
            maxSubLayersMinus1: 2,
            temporalIDNestingFlag: false,
            profileTierLevel: Self.defaultPTL(level: .level5_1, subLayerCount: 2),
            subLayerOrderingInfoPresentFlag: true,
            subLayerOrderingInfo: [
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: 2,
                    maxNumReorderPics: 0,
                    maxLatencyIncreasePlus1: 0
                ),
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: 4,
                    maxNumReorderPics: 1,
                    maxLatencyIncreasePlus1: 0
                ),
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: 5,
                    maxNumReorderPics: 2,
                    maxLatencyIncreasePlus1: 0
                )
            ],
            maxLayerID: 0
        )
        let encoded = vps.encode()
        let decoded = try HEVCVideoParameterSet.parse(rbsp: encoded)
        #expect(decoded == vps)
    }

    @Test
    func vpsWithTimingInfoRoundTrip() throws {
        let vps = HEVCVideoParameterSet(
            vpsID: 0,
            baseLayerInternalFlag: true,
            baseLayerAvailableFlag: true,
            maxLayersMinus1: 0,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: Self.defaultPTL(),
            subLayerOrderingInfoPresentFlag: true,
            subLayerOrderingInfo: [
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: 5,
                    maxNumReorderPics: 0,
                    maxLatencyIncreasePlus1: 0
                )
            ],
            maxLayerID: 0,
            timingInfo: HEVCVideoParameterSet.TimingInfo(
                numUnitsInTick: 1,
                timeScale: 60,
                pocProportionalToTimingFlag: false
            )
        )
        let encoded = vps.encode()
        let decoded = try HEVCVideoParameterSet.parse(rbsp: encoded)
        #expect(decoded == vps)
        #expect(decoded.timingInfo?.timeScale == 60)
    }

    @Test
    func rejectsBadReservedField() {
        // Hand-craft an SPS with reserved bits = 0 instead of 0xFFFF.
        var writer = BitWriter()
        writer.writeBits(0, count: 4)  // vpsID
        writer.writeBool(true)  // baseLayerInternal
        writer.writeBool(true)  // baseLayerAvailable
        writer.writeBits(0, count: 6)  // maxLayers
        writer.writeBits(0, count: 3)  // maxSubLayers
        writer.writeBool(true)  // tidNesting
        writer.writeBits(0xFFFE, count: 16)  // BAD reserved (should be 0xFFFF)
        writer.byteAlign()
        #expect(throws: BitstreamError.self) {
            _ = try HEVCVideoParameterSet.parse(rbsp: writer.data)
        }
    }

    @Test
    func equalityAndHashing() throws {
        let a = HEVCVideoParameterSet(
            vpsID: 0,
            baseLayerInternalFlag: true,
            baseLayerAvailableFlag: true,
            maxLayersMinus1: 0,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: Self.defaultPTL(),
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
        let b = HEVCVideoParameterSet(
            vpsID: 0,
            baseLayerInternalFlag: true,
            baseLayerAvailableFlag: true,
            maxLayersMinus1: 0,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: Self.defaultPTL(),
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
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}

@Suite("HEVCProfileTierLevel")
struct HEVCProfileTierLevelTests {

    @Test
    func generalOnlyRoundTrip() throws {
        let ptl = HEVCProfileTierLevel(
            generalProfile: HEVCProfileTierLevel.ProfileBlock(
                profileSpace: .zero,
                tierFlag: .main,
                profileIDC: .main10,
                compatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0x0000_0004),
                constraintFlags: HEVCConstraintIndicatorFlags(
                    progressiveSourceFlag: true,
                    interlacedSourceFlag: false,
                    nonPackedConstraintFlag: true,
                    frameOnlyConstraintFlag: true
                )
            ),
            generalLevel: .level5
        )
        var writer = BitWriter()
        ptl.encode(to: &writer, profilePresentFlag: true, maxNumSubLayersMinus1: 0)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try HEVCProfileTierLevel.parse(
            reader: &reader, profilePresentFlag: true, maxNumSubLayersMinus1: 0
        )
        #expect(decoded == ptl)
    }

    @Test
    func withSubLayerInfoRoundTrip() throws {
        let ptl = HEVCProfileTierLevel(
            generalProfile: HEVCProfileTierLevel.ProfileBlock(
                profileSpace: .zero,
                tierFlag: .high,
                profileIDC: .main,
                compatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0),
                constraintFlags: HEVCConstraintIndicatorFlags(
                    progressiveSourceFlag: true,
                    interlacedSourceFlag: false,
                    nonPackedConstraintFlag: true,
                    frameOnlyConstraintFlag: true
                )
            ),
            generalLevel: .level5_1,
            subLayers: [
                HEVCProfileTierLevel.SubLayerEntry(
                    profileBlock: nil,
                    levelIDC: .level4_1
                )
            ]
        )
        var writer = BitWriter()
        ptl.encode(to: &writer, profilePresentFlag: true, maxNumSubLayersMinus1: 1)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try HEVCProfileTierLevel.parse(
            reader: &reader, profilePresentFlag: true, maxNumSubLayersMinus1: 1
        )
        #expect(decoded == ptl)
    }
}
