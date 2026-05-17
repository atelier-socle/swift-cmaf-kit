// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("NCLXColorInformation")
struct NCLXColorInformationTests {

    @Test
    func roundTripBT709() throws {
        let original = NCLXColorInformation(
            colorPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709,
            fullRangeFlag: .limited
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try NCLXColorInformation.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func roundTripPQHDR() throws {
        let original = NCLXColorInformation(
            colorPrimaries: .bt2020,
            transferCharacteristics: .smpteST2084_PQ,
            matrixCoefficients: .bt2020NCL,
            fullRangeFlag: .full
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try NCLXColorInformation.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func roundTripHLG() throws {
        let original = NCLXColorInformation(
            colorPrimaries: .bt2020,
            transferCharacteristics: .aribSTDB67_HLG,
            matrixCoefficients: .bt2020NCL,
            fullRangeFlag: .limited
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try NCLXColorInformation.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func parseFromKnownHexBT709Limited() throws {
        let bytes = Data(hex: "00 01 00 01 00 01 00")
        var reader = BinaryReader(bytes)
        let decoded = try NCLXColorInformation.parse(reader: &reader)
        #expect(decoded.colorPrimaries == .bt709)
        #expect(decoded.transferCharacteristics == .bt709)
        #expect(decoded.matrixCoefficients == .bt709)
        #expect(decoded.fullRangeFlag == .limited)
    }

    @Test
    func parseFromKnownHexBT2020FullRange() throws {
        let bytes = Data(hex: "00 09 00 10 00 09 80")
        var reader = BinaryReader(bytes)
        let decoded = try NCLXColorInformation.parse(reader: &reader)
        #expect(decoded.colorPrimaries == .bt2020)
        #expect(decoded.transferCharacteristics == .smpteST2084_PQ)
        #expect(decoded.matrixCoefficients == .bt2020NCL)
        #expect(decoded.fullRangeFlag == .full)
    }

    @Test
    func unknownPrimariesThrows() async throws {
        let bytes = Data(hex: "00 63 00 01 00 01 00")
        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try NCLXColorInformation.parse(reader: &reader)
        }
    }

    @Test
    func unknownTransferThrows() async throws {
        let bytes = Data(hex: "00 01 00 63 00 01 00")
        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try NCLXColorInformation.parse(reader: &reader)
        }
    }

    @Test
    func unknownMatrixThrows() async throws {
        let bytes = Data(hex: "00 01 00 01 00 63 00")
        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try NCLXColorInformation.parse(reader: &reader)
        }
    }

    @Test
    func reservedBitsIgnoredOnParse() throws {
        // fullRange = 1, lower 7 bits = 0x7F (should be ignored)
        let bytes = Data(hex: "00 01 00 01 00 01 FF")
        var reader = BinaryReader(bytes)
        let decoded = try NCLXColorInformation.parse(reader: &reader)
        #expect(decoded.fullRangeFlag == .full)
    }

    @Test
    func encodingLimitedRangeProducesZeroByte() {
        let nclx = NCLXColorInformation(
            colorPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709,
            fullRangeFlag: .limited
        )
        var writer = BinaryWriter()
        nclx.encode(to: &writer)
        #expect(writer.data.last == 0x00)
    }

    @Test
    func encodingFullRangeProducesHighBitOnly() {
        let nclx = NCLXColorInformation(
            colorPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709,
            fullRangeFlag: .full
        )
        var writer = BinaryWriter()
        nclx.encode(to: &writer)
        #expect(writer.data.last == 0x80)
    }
}
