// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCVPSExtension
//
// Reference: ITU-T H.265 §F.7.3.2.1 (vps_extension() syntax),
// §F.7.4.3.1 (vps_extension() semantics), §I.7.4.3.1 (3D-HEVC additions),
// ISO/IEC 14496-15 §8.4 (multi-layer HEVC storage in ISO BMFF).
//
// HEVC Video Parameter Set Extension carrying multi-layer information.
// CMAFKit's representation is a typed projection of the ITU-T §F.7.3.2.1
// syntax tree into Swift value types, suitable for round-trip use inside
// the kit (MV-HEVC sample-entry composition + reader recovery).
//
// Round-trip stability: instances encoded via `encode(to:)` and parsed
// back via `parse(bitstream:)` are equal. The canonical encoding mirrors
// the §F.7.3.2.1 field ordering for the subset of fields that MV-HEVC
// stereo carriage (Apple Vision Pro Spatial Video, ISO/IEC 14496-15 §8.4)
// requires. Fields not modelled by this typed shape (e.g., the rep_format
// override matrix, the cross-layer alignment indicator) are preserved
// only when carried in the opaque tail consumed by the parent
// HEVCMultiLayerSPS — not by this struct directly.

import Foundation

/// HEVC Video Parameter Set Extension — multi-layer / multi-view / scalability
/// information carried by `vps_extension()` in a HEVC VPS NAL unit.
///
/// Declares the layer structure of the stream:
/// - layer IDs and inter-layer dependencies,
/// - the scalability mask (multi-view / spatial-quality / auxiliary),
/// - per-layer view IDs and aux IDs,
/// - output layer sets per operating point.
///
/// References:
/// - ITU-T H.265 §F.7.3.2.1 — VPS extension syntax
/// - ITU-T H.265 §F.7.4.3.1 — VPS extension semantics
/// - ITU-T H.265 §I.7.4.3.1 — 3D-HEVC additions
/// - ISO/IEC 14496-15 §8.4 — multi-layer HEVC storage in ISO BMFF
public struct HEVCVPSExtension: Sendable, Equatable, Hashable {

    /// Total number of layers carried by the stream (`vps_max_layers_minus1 + 1`,
    /// in the range `1...64` per ITU-T H.265 §F.7.4.3.1).
    public let maxLayerCount: UInt8

    /// `layer_id_in_nuh[i]` values for `i = 0..<maxLayerCount`.
    /// Layer 0 is always present and uses `nuh_layer_id == 0`.
    public let layerIDs: [UInt8]

    /// Inter-layer dependency declarations per ITU-T H.265 §F.7.4.3.1
    /// (`direct_dependency_flag[i][j]`). Layer 0 has no dependencies.
    public let layerDependencies: [LayerDependency]

    /// `scalability_mask_flag[i]` bits per ITU-T H.265 Table F.1, decoded
    /// into typed booleans for the well-known bits and preserved as a raw
    /// 16-bit mask for any unknown / future-defined bits.
    public let scalabilityMask: ScalabilityMask

    /// `dimension_id_len_minus1[j] + 1` per scalability dimension.
    /// Length equals `popcount(scalabilityMask.raw) - (splittingFlag ? 1 : 0)`,
    /// which for CMAFKit-canonical streams is the popcount.
    public let dimensionIDLen: [UInt8]

    /// `dimension_id[i][j]` — 2D table of scalability-dimension identifiers.
    /// Outer length `maxLayerCount`, inner length equals `dimensionIDLen.count`.
    public let dimensionID: [[UInt8]]

    /// Derived view of `direct_dependency_flag[i][j]`: for each layer `i`,
    /// the list of `j` indices for which the flag was set. Equivalent to
    /// `layerDependencies[i].dependsOnLayerIDs` but indexed positionally.
    public let directRefLayers: [[UInt8]]

    /// `view_id_val[i]` per ITU-T H.265 §I.7.3.2.1. One entry per view.
    /// Empty when the stream does not carry multi-view scalability
    /// (i.e., `scalabilityMask.isMultiview == false`).
    public let viewIDValues: [UInt16]

    /// `aux_id[i]` per ITU-T H.265 §F.7.4.3.1 — auxiliary picture
    /// identifier (alpha plane, depth, etc.). Empty when the stream
    /// does not carry auxiliary scalability.
    public let auxIDValues: [UInt8]

