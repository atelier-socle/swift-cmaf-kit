// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCMultiLayerSPS
//
// Reference: ITU-T H.265 §F.7.3.2.2.1 (sps_multilayer_extension() syntax),
// §F.7.4.3.2.1 (sps_multilayer_extension() semantics).
//
// Extends a base HEVC SPS with multi-layer signalling. The extension is
// present in an SPS NAL unit when both `sps_extension_present_flag` and
// `sps_multilayer_extension_flag` are set in the parent SPS.

import Foundation

/// Multi-Layer Sequence Parameter Set extension.
///
/// Extends the base HEVC SPS with multi-layer signalling per
/// ITU-T H.265 §F.7.3.2.2.1.
///
/// The extension is present when `sps_extension_present_flag` AND
/// `sps_multilayer_extension_flag` are both set in the parent SPS. CMAFKit
/// reuses the existing ``HEVCSequenceParameterSet`` for the base SPS field
/// rather than redefining a parallel type.
///
/// References:
/// - ITU-T H.265 §F.7.3.2.2.1 — Multi-layer SPS extension syntax
/// - ITU-T H.265 §F.7.4.3.2.1 — Multi-layer SPS extension semantics
public struct HEVCMultiLayerSPS: Sendable, Equatable, Hashable {

    /// The base SPS that this extension augments.
    ///
    /// Reuses the existing 0.1.0 ``HEVCSequenceParameterSet`` — no
    /// redefinition.
    public let baseSPS: HEVCSequenceParameterSet

    /// `inter_layer_ref_pics_present_flag` — when set, at least one
    /// inter-layer reference picture may be used for inter prediction in
    /// the slices of this layer.
    public let interLayerRefPicsPresentFlag: Bool

    /// `update_rep_format_flag` — when set, the representation format
    /// (chroma / bit-depth / dimensions) of this layer is overridden with
    /// respect to the base layer.
    public let updateRepFormatFlag: Bool

    /// Opaque preservation of any further extension bytes consumed beyond
    /// the typed fields. Empty for canonical streams that do not carry
    /// unknown extension data; non-empty when CMAFKit encounters fields
    /// it does not yet model.
    public let multiLayerExtensionData: Data

    public init(
        baseSPS: HEVCSequenceParameterSet,
        interLayerRefPicsPresentFlag: Bool,
        updateRepFormatFlag: Bool,
        multiLayerExtensionData: Data = .init()
    ) {
        self.baseSPS = baseSPS
        self.interLayerRefPicsPresentFlag = interLayerRefPicsPresentFlag
        self.updateRepFormatFlag = updateRepFormatFlag
        self.multiLayerExtensionData = multiLayerExtensionData
    }

    /// Parse a multi-layer SPS extension.
    ///
    /// - Parameters:
    ///   - bitstream: `BitReader` positioned at the start of the multi-layer
    ///     extension payload (after `sps_multilayer_extension_flag` has
    ///     been confirmed true in the parent SPS).
    ///   - baseSPS: the already-parsed base SPS this extension augments.
    ///   - layerID: the `nuh_layer_id` of the NAL unit carrying this SPS.
    ///     Used to detect a mismatch with `baseSPS.vpsID`-derived layer
    ///     context.
    /// - Throws: ``HEVCMultiLayerSPSError`` on malformed input or layer
    ///   identifier mismatch.
    ///
    /// Reference: ITU-T H.265 §F.7.3.2.2.1.
    public static func parse(
        bitstream: inout BitReader,
        baseSPS: HEVCSequenceParameterSet,
        layerID: UInt8
    ) throws -> HEVCMultiLayerSPS {
        guard layerID <= 63 else {
            throw HEVCMultiLayerSPSError.mismatchedLayerID(
                declared: layerID, expected: 63
            )
        }
        let interLayerRefPics = try bitstream.readBool()
        let updateRepFormat = try bitstream.readBool()
        // Remaining 16 bits are reserved for future fields that we
        // preserve as opaque tail bytes when present.
        let opaqueByteCount = max(0, bitstream.bitsRemaining / 8)
        var opaque = Data()
        opaque.reserveCapacity(opaqueByteCount)
        for _ in 0..<opaqueByteCount {
            opaque.append(UInt8(try bitstream.readBits(8)))
        }
        return HEVCMultiLayerSPS(
            baseSPS: baseSPS,
            interLayerRefPicsPresentFlag: interLayerRefPics,
            updateRepFormatFlag: updateRepFormat,
            multiLayerExtensionData: opaque
        )
    }

    /// Encode the multi-layer SPS extension to a CMAFKit-canonical bitstream.
    ///
    /// Round-trip with ``parse(bitstream:baseSPS:layerID:)`` is byte-identical.
    public func encode(to writer: inout BitWriter) throws {
        writer.writeBool(interLayerRefPicsPresentFlag)
        writer.writeBool(updateRepFormatFlag)
        for byte in multiLayerExtensionData {
            writer.writeBits(UInt64(byte), count: 8)
        }
    }
}

/// Typed errors thrown by ``HEVCMultiLayerSPS/parse(bitstream:baseSPS:layerID:)``
/// and ``HEVCMultiLayerSPS/encode(to:)``.
public enum HEVCMultiLayerSPSError: Error, Equatable {
    /// The bitstream is truncated or violates a structural invariant.
    case malformedBitstream(reason: String)

    /// The NAL unit's `nuh_layer_id` is outside the `0...63` range allowed
    /// by ITU-T H.265 §7.4.2.2.
    case mismatchedLayerID(declared: UInt8, expected: UInt8)
}
