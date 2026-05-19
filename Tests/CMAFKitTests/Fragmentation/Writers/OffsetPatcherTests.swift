// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("OffsetPatcher")
struct OffsetPatcherTests {

    @Test
    func noPatchesLeavesBufferUnchanged() {
        let patcher = OffsetPatcher()
        var bytes = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let original = bytes
        patcher.apply(to: &bytes)
        #expect(bytes == original)
        #expect(patcher.count == 0)
    }

    @Test
    func single32BitPatchWritesBigEndian() {
        var patcher = OffsetPatcher()
        var bytes = Data([0x00, 0x00, 0x00, 0x00, 0xFF])
        patcher.record32(at: 0, value: 0x1234_5678)
        patcher.apply(to: &bytes)
        #expect(bytes == Data([0x12, 0x34, 0x56, 0x78, 0xFF]))
    }

    @Test
    func single64BitPatchWritesBigEndian() {
        var patcher = OffsetPatcher()
        var bytes = Data([0xAA, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xBB])
        patcher.record64(at: 1, value: 0x0102_0304_0506_0708)
        patcher.apply(to: &bytes)
        #expect(
            bytes
                == Data([
                    0xAA, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0xBB
                ]))
    }

    @Test
    func multiplePatchesAppliedInOrder() {
        var patcher = OffsetPatcher()
        var bytes = Data(repeating: 0, count: 16)
        patcher.record32(at: 0, value: 0xDEAD_BEEF)
        patcher.record32(at: 4, value: 0xCAFE_BABE)
        patcher.record32(at: 8, value: 0xFEED_FACE)
        patcher.apply(to: &bytes)
        #expect(
            bytes
                == Data([
                    0xDE, 0xAD, 0xBE, 0xEF,
                    0xCA, 0xFE, 0xBA, 0xBE,
                    0xFE, 0xED, 0xFA, 0xCE,
                    0x00, 0x00, 0x00, 0x00
                ]))
    }

    @Test
    func patchAtEndOfBuffer() {
        var patcher = OffsetPatcher()
        var bytes = Data([0x00, 0x00, 0x00, 0x00])
        patcher.record32(at: 0, value: 0x4142_4344)
        patcher.apply(to: &bytes)
        #expect(bytes == Data([0x41, 0x42, 0x43, 0x44]))
    }

    @Test
    func appliedReturnsCopyWithoutMutatingSource() {
        var patcher = OffsetPatcher()
        let original = Data(repeating: 0, count: 8)
        patcher.record32(at: 0, value: 0x1234_5678)
        let result = patcher.applied(to: original)
        #expect(result != original)
        #expect(original == Data(repeating: 0, count: 8))
    }

    @Test
    func zeroValuePatchAcceptedAndAppliedExplicitly() {
        var patcher = OffsetPatcher()
        var bytes = Data([0xFF, 0xFF, 0xFF, 0xFF])
        patcher.record32(at: 0, value: 0)
        patcher.apply(to: &bytes)
        #expect(bytes == Data([0x00, 0x00, 0x00, 0x00]))
    }

    @Test
    func patchCountReflectsRecords() {
        var patcher = OffsetPatcher()
        patcher.record32(at: 0, value: 0x01)
        patcher.record64(at: 4, value: 0x02)
        #expect(patcher.count == 2)
    }

    @Test
    func mixedWidthPatchesIndependent() {
        var patcher = OffsetPatcher()
        var bytes = Data(repeating: 0, count: 12)
        patcher.record32(at: 0, value: 0xAA_BB_CC_DD)
        patcher.record64(at: 4, value: 0x1234_5678_9ABC_DEF0)
        patcher.apply(to: &bytes)
        #expect(
            bytes
                == Data([
                    0xAA, 0xBB, 0xCC, 0xDD,
                    0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0
                ]))
    }

    @Test
    func reapplicationIsIdempotent() {
        var patcher = OffsetPatcher()
        var bytes = Data(repeating: 0, count: 8)
        patcher.record32(at: 0, value: 0xAA_BB_CC_DD)
        patcher.apply(to: &bytes)
        let firstResult = bytes
        patcher.apply(to: &bytes)
        #expect(bytes == firstResult)
    }
}
