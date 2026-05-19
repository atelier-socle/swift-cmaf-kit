// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCHRDParameters")
struct HEVCHRDParametersTests {

    private static func roundTrip(
        _ hrd: HEVCHRDParameters,
        commonInfPresent: Bool = true,
        maxSubLayersMinus1: UInt8 = 0
    ) throws -> HEVCHRDParameters {
        var writer = BitWriter()
        hrd.encode(
            to: &writer,
            commonInfPresentFlag: commonInfPresent,
            maxNumSubLayersMinus1: maxSubLayersMinus1
        )
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        return try HEVCHRDParameters.parse(
            reader: &reader,
            commonInfPresentFlag: commonInfPresent,
            maxNumSubLayersMinus1: maxSubLayersMinus1
        )
    }

    private static func basicCommon() -> HEVCHRDParameters.CommonInfo {
        HEVCHRDParameters.CommonInfo(
            nalHRDParametersPresentFlag: true,
            vclHRDParametersPresentFlag: false,
            bitRateScale: 0,
            cpbSizeScale: 0,
            initialCPBRemovalDelayLengthMinus1: 23,
            auCPBRemovalDelayLengthMinus1: 23,
            dpbOutputDelayLengthMinus1: 23
        )
    }

    private static func basicSubLayer() -> HEVCHRDParameters.SubLayerInfo {
        HEVCHRDParameters.SubLayerInfo(
            fixedPicRateGeneralFlag: true,
            elementalDurationInTCMinus1: 0,
            cpbCountMinus1: 0,
            nalSubLayerHRD: [
                HEVCHRDParameters.CPBEntry(
                    bitRateValueMinus1: 99,
                    cpbSizeValueMinus1: 199,
                    cbrFlag: true
                )
            ]
        )
    }

    @Test
    func nalHRDOnlyRoundTrip() throws {
        let hrd = HEVCHRDParameters(
            commonInfo: Self.basicCommon(),
            subLayers: [Self.basicSubLayer()]
        )
        let decoded = try Self.roundTrip(hrd)
        #expect(decoded == hrd)
    }

    @Test
    func vclHRDOnlyRoundTrip() throws {
        let common = HEVCHRDParameters.CommonInfo(
            nalHRDParametersPresentFlag: false,
            vclHRDParametersPresentFlag: true,
            initialCPBRemovalDelayLengthMinus1: 23,
            auCPBRemovalDelayLengthMinus1: 23,
            dpbOutputDelayLengthMinus1: 23
        )
        let sub = HEVCHRDParameters.SubLayerInfo(
            fixedPicRateGeneralFlag: true,
            elementalDurationInTCMinus1: 0,
            cpbCountMinus1: 0,
            vclSubLayerHRD: [
                HEVCHRDParameters.CPBEntry(
                    bitRateValueMinus1: 50,
                    cpbSizeValueMinus1: 100,
                    cbrFlag: false
                )
            ]
        )
        let hrd = HEVCHRDParameters(commonInfo: common, subLayers: [sub])
        let decoded = try Self.roundTrip(hrd)
        #expect(decoded == hrd)
    }

    @Test
    func nalPlusVCLRoundTrip() throws {
        let common = HEVCHRDParameters.CommonInfo(
            nalHRDParametersPresentFlag: true,
            vclHRDParametersPresentFlag: true,
            initialCPBRemovalDelayLengthMinus1: 23,
            auCPBRemovalDelayLengthMinus1: 23,
            dpbOutputDelayLengthMinus1: 23
        )
        let nalEntry = HEVCHRDParameters.CPBEntry(
            bitRateValueMinus1: 99, cpbSizeValueMinus1: 199, cbrFlag: true
        )
        let vclEntry = HEVCHRDParameters.CPBEntry(
            bitRateValueMinus1: 50, cpbSizeValueMinus1: 100, cbrFlag: false
        )
        let sub = HEVCHRDParameters.SubLayerInfo(
            fixedPicRateGeneralFlag: true,
            elementalDurationInTCMinus1: 0,
            cpbCountMinus1: 0,
            nalSubLayerHRD: [nalEntry],
            vclSubLayerHRD: [vclEntry]
        )
        let hrd = HEVCHRDParameters(commonInfo: common, subLayers: [sub])
        let decoded = try Self.roundTrip(hrd)
        #expect(decoded == hrd)
    }

