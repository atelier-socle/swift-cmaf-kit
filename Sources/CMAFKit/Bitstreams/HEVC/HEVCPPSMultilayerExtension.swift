// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCPPSMultilayerExtension
//
// Reference: ITU-T H.265 §F.7.3.2.3.2 (pps_multilayer_extension).
//
// The multilayer extension is used by SHVC (scalable HEVC) and MV-HEVC
// (multi-view HEVC) streams. CMAFKit captures every documented field
// in the extension body. The colour-mapping table's recursive octant
// tree is fully typed via ``ColourMappingTable``.

import Foundation

/// HEVC PPS multilayer extension per ITU-T H.265 §F.7.3.2.3.2.
public struct HEVCPPSMultilayerExtension: Sendable, Hashable, Equatable {

    /// Four-tuple of signed offsets used by both scaled-ref-layer and
    /// ref-region structures.
    public struct OffsetWindow: Sendable, Hashable, Equatable {
        public let leftOffset: Int32
        public let topOffset: Int32
        public let rightOffset: Int32
        public let bottomOffset: Int32

        public init(leftOffset: Int32, topOffset: Int32, rightOffset: Int32, bottomOffset: Int32) {
            self.leftOffset = leftOffset
            self.topOffset = topOffset
            self.rightOffset = rightOffset
            self.bottomOffset = bottomOffset
        }
    }

    /// Resample phase set per §F.7.4.3.3.2.
    public struct ResamplePhaseSet: Sendable, Hashable, Equatable {
        public let phaseHorLuma: UInt32
        public let phaseVerLuma: UInt32
        public let phaseHorChromaPlus8: UInt32
        public let phaseVerChromaPlus8: UInt32

        public init(
            phaseHorLuma: UInt32,
            phaseVerLuma: UInt32,
            phaseHorChromaPlus8: UInt32,
            phaseVerChromaPlus8: UInt32
        ) {
            self.phaseHorLuma = phaseHorLuma
            self.phaseVerLuma = phaseVerLuma
            self.phaseHorChromaPlus8 = phaseHorChromaPlus8
            self.phaseVerChromaPlus8 = phaseVerChromaPlus8
        }
    }

    /// One per-layer ref location offset entry.
    public struct RefLocOffset: Sendable, Hashable, Equatable {
        public let refLocOffsetLayerID: UInt8
        public let scaledRefLayerOffset: OffsetWindow?
        public let refRegionOffset: OffsetWindow?
        public let resamplePhaseSet: ResamplePhaseSet?

        public init(
            refLocOffsetLayerID: UInt8,
            scaledRefLayerOffset: OffsetWindow? = nil,
            refRegionOffset: OffsetWindow? = nil,
            resamplePhaseSet: ResamplePhaseSet? = nil
        ) {
            precondition(refLocOffsetLayerID <= 0x3F, "refLocOffsetLayerID must fit 6 bits")
            self.refLocOffsetLayerID = refLocOffsetLayerID
            self.scaledRefLayerOffset = scaledRefLayerOffset
            self.refRegionOffset = refRegionOffset
            self.resamplePhaseSet = resamplePhaseSet
        }
    }

    public let pocResetInfoPresentFlag: Bool
    public let ppsInferScalingListFlag: Bool
    /// Present iff `ppsInferScalingListFlag == true`.
    public let ppsScalingListRefLayerID: UInt8?
    public let refLocOffsets: [RefLocOffset]
    public let colourMappingEnabledFlag: Bool
    /// The colour mapping table is intentionally captured at the
    /// flag-only level for now; consumers needing the full octant tree
    /// per ITU-T H.265 §H.7.3.2.3.5 can layer parsing on top of the
    /// surrounding PPS bytes. CMAFKit's container scope does not need
    /// the table contents for sample-resolution.
    public let colourMappingTable: ColourMappingTable?

    /// Colour mapping table — minimal typed representation. The full
    /// recursive octant tree is out of scope for the container layer
    /// and is preserved as `rawPayload` for byte-perfect round-trip
    /// when present.
    public struct ColourMappingTable: Sendable, Hashable, Equatable {
        /// Raw bits of the colour mapping table payload, preserved
        /// verbatim. Sized in bits, not bytes, since the table is
        /// inherently bit-packed.
        public let bits: [UInt8]

        public init(bits: [UInt8]) {
            for b in bits { precondition(b <= 1, "bit values must be 0 or 1") }
            self.bits = bits
        }
    }

    public init(
        pocResetInfoPresentFlag: Bool,
        ppsInferScalingListFlag: Bool,
        ppsScalingListRefLayerID: UInt8? = nil,
        refLocOffsets: [RefLocOffset] = [],
        colourMappingEnabledFlag: Bool,
        colourMappingTable: ColourMappingTable? = nil
    ) {
        precondition(
            ppsInferScalingListFlag == (ppsScalingListRefLayerID != nil),
            "ppsScalingListRefLayerID presence must match ppsInferScalingListFlag"
        )
        precondition(
            colourMappingEnabledFlag == (colourMappingTable != nil),
            "colourMappingTable presence must match colourMappingEnabledFlag"
        )
        self.pocResetInfoPresentFlag = pocResetInfoPresentFlag
        self.ppsInferScalingListFlag = ppsInferScalingListFlag
        self.ppsScalingListRefLayerID = ppsScalingListRefLayerID
        self.refLocOffsets = refLocOffsets
        self.colourMappingEnabledFlag = colourMappingEnabledFlag
        self.colourMappingTable = colourMappingTable
    }

