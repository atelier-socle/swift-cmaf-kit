// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCPPS3DExtension
//
// Reference: ITU-T H.265 §I.7.3.2.3.2 (pps_3d_extension).
//
// 3D-HEVC depth lookup table (DLT) extension. The number of DLT
// entries equals the depth-layer count derivable from the VPS;
// callers pass it via `depthLayerCount` (1 by default for streams
// that signal a single depth layer).

import Foundation

/// HEVC PPS 3D-HEVC extension per ITU-T H.265 §I.7.3.2.3.2.
public struct HEVCPPS3DExtension: Sendable, Hashable, Equatable {

    /// One DLT entry per depth layer.
    public struct DLTEntry: Sendable, Hashable, Equatable {
        public let dltFlag: Bool
        public let dltPredFlag: Bool?
        public let dltValFlagsPresentFlag: Bool?
        public let dltValueFlags: [Bool]?
        public let deltaDltValues: [UInt32]?

        public init(
            dltFlag: Bool,
            dltPredFlag: Bool? = nil,
            dltValFlagsPresentFlag: Bool? = nil,
            dltValueFlags: [Bool]? = nil,
            deltaDltValues: [UInt32]? = nil
        ) {
            self.dltFlag = dltFlag
            self.dltPredFlag = dltPredFlag
            self.dltValFlagsPresentFlag = dltValFlagsPresentFlag
            self.dltValueFlags = dltValueFlags
            self.deltaDltValues = deltaDltValues
        }
    }

    public let dltsPresentFlag: Bool
    public let dlts: [DLTEntry]?

    public init(dltsPresentFlag: Bool, dlts: [DLTEntry]? = nil) {
        precondition(
            dltsPresentFlag == (dlts != nil),
            "dlts presence must match dltsPresentFlag"
        )
        self.dltsPresentFlag = dltsPresentFlag
        self.dlts = dlts
    }

    public static func parse(
        reader: inout BitReader,
        depthLayerCount: Int = 1
    ) throws -> HEVCPPS3DExtension {
        let present = try reader.readBool()
        guard present else {
            return HEVCPPS3DExtension(dltsPresentFlag: false)
        }
        var entries: [DLTEntry] = []
        entries.reserveCapacity(depthLayerCount)
        for _ in 0..<depthLayerCount {
            let dltFlag = try reader.readBool()
            if !dltFlag {
                entries.append(DLTEntry(dltFlag: false))
                continue
            }
            let predFlag = try reader.readBool()
            // The body of dlt_layer() per the standard is bitstream
            // value-list parsing dependent on the depth layer's
            // bit-depth, which is itself signalled in the SPS / VPS.
            // CMAFKit captures the flag-level structure here; the
            // value-list body is decoded once VPS context is plumbed
            // through.
            entries.append(
                DLTEntry(
                    dltFlag: true,
                    dltPredFlag: predFlag,
                    dltValFlagsPresentFlag: nil,
                    dltValueFlags: nil,
                    deltaDltValues: nil
                )
            )
        }
        return HEVCPPS3DExtension(dltsPresentFlag: true, dlts: entries)
    }

    public func encode(to writer: inout BitWriter) {
        writer.writeBool(dltsPresentFlag)
        guard let entries = dlts else { return }
        for entry in entries {
            writer.writeBool(entry.dltFlag)
            if entry.dltFlag {
                writer.writeBool(entry.dltPredFlag ?? false)
            }
        }
    }
}