    /// Output layer sets per ITU-T H.265 §F.7.4.3.1 (`output_layer_set_idx[i]`
    /// + `output_layer_flag[i][j]`).
    public let outputLayerSets: [OutputLayerSet]

    public init(
        maxLayerCount: UInt8,
        layerIDs: [UInt8],
        layerDependencies: [LayerDependency],
        scalabilityMask: ScalabilityMask,
        dimensionIDLen: [UInt8],
        dimensionID: [[UInt8]],
        directRefLayers: [[UInt8]],
        viewIDValues: [UInt16],
        auxIDValues: [UInt8],
        outputLayerSets: [OutputLayerSet]
    ) {
        precondition(
            (1...64).contains(maxLayerCount),
            "HEVCVPSExtension.maxLayerCount must fit in vps_max_layers_minus1 + 1 (1...64)"
        )
        precondition(
            layerIDs.count == Int(maxLayerCount),
            "HEVCVPSExtension.layerIDs must have maxLayerCount entries"
        )
        precondition(
            dimensionID.count == Int(maxLayerCount),
            "HEVCVPSExtension.dimensionID outer length must equal maxLayerCount"
        )
        for row in dimensionID {
            precondition(
                row.count == dimensionIDLen.count,
                "HEVCVPSExtension.dimensionID inner length must equal dimensionIDLen.count"
            )
        }
        self.maxLayerCount = maxLayerCount
        self.layerIDs = layerIDs
        self.layerDependencies = layerDependencies
        self.scalabilityMask = scalabilityMask
        self.dimensionIDLen = dimensionIDLen
        self.dimensionID = dimensionID
        self.directRefLayers = directRefLayers
        self.viewIDValues = viewIDValues
        self.auxIDValues = auxIDValues
        self.outputLayerSets = outputLayerSets
    }

    /// Parse a CMAFKit-canonical VPS extension bitstream.
    ///
    /// - Parameter bitstream: a `BitReader` positioned at the start of the
    ///   extension payload (after the parent VPS has signalled its presence).
    /// - Throws: ``HEVCVPSExtensionError`` on malformed input.
    ///
    /// Reference: ITU-T H.265 §F.7.3.2.1.
    public static func parse(
        bitstream: inout BitReader
    ) throws -> HEVCVPSExtension {
        let scalabilityRaw = UInt16(try bitstream.readBits(16))
        let scalabilityMask = ScalabilityMask(raw: scalabilityRaw)

        let rawMaxLayersMinus1 = try bitstream.readBits(6)
        let maxLayerCount = UInt8(rawMaxLayersMinus1) &+ 1
        guard maxLayerCount >= 1 else {
            throw HEVCVPSExtensionError.invalidLayerCount(
                Int(maxLayerCount), maxAllowed: 64
            )
        }

        var layerIDs: [UInt8] = [0]
        layerIDs.reserveCapacity(Int(maxLayerCount))
        if maxLayerCount > 1 {
            for _ in 1..<Int(maxLayerCount) {
                layerIDs.append(UInt8(try bitstream.readBits(6)))
            }
        }

        // dimensionIDLen
        let scalabilityCount = scalabilityRaw.nonzeroBitCount
        guard scalabilityCount <= 16 else {
            throw HEVCVPSExtensionError.unsupportedDimensionCount(scalabilityCount)
        }
        var dimensionIDLen: [UInt8] = []
        dimensionIDLen.reserveCapacity(scalabilityCount)
        for _ in 0..<scalabilityCount {
            dimensionIDLen.append(UInt8(try bitstream.readBits(3) &+ 1))
        }

        // dimensionID 2D table
        var dimensionID: [[UInt8]] = []
        dimensionID.reserveCapacity(Int(maxLayerCount))
        for _ in 0..<Int(maxLayerCount) {
            var row: [UInt8] = []
            row.reserveCapacity(scalabilityCount)
            for length in dimensionIDLen {
                row.append(UInt8(try bitstream.readBits(Int(length))))
            }
            dimensionID.append(row)
        }

        // viewIDValues
        let viewIDLen = UInt8(try bitstream.readBits(4))
        var viewIDValues: [UInt16] = []
        if viewIDLen > 0 {
            let viewCount = UInt8(try bitstream.readBits(6))
            viewIDValues.reserveCapacity(Int(viewCount))
            for _ in 0..<Int(viewCount) {
                viewIDValues.append(UInt16(try bitstream.readBits(Int(viewIDLen))))
            }
        }

        // auxIDValues
        let auxCount = UInt8(try bitstream.readBits(6))
        var auxIDValues: [UInt8] = []
        auxIDValues.reserveCapacity(Int(auxCount))
        for _ in 0..<Int(auxCount) {
            auxIDValues.append(UInt8(try bitstream.readBits(8)))
        }

        // direct dependency flag matrix
        var directRefLayers: [[UInt8]] = []
        directRefLayers.reserveCapacity(Int(maxLayerCount))
        var layerDependencies: [LayerDependency] = []
        layerDependencies.reserveCapacity(Int(maxLayerCount))
        for i in 0..<Int(maxLayerCount) {
            var refs: [UInt8] = []
            for j in 0..<i {
                let flag = try bitstream.readBit()
                if flag == 1 {
                    refs.append(UInt8(j))
                }
            }
            directRefLayers.append(refs)
            layerDependencies.append(
                LayerDependency(
                    layerID: layerIDs[i],
                    dependsOnLayerIDs: refs.map { layerIDs[Int($0)] }
                )
            )
        }

        // output layer sets
        let olsCount = UInt8(try bitstream.readBits(8))
        var outputLayerSets: [OutputLayerSet] = []
        outputLayerSets.reserveCapacity(Int(olsCount))
        for _ in 0..<Int(olsCount) {
            let idx = UInt8(try bitstream.readBits(8))
            var flags: [Bool] = []
            flags.reserveCapacity(Int(maxLayerCount))
            for _ in 0..<Int(maxLayerCount) {
                flags.append(try bitstream.readBool())
            }
            outputLayerSets.append(
                OutputLayerSet(layerSetIDx: idx, outputLayerFlags: flags)
            )
        }

        return HEVCVPSExtension(
            maxLayerCount: maxLayerCount,
            layerIDs: layerIDs,
            layerDependencies: layerDependencies,
            scalabilityMask: scalabilityMask,
            dimensionIDLen: dimensionIDLen,
            dimensionID: dimensionID,
            directRefLayers: directRefLayers,
            viewIDValues: viewIDValues,
            auxIDValues: auxIDValues,
            outputLayerSets: outputLayerSets
        )
    }

