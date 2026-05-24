// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCMultiLayerScalingListData")
struct HEVCMultiLayerScalingListDataTests {

    // MARK: - Fixtures

    /// Canonical all-predicted scaling list with `predMatrixID == matrixID`
    /// (every slot encodes as `delta = 0`, round-trips byte-identical for
    /// every `sizeID`).
    ///
    /// Mirrors the pattern in `HEVCScalingListDataTests.allPredicted()`.
    private static func minimalScalingList() -> HEVCScalingListData {
        var rows: [[HEVCScalingListData.Entry]] = []
        for sizeID in 0..<4 {
            let count = sizeID < 3 ? 6 : 2
            var row: [HEVCScalingListData.Entry] = []
            for i in 0..<count {
                row.append(.predicted(predMatrixID: UInt32(i)))
            }
            rows.append(row)
        }
        return HEVCScalingListData(entries: rows)
    }

    /// Variant scaling list — same shape as `minimalScalingList` except
    /// the first entry of row 0 (sizeID=0) carries an explicit 16-coef
    /// delta block of zeros (the canonical "explicit" form for sizeID=0
    /// per ITU-T H.265 §7.4.5).
    private static func variantScalingList() -> HEVCScalingListData {
        var rows: [[HEVCScalingListData.Entry]] = []
        var row0: [HEVCScalingListData.Entry] = [
            .explicit(dcCoefMinus8: nil, deltas: Array(repeating: Int32(0), count: 16))
        ]
        for i in 1..<6 {
            row0.append(.predicted(predMatrixID: UInt32(i)))
        }
        rows.append(row0)
        for sizeID in 1..<4 {
            let count = sizeID < 3 ? 6 : 2
            var row: [HEVCScalingListData.Entry] = []
            for i in 0..<count {
                row.append(.predicted(predMatrixID: UInt32(i)))
            }
            rows.append(row)
        }
        return HEVCScalingListData(entries: rows)
    }

    // MARK: - Round-trip

    @Test
    func roundTripEmptyOverrideSet() throws {
        let original = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: []
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCMultiLayerScalingListData.parse(
            bitstream: &reader,
            baseScalingList: Self.minimalScalingList(),
            layerCount: 0
        )
        #expect(recovered == original)
    }

    @Test
    func roundTripOneOverride() throws {
        let original = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: [Self.variantScalingList()]
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCMultiLayerScalingListData.parse(
            bitstream: &reader,
            baseScalingList: Self.minimalScalingList(),
            layerCount: 1
        )
        #expect(recovered == original)
        #expect(recovered.layerSpecificScalingList.count == 1)
    }

    @Test
    func roundTripTwoOverrides() throws {
        let original = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: [
                Self.variantScalingList(),
                Self.minimalScalingList()
            ]
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCMultiLayerScalingListData.parse(
            bitstream: &reader,
            baseScalingList: Self.minimalScalingList(),
            layerCount: 2
        )
        #expect(recovered == original)
    }

    @Test
    func sharedScalingListEmptyOverrides() {
        let shared = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList()
        )
        #expect(shared.layerSpecificScalingList.isEmpty)
    }

    @Test
    func layerCountZeroSkipsCheck() throws {
        // layerCount: 0 means "no enforcement" — any parsed count is accepted.
        let original = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: [Self.variantScalingList()]
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCMultiLayerScalingListData.parse(
            bitstream: &reader,
            baseScalingList: Self.minimalScalingList(),
            layerCount: 0
        )
        #expect(recovered.layerSpecificScalingList.count == 1)
    }

    // MARK: - Error paths

    @Test
    func layerCountMismatchThrows() throws {
        let original = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: [Self.variantScalingList()]
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        #expect(
            throws: HEVCMultiLayerScalingListDataError.layerCountMismatch(
                declared: 5, parsed: 1
            )
        ) {
            _ = try HEVCMultiLayerScalingListData.parse(
                bitstream: &reader,
                baseScalingList: Self.minimalScalingList(),
                layerCount: 5
            )
        }
    }

    // MARK: - Equatable / Hashable

    @Test
    func equatableSameInput() {
        let a = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: [Self.variantScalingList()]
        )
        let b = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: [Self.variantScalingList()]
        )
        #expect(a == b)
    }

    @Test
    func hashableSameInput() {
        let a = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: [Self.variantScalingList()]
        )
        let b = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: [Self.variantScalingList()]
        )
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }

    @Test
    func equatableDifferentOverrideCount() {
        let a = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: []
        )
        let b = HEVCMultiLayerScalingListData(
            scalingListData: Self.minimalScalingList(),
            layerSpecificScalingList: [Self.variantScalingList()]
        )
        #expect(a != b)
    }
}
