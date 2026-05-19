// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCScalingList / AVCScalingMatrix
//
// Reference: ITU-T H.264 §7.3.2.1.1.1 (scaling_list) + §7.4.2.1.1.1.
//
// A scaling list is either:
//   - the "use default" flag, in which case the decoder substitutes the
//     standard's default matrix; or
//   - an explicit list of `count` signed Exp-Golomb deltas, parsed
//     iteratively with a running "next scale" predictor (see §7.4.2.1.1.1
//     for the inference rule).
//
// The on-wire representation captures whichever of the two forms is
// signalled, byte-perfect on round-trip.

import Foundation

/// A single AVC scaling list (4x4 → 16 coefficients, 8x8 → 64).
public enum AVCScalingList: Sendable, Hashable, Equatable, Codable {
    /// The list is signalled as "use the standard's default matrix".
    case useDefault
    /// The list is signalled explicitly with the listed deltas.
    case explicit(deltas: [Int32])

    public static func parse(
        reader: inout BitReader,
        count: Int
    ) throws -> AVCScalingList {
        var deltas: [Int32] = []
        deltas.reserveCapacity(count)
        var lastScale: Int32 = 8
        var nextScale: Int32 = 8
        var useDefault = false
        for j in 0..<count {
            if nextScale != 0 {
                let delta = try reader.readSignedExpGolomb()
                deltas.append(delta)
                nextScale = (lastScale + delta + 256) & 0xFF
                useDefault = (j == 0 && nextScale == 0)
            }
            // Per §7.4.2.1.1.1: scalingList[scan(j)] = (nextScale == 0)
            //                                          ? lastScale
            //                                          : nextScale.
            // The on-wire value preserved is the delta sequence.
            if nextScale != 0 {
                lastScale = nextScale
            }
        }
        return useDefault ? .useDefault : .explicit(deltas: deltas)
    }

    public func encode(to writer: inout BitWriter, count: Int) {
        switch self {
        case .useDefault:
            // Emit a single delta that decodes to nextScale == 0 in the
            // first iteration: lastScale (8) + delta == 0 mod 256 →
            // delta = -8.
            writer.writeSignedExpGolomb(-8)
        case .explicit(let deltas):
            // Replay the same logic the parser uses to know when to
            // stop emitting deltas (nextScale becomes 0 → no more deltas).
            var lastScale: Int32 = 8
            var nextScale: Int32 = 8
            var emitted = 0
            for j in 0..<count {
                if nextScale != 0 {
                    let delta = emitted < deltas.count ? deltas[emitted] : 0
                    writer.writeSignedExpGolomb(delta)
                    emitted += 1
                    nextScale = (lastScale + delta + 256) & 0xFF
                    if j == 0 && nextScale == 0 {
                        // First delta drove nextScale to 0; the decoder
                        // will read this as "use default". Done.
                        return
                    }
                }
                if nextScale != 0 {
                    lastScale = nextScale
                }
            }
        }
    }
}

/// AVC sequence-level scaling matrix per ITU-T H.264 §7.4.2.1.1.
///
/// Holds up to eight 4x4 lists and up to twelve 8x8 lists (or eight
/// when `chroma_format_idc != 3`). Lists that are absent on the wire
/// (their `seq_scaling_list_present_flag` was 0) are represented by
/// `nil`.
public struct AVCScalingMatrix: Sendable, Hashable, Equatable, Codable {
    /// One entry per `seq_scaling_list_present_flag[i]`: `nil` if the
    /// flag was 0, the parsed list otherwise.
    public let lists4x4: [AVCScalingList?]
    /// 8x8 lists. Indexed by `(i - 6)` per the SPS loop.
    public let lists8x8: [AVCScalingList?]

    public init(lists4x4: [AVCScalingList?], lists8x8: [AVCScalingList?]) {
        self.lists4x4 = lists4x4
        self.lists8x8 = lists8x8
    }

    public static func parse(
        reader: inout BitReader,
        chromaFormatIDC: UInt32
    ) throws -> AVCScalingMatrix {
        let listCount = chromaFormatIDC != 3 ? 8 : 12
        var lists4x4: [AVCScalingList?] = []
        var lists8x8: [AVCScalingList?] = []
        lists4x4.reserveCapacity(6)
        lists8x8.reserveCapacity(listCount - 6)
        for i in 0..<listCount {
            let present = try reader.readBool()
            if !present {
                if i < 6 { lists4x4.append(nil) } else { lists8x8.append(nil) }
                continue
            }
            if i < 6 {
                let list = try AVCScalingList.parse(reader: &reader, count: 16)
                lists4x4.append(list)
            } else {
                let list = try AVCScalingList.parse(reader: &reader, count: 64)
                lists8x8.append(list)
            }
        }
        return AVCScalingMatrix(lists4x4: lists4x4, lists8x8: lists8x8)
    }

    public func encode(to writer: inout BitWriter) {
        for list in lists4x4 {
            writer.writeBool(list != nil)
            list?.encode(to: &writer, count: 16)
        }
        for list in lists8x8 {
            writer.writeBool(list != nil)
            list?.encode(to: &writer, count: 64)
        }
    }
}
