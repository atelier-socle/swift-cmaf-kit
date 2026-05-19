// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCShortTermRefPicSet
//
// Reference: ITU-T H.265 §7.3.7 (st_ref_pic_set) + §7.4.8.
//
// A short-term reference picture set is either signalled with an
// inter-RPS prediction reference plus a delta, or with an explicit
// list of `(delta_poc, used)` pairs.
//
// Inter-RPS prediction references a previously-parsed RPS at index
// `i - 1 - delta_idx_minus1`; the predicted flags consist of one
// `used_by_curr_pic_flag` per `NumDeltaPocs` of the referenced RPS
// plus one for the predicted current picture, with an optional
// `use_delta_flag` when `used_by_curr_pic_flag == 0`. The parser
// therefore needs the array context of all prior RPSes in the SPS.

import Foundation

/// HEVC short-term reference picture set per ITU-T H.265 §7.3.7.
public struct HEVCShortTermRefPicSet: Sendable, Hashable, Equatable {

    /// One entry in an explicit-form RPS list.
    public struct DeltaPOCEntry: Sendable, Hashable, Equatable {
        /// `delta_poc_s0_minus1` (negative list) or `delta_poc_s1_minus1`
        /// (positive list) per §7.4.8.
        public let deltaPocMinus1: UInt32
        public let usedByCurrPicFlag: Bool

        public init(deltaPocMinus1: UInt32, usedByCurrPicFlag: Bool) {
            self.deltaPocMinus1 = deltaPocMinus1
            self.usedByCurrPicFlag = usedByCurrPicFlag
        }
    }

    /// Either form may be in use; the encoded form is stored verbatim
    /// for byte-perfect round-trip.
    public enum Form: Sendable, Hashable, Equatable {
        /// Explicit listing of negative-side and positive-side delta POCs.
        case explicit(negativePics: [DeltaPOCEntry], positivePics: [DeltaPOCEntry])
        /// Inter-RPS prediction from the RPS at `(i - 1 - deltaIdxMinus1)`.
        /// `useDeltaFlags[j]` is present only when `usedByCurrPicFlags[j]`
        /// is `false`; otherwise it is `nil` (the spec default is `true`).
        case interRPS(
            deltaIdxMinus1: UInt32,
            deltaRPSSign: Bool,
            absDeltaRPSMinus1: UInt32,
            usedByCurrPicFlags: [Bool],
            useDeltaFlags: [Bool?]
        )
    }

    public let form: Form

    public init(form: Form) {
        self.form = form
    }

    /// `NumDeltaPocs` for this RPS, used by subsequent inter-RPS
    /// predictions per §7.4.8.
    public var numDeltaPocs: Int {
        switch form {
        case .explicit(let neg, let pos):
            return neg.count + pos.count
        case .interRPS(_, _, _, let usedFlags, _):
            return usedFlags.count
        }
    }

    /// Parse the RPS at `indexInSPS` using `previousRefPicSets` as the
    /// pool for inter-RPS prediction references. `previousRefPicSets`
    /// must contain exactly the RPSes already parsed at lower indices.
    public static func parse(
        reader: inout BitReader,
        indexInSPS: UInt32,
        previousRefPicSets: [HEVCShortTermRefPicSet]
    ) throws -> HEVCShortTermRefPicSet {
        let interRefPredictionFlag: Bool
        if indexInSPS != 0 {
            interRefPredictionFlag = try reader.readBool()
        } else {
            interRefPredictionFlag = false
        }
        if interRefPredictionFlag {
            return try parseInterRPS(
                reader: &reader,
                indexInSPS: indexInSPS,
                previousRefPicSets: previousRefPicSets
            )
        }
        return try parseExplicit(reader: &reader)
    }