    /// Encode the VPS extension as a CMAFKit-canonical bitstream.
    ///
    /// Round-trip with ``parse(bitstream:)`` is byte-identical.
    /// Reference: ITU-T H.265 §F.7.3.2.1 (canonical field ordering).
    public func encode(to writer: inout BitWriter) throws {
        guard (1...64).contains(maxLayerCount) else {
            throw HEVCVPSExtensionError.invalidLayerCount(
                Int(maxLayerCount), maxAllowed: 64
            )
        }
        let scalabilityCount = scalabilityMask.raw.nonzeroBitCount
        guard scalabilityCount == dimensionIDLen.count else {
            throw HEVCVPSExtensionError.malformedBitstream(
                reason: "dimensionIDLen.count (\(dimensionIDLen.count)) must equal "
                    + "popcount(scalabilityMask) (\(scalabilityCount))"
            )
        }

        writer.writeBits(UInt64(scalabilityMask.raw), count: 16)
        writer.writeBits(UInt64(maxLayerCount) - 1, count: 6)

        if maxLayerCount > 1 {
            for i in 1..<Int(maxLayerCount) {
                writer.writeBits(UInt64(layerIDs[i]), count: 6)
            }
        }

        for length in dimensionIDLen {
            writer.writeBits(UInt64(length) - 1, count: 3)
        }
        for row in dimensionID {
            for (j, value) in row.enumerated() {
                writer.writeBits(UInt64(value), count: Int(dimensionIDLen[j]))
            }
        }

        let viewIDLen: UInt8
        if viewIDValues.isEmpty {
            viewIDLen = 0
            writer.writeBits(0, count: 4)
        } else {
            // Use the smallest length that fits every value.
            let maxValue = viewIDValues.max() ?? 0
            let needed = UInt8(max(1, 16 - maxValue.leadingZeroBitCount))
            viewIDLen = needed
            writer.writeBits(UInt64(viewIDLen), count: 4)
            writer.writeBits(UInt64(viewIDValues.count), count: 6)
            for value in viewIDValues {
                writer.writeBits(UInt64(value), count: Int(viewIDLen))
            }
        }

        writer.writeBits(UInt64(auxIDValues.count), count: 6)
        for value in auxIDValues {
            writer.writeBits(UInt64(value), count: 8)
        }

        for i in 0..<Int(maxLayerCount) {
            let refs = directRefLayers[i]
            for j in 0..<i {
                writer.writeBool(refs.contains(UInt8(j)))
            }
        }

        writer.writeBits(UInt64(outputLayerSets.count), count: 8)
        for ols in outputLayerSets {
            writer.writeBits(UInt64(ols.layerSetIDx), count: 8)
            for flag in ols.outputLayerFlags {
                writer.writeBool(flag)
            }
        }
    }
}

