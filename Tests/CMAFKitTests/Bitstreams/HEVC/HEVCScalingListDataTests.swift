// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCScalingListData")
struct HEVCScalingListDataTests {

    private static func roundTrip(_ data: HEVCScalingListData) throws -> HEVCScalingListData {
        var writer = BitWriter()
        data.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        return try HEVCScalingListData.parse(reader: &reader)
    }

    /// Build an all-predicted scaling list (every matrix references the
    /// first one with delta 0).
    private static func allPredicted() -> HEVCScalingListData {
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

    @Test
    func allPredictedRoundTrip() throws {
        let data = Self.allPredicted()
        let decoded = try Self.roundTrip(data)
        #expect(decoded.entries.count == 4)
    }

    @Test
    func explicit4x4MatrixRoundTrip() throws {
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
        let data = HEVCScalingListData(entries: rows)
        let decoded = try Self.roundTrip(data)
        if case .explicit(_, let deltas) = decoded.entries[0][0] {
            #expect(deltas.count == 16)
        } else {
            Issue.record("Expected explicit form")
        }
    }

    @Test
    func explicit8x8MatrixRoundTrip() throws {
        var rows = Self.allPredicted().entries
        rows[1][0] = .explicit(
            dcCoefMinus8: nil,
            deltas: Array(repeating: Int32(0), count: 64)
        )
        let data = HEVCScalingListData(entries: rows)
        let decoded = try Self.roundTrip(data)
        if case .explicit(_, let deltas) = decoded.entries[1][0] {
            #expect(deltas.count == 64)
        } else {
            Issue.record("Expected explicit form")
        }
    }

    @Test
    func explicit16x16WithDCCoefRoundTrip() throws {
        var rows = Self.allPredicted().entries
        // sizeID == 2 → 16x16 matrix, has DC coefficient.
        rows[2][0] = .explicit(
            dcCoefMinus8: 4,
            deltas: Array(repeating: Int32(0), count: 64)
        )
        let data = HEVCScalingListData(entries: rows)
        let decoded = try Self.roundTrip(data)
        if case .explicit(let dcCoef, _) = decoded.entries[2][0] {
            #expect(dcCoef == 4)
        } else {
            Issue.record("Expected explicit form")
        }
    }

    @Test
    func explicit32x32WithDCCoefRoundTrip() throws {
        var rows = Self.allPredicted().entries
        // sizeID == 3 → 32x32 matrix, has DC coefficient.
        rows[3][0] = .explicit(
            dcCoefMinus8: 8,
            deltas: Array(repeating: Int32(0), count: 64)
        )
        let data = HEVCScalingListData(entries: rows)
        let decoded = try Self.roundTrip(data)
        if case .explicit(let dcCoef, _) = decoded.entries[3][0] {
            #expect(dcCoef == 8)
        } else {
            Issue.record("Expected explicit form")
        }
    }

    @Test
    func mixedFormsRoundTrip() throws {
        var rows: [[HEVCScalingListData.Entry]] = []
        var row0: [HEVCScalingListData.Entry] = []
        for i in 0..<6 {
            if i == 0 {
                row0.append(.explicit(dcCoefMinus8: nil, deltas: Array(repeating: Int32(0), count: 16)))
            } else {
                row0.append(.predicted(predMatrixID: UInt32(i)))
            }
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
        let data = HEVCScalingListData(entries: rows)
        let decoded = try Self.roundTrip(data)
        #expect(decoded.entries.count == 4)
        #expect(decoded.entries[3].count == 2)
    }
}