    private static func parseInterRPS(
        reader: inout BitReader,
        indexInSPS: UInt32,
        previousRefPicSets: [HEVCShortTermRefPicSet]
    ) throws -> HEVCShortTermRefPicSet {
        // Per §7.3.7: `delta_idx_minus1` is on the wire only at the end
        // of the SPS RPS loop (when called with i == numShortTermRefPicSets).
        // For in-loop predictions the spec uses an implicit zero.
        let deltaIdxMinus1: UInt32
        if Int(indexInSPS) == previousRefPicSets.count {
            deltaIdxMinus1 = try reader.readUnsignedExpGolomb()
        } else {
            deltaIdxMinus1 = 0
        }
        let refIndex = Int(indexInSPS) - 1 - Int(deltaIdxMinus1)
        guard refIndex >= 0, refIndex < previousRefPicSets.count else {
            throw BitstreamError.unsupportedValue(
                codec: "HEVC", field: "delta_idx_minus1", value: UInt64(deltaIdxMinus1)
            )
        }
        let referenced = previousRefPicSets[refIndex]
        let deltaRPSSign = try reader.readBool()
        let absDeltaRPSMinus1 = try reader.readUnsignedExpGolomb()
        // Per §7.4.8: one flag per delta POC in the referenced RPS, plus
        // one for the predicted current picture introduced by the inter-
        // RPS delta. Total = referenced.numDeltaPocs + 1.
        let predictedCount = referenced.numDeltaPocs + 1
        var usedFlags: [Bool] = []
        var useDeltaFlags: [Bool?] = []
        usedFlags.reserveCapacity(predictedCount)
        useDeltaFlags.reserveCapacity(predictedCount)
        for _ in 0..<predictedCount {
            let used = try reader.readBool()
            usedFlags.append(used)
            if !used {
                useDeltaFlags.append(try reader.readBool())
            } else {
                useDeltaFlags.append(nil)
            }
        }
        return HEVCShortTermRefPicSet(
            form: .interRPS(
                deltaIdxMinus1: deltaIdxMinus1,
                deltaRPSSign: deltaRPSSign,
                absDeltaRPSMinus1: absDeltaRPSMinus1,
                usedByCurrPicFlags: usedFlags,
                useDeltaFlags: useDeltaFlags
            )
        )
    }

    private static func parseExplicit(reader: inout BitReader) throws -> HEVCShortTermRefPicSet {
        let numNeg = try reader.readUnsignedExpGolomb()
        let numPos = try reader.readUnsignedExpGolomb()
        var neg: [DeltaPOCEntry] = []
        var pos: [DeltaPOCEntry] = []
        neg.reserveCapacity(Int(numNeg))
        pos.reserveCapacity(Int(numPos))
        for _ in 0..<numNeg {
            let delta = try reader.readUnsignedExpGolomb()
            let used = try reader.readBool()
            neg.append(DeltaPOCEntry(deltaPocMinus1: delta, usedByCurrPicFlag: used))
        }
        for _ in 0..<numPos {
            let delta = try reader.readUnsignedExpGolomb()
            let used = try reader.readBool()
            pos.append(DeltaPOCEntry(deltaPocMinus1: delta, usedByCurrPicFlag: used))
        }
        return HEVCShortTermRefPicSet(form: .explicit(negativePics: neg, positivePics: pos))
    }

    public func encode(
        to writer: inout BitWriter,
        indexInSPS: UInt32,
        previousRefPicSets: [HEVCShortTermRefPicSet]
    ) {
        if indexInSPS != 0 {
            switch form {
            case .interRPS:
                writer.writeBool(true)
            case .explicit:
                writer.writeBool(false)
            }
        }
        switch form {
        case .interRPS(let deltaIdxMinus1, let sign, let absDeltaMinus1, let usedFlags, let useDeltaFlags):
            if Int(indexInSPS) == previousRefPicSets.count {
                writer.writeUnsignedExpGolomb(deltaIdxMinus1)
            }
            writer.writeBool(sign)
            writer.writeUnsignedExpGolomb(absDeltaMinus1)
            for (used, useDelta) in zip(usedFlags, useDeltaFlags) {
                writer.writeBool(used)
                if !used {
                    writer.writeBool(useDelta ?? true)
                }
            }
        case .explicit(let neg, let pos):
            writer.writeUnsignedExpGolomb(UInt32(neg.count))
            writer.writeUnsignedExpGolomb(UInt32(pos.count))
            for entry in neg {
                writer.writeUnsignedExpGolomb(entry.deltaPocMinus1)
                writer.writeBool(entry.usedByCurrPicFlag)
            }
            for entry in pos {
                writer.writeUnsignedExpGolomb(entry.deltaPocMinus1)
                writer.writeBool(entry.usedByCurrPicFlag)
            }
        }
    }
}