/// Layer dependency declaration — which other layers a given layer depends on.
///
/// Reference: ITU-T H.265 §F.7.4.3.1 — `direct_dependency_flag[i][j]`.
public struct LayerDependency: Sendable, Equatable, Hashable {
    /// The dependent layer's `nuh_layer_id`.
    public let layerID: UInt8
    /// The `nuh_layer_id` values of every layer this layer depends on for
    /// inter-layer prediction.
    public let dependsOnLayerIDs: [UInt8]

    public init(layerID: UInt8, dependsOnLayerIDs: [UInt8]) {
        self.layerID = layerID
        self.dependsOnLayerIDs = dependsOnLayerIDs
    }
}

/// Scalability mask — declares the *dimensions* along which layers vary.
///
/// Reference: ITU-T H.265 §F.7.4.3.1 — `scalability_mask_flag[i]`.
/// Bit indices per ITU-T H.265 Table F.1.
public struct ScalabilityMask: Sendable, Equatable, Hashable {

    /// Multi-view scalability (bit 1 of `scalability_mask_flag` per Table F.1).
    public let isMultiview: Bool

    /// Spatial / quality scalability (bit 2 per Table F.1).
    public let isSpatialQuality: Bool

    /// Auxiliary picture scalability (bit 3 per Table F.1 — alpha plane,
    /// depth, etc.).
    public let isAuxiliary: Bool

    /// Raw 16-bit mask preserved verbatim for round-trip safety of unknown /
    /// future-defined bits.
    public let raw: UInt16

    public init(
        isMultiview: Bool,
        isSpatialQuality: Bool,
        isAuxiliary: Bool,
        raw: UInt16
    ) {
        self.isMultiview = isMultiview
        self.isSpatialQuality = isSpatialQuality
        self.isAuxiliary = isAuxiliary
        self.raw = raw
    }

    /// Convenience: build from the raw 16-bit value, decoding the typed
    /// flags per ITU-T H.265 Table F.1.
    public init(raw: UInt16) {
        self.raw = raw
        self.isMultiview = (raw & (1 << 1)) != 0
        self.isSpatialQuality = (raw & (1 << 2)) != 0
        self.isAuxiliary = (raw & (1 << 3)) != 0
    }
}

/// Output Layer Set — declares which layers are output for a given
/// operating point.
///
/// Reference: ITU-T H.265 §F.7.4.3.1 — `output_layer_set_idx[i]` +
/// `output_layer_flag[i][j]`.
public struct OutputLayerSet: Sendable, Equatable, Hashable {
    /// `output_layer_set_idx[i]` — the layer-set index this OLS references.
    public let layerSetIDx: UInt8
    /// Per-layer output flag. Length equals the parent VPS's `maxLayerCount`.
    public let outputLayerFlags: [Bool]

    public init(layerSetIDx: UInt8, outputLayerFlags: [Bool]) {
        self.layerSetIDx = layerSetIDx
        self.outputLayerFlags = outputLayerFlags
    }
}

/// Typed errors thrown by ``HEVCVPSExtension/parse(bitstream:)`` and
/// ``HEVCVPSExtension/encode(to:)``.
public enum HEVCVPSExtensionError: Error, Equatable {
    /// The bitstream is truncated or violates a structural invariant.
    case malformedBitstream(reason: String)

    /// The number of scalability dimensions exceeds the 16-bit mask
    /// width supported by ITU-T H.265 §F.7.4.3.1.
    case unsupportedDimensionCount(_ count: Int)

    /// `maxLayerCount` is outside the `1...64` range allowed by
    /// `vps_max_layers_minus1`.
    case invalidLayerCount(_ count: Int, maxAllowed: Int)
}
