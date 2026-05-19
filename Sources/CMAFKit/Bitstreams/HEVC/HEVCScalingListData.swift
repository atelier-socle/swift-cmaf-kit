// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCScalingListData
//
// Reference: ITU-T H.265 §7.3.4 (scaling_list_data) + §7.4.5.

import Foundation

/// HEVC scaling-list data per ITU-T H.265 §7.3.4. Four "sizeID" rows
/// (0..3) holding 6 matrices each, except sizeID 3 which holds only 2.
public struct HEVCScalingListData: Sendable, Hashable, Equatable {

    /// One entry per `(sizeID, matrixID)` slot. The slot may either
    /// reference a previously-signalled matrix (`predMatrixID`) or
    /// carry an explicit delta sequence.
    public enum Entry: Sendable, Hashable, Equatable {
        case predicted(predMatrixID: UInt32)
        case explicit(dcCoefMinus8: Int32?, deltas: [Int32])
    }

    /// `entries[sizeID][matrixID]`. Outer length is 4; inner length is
    /// 6 for sizeID 0..2, 2 for sizeID 3.
    public let entries: [[Entry]]

    public init(entries: [[Entry]]) {
        precondition(entries.count == 4, "HEVCScalingListData requires 4 sizeID rows")
        for (sizeID, row) in entries.enumerated() {
            let expected = sizeID < 3 ? 6 : 2
            precondition(
                row.count == expected,
                "HEVCScalingListData row \(sizeID) requires \(expected) matrices"
            )
        }
        self.entries = entries
    }

    public static func parse(reader: inout BitReader) throws -> HEVCScalingListData {
        var rows: [[Entry]] = []
        rows.reserveCapacity(4)
        for sizeID in 0..<4 {
            let matrixCount = sizeID < 3 ? 6 : 2
            var row: [Entry] = []
            row.reserveCapacity(matrixCount)
            for matrixID in 0..<matrixCount {
                let predModeFlag = try reader.readBool()
                if !predModeFlag {
                    // scaling_list_pred_matrix_id_delta[sizeId][matrixId]
                    let delta = try reader.readUnsignedExpGolomb()
                    let pred = UInt32(matrixID) - delta * (sizeID == 3 ? 3 : 1)
                    row.append(.predicted(predMatrixID: pred))
                } else {
                    let coefCount = min(64, 1 << (4 + (sizeID << 1)))
                    var dcCoef: Int32?
                    if sizeID > 1 {
                        dcCoef = try reader.readSignedExpGolomb()
                    }
                    var deltas: [Int32] = []
                    deltas.reserveCapacity(coefCount)
                    for _ in 0..<coefCount {
                        deltas.append(try reader.readSignedExpGolomb())
                    }
                    row.append(.explicit(dcCoefMinus8: dcCoef, deltas: deltas))
                }
            }
            rows.append(row)
        }
        return HEVCScalingListData(entries: rows)
    }

    public func encode(to writer: inout BitWriter) {
        for (sizeID, row) in entries.enumerated() {
            for (matrixID, entry) in row.enumerated() {
                switch entry {
                case .predicted(let pred):
                    writer.writeBool(false)
                    let delta: UInt32
                    let denom: UInt32 = sizeID == 3 ? 3 : 1
                    if pred == UInt32(matrixID) {
                        delta = 0
                    } else {
                        delta = (UInt32(matrixID) - pred) / denom
                    }
                    writer.writeUnsignedExpGolomb(delta)
                case .explicit(let dcCoef, let deltas):
                    writer.writeBool(true)
                    if sizeID > 1 {
                        writer.writeSignedExpGolomb(dcCoef ?? 0)
                    }
                    for d in deltas {
                        writer.writeSignedExpGolomb(d)
                    }
                }
            }
        }
    }
}