    @Test
    func twoSubLayersRoundTrip() throws {
        let hrd = HEVCHRDParameters(
            commonInfo: Self.basicCommon(),
            subLayers: [Self.basicSubLayer(), Self.basicSubLayer()]
        )
        let decoded = try Self.roundTrip(hrd, maxSubLayersMinus1: 1)
        #expect(decoded == hrd)
    }

    @Test
    func subPicHRDParamsRoundTrip() throws {
        let common = HEVCHRDParameters.CommonInfo(
            nalHRDParametersPresentFlag: true,
            vclHRDParametersPresentFlag: false,
            subPicHRDParams: HEVCHRDParameters.SubPicHRDParams(
                tickDivisorMinus2: 10,
                duCPBRemovalDelayIncrementLengthMinus1: 4,
                subPicCPBParamsInPicTimingSEIFlag: false,
                dpbOutputDelayDULengthMinus1: 4
            ),
            cpbSizeDUScale: 1,
            initialCPBRemovalDelayLengthMinus1: 23,
            auCPBRemovalDelayLengthMinus1: 23,
            dpbOutputDelayLengthMinus1: 23
        )
        // With sub-pic params, CPB entries carry additional DU fields.
        let entry = HEVCHRDParameters.CPBEntry(
            bitRateValueMinus1: 99,
            cpbSizeValueMinus1: 199,
            cpbSizeDUValueMinus1: 5,
            bitRateDUValueMinus1: 10,
            cbrFlag: true
        )
        let sub = HEVCHRDParameters.SubLayerInfo(
            fixedPicRateGeneralFlag: true,
            elementalDurationInTCMinus1: 0,
            cpbCountMinus1: 0,
            nalSubLayerHRD: [entry]
        )
        let hrd = HEVCHRDParameters(commonInfo: common, subLayers: [sub])
        let decoded = try Self.roundTrip(hrd)
        #expect(decoded == hrd)
    }

    @Test
    func vbrEntryRoundTrip() throws {
        let common = HEVCHRDParameters.CommonInfo(
            nalHRDParametersPresentFlag: true,
            vclHRDParametersPresentFlag: false,
            initialCPBRemovalDelayLengthMinus1: 23,
            auCPBRemovalDelayLengthMinus1: 23,
            dpbOutputDelayLengthMinus1: 23
        )
        let entry = HEVCHRDParameters.CPBEntry(
            bitRateValueMinus1: 1000,
            cpbSizeValueMinus1: 2000,
            cbrFlag: false
        )
        let sub = HEVCHRDParameters.SubLayerInfo(
            fixedPicRateGeneralFlag: false,
            fixedPicRateWithinCVSFlag: false,
            lowDelayHRDFlag: false,
            cpbCountMinus1: 0,
            nalSubLayerHRD: [entry]
        )
        let hrd = HEVCHRDParameters(commonInfo: common, subLayers: [sub])
        let decoded = try Self.roundTrip(hrd)
        #expect(decoded == hrd)
    }

    @Test
    func multipleCPBEntriesRoundTrip() throws {
        var entries: [HEVCHRDParameters.CPBEntry] = []
        for i in 0..<3 {
            entries.append(
                HEVCHRDParameters.CPBEntry(
                    bitRateValueMinus1: UInt32(i * 100),
                    cpbSizeValueMinus1: UInt32(i * 200),
                    cbrFlag: i % 2 == 0
                )
            )
        }
        let sub = HEVCHRDParameters.SubLayerInfo(
            fixedPicRateGeneralFlag: true,
            elementalDurationInTCMinus1: 0,
            cpbCountMinus1: 2,
            nalSubLayerHRD: entries
        )
        let hrd = HEVCHRDParameters(commonInfo: Self.basicCommon(), subLayers: [sub])
        let decoded = try Self.roundTrip(hrd)
        #expect(decoded == hrd)
    }
}