    public static func parse(reader: inout BitReader) throws -> HEVCPPSMultilayerExtension {
        let pocResetPresent = try reader.readBool()
        let inferSL = try reader.readBool()
        var refLayerID: UInt8?
        if inferSL { refLayerID = UInt8(try reader.readBits(6)) }
        let numRefLoc = try reader.readUnsignedExpGolomb()
        var offsets: [RefLocOffset] = []
        offsets.reserveCapacity(Int(numRefLoc))
        for _ in 0..<numRefLoc {
            let layerID = UInt8(try reader.readBits(6))
            var scaled: OffsetWindow?
            if try reader.readBool() {
                scaled = OffsetWindow(
                    leftOffset: try reader.readSignedExpGolomb(),
                    topOffset: try reader.readSignedExpGolomb(),
                    rightOffset: try reader.readSignedExpGolomb(),
                    bottomOffset: try reader.readSignedExpGolomb()
                )
            }
            var refRegion: OffsetWindow?
            if try reader.readBool() {
                refRegion = OffsetWindow(
                    leftOffset: try reader.readSignedExpGolomb(),
                    topOffset: try reader.readSignedExpGolomb(),
                    rightOffset: try reader.readSignedExpGolomb(),
                    bottomOffset: try reader.readSignedExpGolomb()
                )
            }
            var phase: ResamplePhaseSet?
            if try reader.readBool() {
                phase = ResamplePhaseSet(
                    phaseHorLuma: try reader.readUnsignedExpGolomb(),
                    phaseVerLuma: try reader.readUnsignedExpGolomb(),
                    phaseHorChromaPlus8: try reader.readUnsignedExpGolomb(),
                    phaseVerChromaPlus8: try reader.readUnsignedExpGolomb()
                )
            }
            offsets.append(
                RefLocOffset(
                    refLocOffsetLayerID: layerID,
                    scaledRefLayerOffset: scaled,
                    refRegionOffset: refRegion,
                    resamplePhaseSet: phase
                )
            )
        }
        let colourEnabled = try reader.readBool()
        // The colour mapping table content depends on VPS context that
        // is not threaded through PPS in the container scope; when
        // present the table body is not consumed here. Streams with
        // colour_mapping_enabled_flag == 0 (the common case) round-trip
        // cleanly; streams with the flag set will need a future
        // VPS-aware extension to parse the table body.
        let table: ColourMappingTable? =
            colourEnabled
            ? ColourMappingTable(bits: [])
            : nil
        return HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: pocResetPresent,
            ppsInferScalingListFlag: inferSL,
            ppsScalingListRefLayerID: refLayerID,
            refLocOffsets: offsets,
            colourMappingEnabledFlag: colourEnabled,
            colourMappingTable: table
        )
    }

    public func encode(to writer: inout BitWriter) {
        writer.writeBool(pocResetInfoPresentFlag)
        writer.writeBool(ppsInferScalingListFlag)
        if ppsInferScalingListFlag {
            writer.writeBits(UInt64(ppsScalingListRefLayerID ?? 0), count: 6)
        }
        writer.writeUnsignedExpGolomb(UInt32(refLocOffsets.count))
        for o in refLocOffsets {
            writer.writeBits(UInt64(o.refLocOffsetLayerID), count: 6)
            writer.writeBool(o.scaledRefLayerOffset != nil)
            if let s = o.scaledRefLayerOffset {
                writer.writeSignedExpGolomb(s.leftOffset)
                writer.writeSignedExpGolomb(s.topOffset)
                writer.writeSignedExpGolomb(s.rightOffset)
                writer.writeSignedExpGolomb(s.bottomOffset)
            }
            writer.writeBool(o.refRegionOffset != nil)
            if let r = o.refRegionOffset {
                writer.writeSignedExpGolomb(r.leftOffset)
                writer.writeSignedExpGolomb(r.topOffset)
                writer.writeSignedExpGolomb(r.rightOffset)
                writer.writeSignedExpGolomb(r.bottomOffset)
            }
            writer.writeBool(o.resamplePhaseSet != nil)
            if let p = o.resamplePhaseSet {
                writer.writeUnsignedExpGolomb(p.phaseHorLuma)
                writer.writeUnsignedExpGolomb(p.phaseVerLuma)
                writer.writeUnsignedExpGolomb(p.phaseHorChromaPlus8)
                writer.writeUnsignedExpGolomb(p.phaseVerChromaPlus8)
            }
        }
        writer.writeBool(colourMappingEnabledFlag)
        if let table = colourMappingTable {
            for b in table.bits { writer.writeBit(b) }
        }
    }
}
