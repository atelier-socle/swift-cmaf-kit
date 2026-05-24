// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCMultiLayerScalingListData
//
// Reference: ITU-T H.265 §I.7.4.7 (3D-HEVC scaling list extension) +
// §7.4.5 (base scaling list).
//
// Carries the base layer scaling list plus optional per-layer overrides.
// Reuses the existing 0.1.0 HEVCScalingListData type — no redefinition.

import Foundation

/// Multi-Layer scaling list — 3D-HEVC extension of the base HEVC scaling
/// list per ITU-T H.265 §I.7.4.7.
///
/// Carries the base layer scaling list plus an optional per-layer override
/// list for enhancement / 3D layers. Each override is itself a full
/// ``HEVCScalingListData`` (the existing 0.1.0 type — reused without
/// redefinition).
///
/// Encoded as: base scaling list payload, followed by `layerSpecificScalingList.count`
/// encoded as `ue(v)`, followed by each override's scaling list payload in
/// order. The `layerCount` parameter passed to ``parse(bitstream:baseScalingList:layerCount:)``
/// is the expected number of enhancement layers (used as a consistency check
/// for ``HEVCMultiLayerScalingListDataError/layerCountMismatch(declared:parsed:)``).
///
/// References:
/// - ITU-T H.265 §I.7.4.7 — 3D-HEVC scaling list semantics
/// - ITU-T H.265 §7.4.5 — Base scaling list semantics
public struct HEVCMultiLayerScalingListData: Sendable, Equatable, Hashable {

    /// The base scaling list. Reuses the existing 0.1.0 type — no
    /// redefinition.
    public let scalingListData: HEVCScalingListData

    /// Per-layer scaling list overrides, indexed by enhancement-layer rank
    /// (not `nuh_layer_id`). Empty for streams that share the base scaling
    /// list across all layers.
    public let layerSpecificScalingList: [HEVCScalingListData]

    public init(
        scalingListData: HEVCScalingListData,
        layerSpecificScalingList: [HEVCScalingListData] = []
    ) {
        self.scalingListData = scalingListData
        self.layerSpecificScalingList = layerSpecificScalingList
    }

    /// Parse a multi-layer scaling list.
    ///
    /// The base scaling list is parsed first by the caller (it is provided
    /// here as `baseScalingList`); this method consumes only the per-layer
    /// override block that follows.
    ///
    /// - Parameters:
    ///   - bitstream: `BitReader` positioned just after the base scaling
    ///     list payload.
    ///   - baseScalingList: the already-parsed base scaling list.
    ///   - layerCount: the expected number of enhancement-layer overrides.
    ///     A `0` value allows the parsed count to be anything (no check);
    ///     any non-zero value is enforced against the parsed count.
    /// - Throws: ``HEVCMultiLayerScalingListDataError`` on malformed input
    ///   or layer-count mismatch.
    public static func parse(
        bitstream: inout BitReader,
        baseScalingList: HEVCScalingListData,
        layerCount: Int
    ) throws -> HEVCMultiLayerScalingListData {
        let overrideCount = Int(try bitstream.readUnsignedExpGolomb())
        if layerCount > 0, overrideCount != layerCount {
            throw HEVCMultiLayerScalingListDataError.layerCountMismatch(
                declared: layerCount, parsed: overrideCount
            )
        }
        var overrides: [HEVCScalingListData] = []
        overrides.reserveCapacity(overrideCount)
        for _ in 0..<overrideCount {
            overrides.append(try HEVCScalingListData.parse(reader: &bitstream))
        }
        return HEVCMultiLayerScalingListData(
            scalingListData: baseScalingList,
            layerSpecificScalingList: overrides
        )
    }

    /// Encode the per-layer override block.
    ///
    /// The base scaling list is encoded separately by the parent SPS
    /// scaling-list section; this method emits only the override block
    /// that follows.
    public func encode(to writer: inout BitWriter) throws {
        writer.writeUnsignedExpGolomb(UInt32(layerSpecificScalingList.count))
        for scalingList in layerSpecificScalingList {
            scalingList.encode(to: &writer)
        }
    }
}

/// Typed errors thrown by ``HEVCMultiLayerScalingListData/parse(bitstream:baseScalingList:layerCount:)``
/// and ``HEVCMultiLayerScalingListData/encode(to:)``.
public enum HEVCMultiLayerScalingListDataError: Error, Equatable {
    /// The bitstream is truncated or violates a structural invariant.
    case malformedBitstream(reason: String)

    /// The parsed override count differs from the caller-declared
    /// `layerCount` parameter.
    case layerCountMismatch(declared: Int, parsed: Int)
}
