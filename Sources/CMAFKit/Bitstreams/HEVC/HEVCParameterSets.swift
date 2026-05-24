// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCParameterSets
//
// Aggregate parameter-set extractor consolidating VPS / SPS / PPS NAL
// units from a HEVC bitstream into typed parser arrays and packing the
// result into the array form required by `HEVCDecoderConfigurationRecord`
// (the `hvcC` box).
//
// Reference: ITU-T H.265 §7.3.2 (NAL unit headers + parameter set
// ordering), §7.4.1 (emulation prevention), and ISO/IEC 14496-15
// §8.3.3.1.1 (hvcC parameter-set array storage).

import Foundation

/// Aggregate HEVC parameter sets container.
///
/// Extracts Video / Sequence / Picture parameter sets from a heterogeneous
/// NAL unit stream and packs the result into the array form consumed by
/// `HEVCDecoderConfigurationRecord` (the `hvcC` sample-entry box).
///
/// HEVC parameter sets are carried as separate NAL units of types 32 (VPS),
/// 33 (SPS), and 34 (PPS) per ITU-T H.265 §7.3.2. CMAFKit's per-field
/// parsers (``HEVCVideoParameterSet``, ``HEVCSequenceParameterSet``,
/// ``HEVCPictureParameterSet``) decode each individual RBSP; this aggregate
/// orchestrates extraction from a stream and produces the
/// `(arrayCompleteness, nalUnitType, parameterSets[])` groups that
/// `hvcC` expects.
///
/// References:
/// - ITU-T H.265 §7.3.2 — NAL unit headers and parameter set ordering
/// - ITU-T H.265 §7.4.1 — NAL unit semantics, emulation prevention
/// - ISO/IEC 14496-15 §8.3.3.1 — `HEVCDecoderConfigurationRecord` storage
/// - ISO/IEC 14496-15 §A — bytestream NAL unit format (Annex B)
public struct HEVCParameterSets: Sendable, Equatable, Hashable {

    /// VPS NAL units parsed (NAL unit type 32). At least one is required by `hvcC`.
    public let videoParameterSets: [HEVCVideoParameterSet]

    /// SPS NAL units parsed (NAL unit type 33). At least one is required.
    public let sequenceParameterSets: [HEVCSequenceParameterSet]

    /// PPS NAL units parsed (NAL unit type 34). At least one is required.
    public let pictureParameterSets: [HEVCPictureParameterSet]

    /// Designated initializer.
    ///
    /// - Note: this initializer does **not** enforce the
    ///   "at least one of each" rule — that constraint is checked only
    ///   during ``extract(from:format:)`` so that unit tests can construct
    ///   aggregates with empty arrays for diagnostic purposes.
    public init(
        videoParameterSets: [HEVCVideoParameterSet],
        sequenceParameterSets: [HEVCSequenceParameterSet],
        pictureParameterSets: [HEVCPictureParameterSet]
    ) {
        self.videoParameterSets = videoParameterSets
        self.sequenceParameterSets = sequenceParameterSets
        self.pictureParameterSets = pictureParameterSets
    }

    /// Extract VPS / SPS / PPS from a list of NAL unit byte buffers.
    ///
    /// - Parameters:
    ///   - nalUnits: array of NAL unit byte buffers. For ``HEVCNALFormat/annexB`` the
    ///     individual entries may carry multiple concatenated NAL units; for the other
    ///     formats each entry must be exactly one NAL unit.
    ///   - format: how the NAL unit bytes are framed (see ``HEVCNALFormat``).
    ///     Determines whether emulation-prevention bytes are already stripped
    ///     (``HEVCNALFormat/rawRBSP``) or must be stripped by this extractor.
    /// - Returns: a fully-typed ``HEVCParameterSets`` aggregating every VPS / SPS / PPS
    ///   present in the stream.
    /// - Throws:
    ///   - ``HEVCParameterSetsError/malformedNALUnit(reason:)`` — invalid header,
    ///     truncated buffer, or invalid `lengthPrefixed` prefix size.
    ///   - ``HEVCParameterSetsError/duplicateParameterSet(type:id:)`` — same VPS, SPS,
    ///     or PPS id encountered twice in the stream.
    ///   - ``HEVCParameterSetsError/conflictingProfileTierLevel(reason:)`` — a VPS
    ///     and an SPS sharing the same `vps_video_parameter_set_id` carry
    ///     different `profile_tier_level` payloads (best-effort: the check is
    ///     skipped when the link cannot be resolved).
    ///   - ``HEVCParameterSetsError/missingMandatoryParameterSet(type:)`` — at least
    ///     one VPS, SPS, and PPS must be present (per `hvcC` requirements).
    ///
    /// Reference: ITU-T H.265 §7.3.2 + ISO/IEC 14496-15 §8.3.3.1.
    public static func extract(
        from nalUnits: [Data],
        format: HEVCNALFormat
    ) throws -> HEVCParameterSets {
        let units = try normalize(nalUnits: nalUnits, format: format)

        var vps: [HEVCVideoParameterSet] = []
        var sps: [HEVCSequenceParameterSet] = []
        var pps: [HEVCPictureParameterSet] = []
        var vpsIDs: Set<UInt8> = []
        var spsIDs: Set<UInt32> = []
        var ppsIDs: Set<UInt32> = []

        for nalUnit in units {
            guard nalUnit.count >= 2 else {
                throw HEVCParameterSetsError.malformedNALUnit(
                    reason: "NAL unit smaller than 2-byte header"
                )
            }
            let headerByte0 = nalUnit[nalUnit.startIndex]
            let nalType = (headerByte0 >> 1) & 0x3F

            // VPS / SPS / PPS only. Other NAL units are skipped silently —
            // this extractor is parameter-set-focused per ITU-T H.265 §7.4.2.4.
            guard
                nalType == HEVCNALUnitType.vpsNUT.rawValue
                    || nalType == HEVCNALUnitType.spsNUT.rawValue
                    || nalType == HEVCNALUnitType.ppsNUT.rawValue
            else {
                continue
            }

            // Body = bytes after the 2-byte NAL header.
            let bodyStart = nalUnit.index(nalUnit.startIndex, offsetBy: 2)
            let body = nalUnit.subdata(in: bodyStart..<nalUnit.endIndex)
            let rbsp: Data
            switch format {
            case .rawRBSP:
                rbsp = body
            case .ebspWithPrefix, .lengthPrefixed, .annexB:
                rbsp = NALRBSPDecoder.ebspToRBSP(body)
            }

            switch nalType {
            case HEVCNALUnitType.vpsNUT.rawValue:
                let parsed = try Self.parseVPS(rbsp: rbsp)
                if !vpsIDs.insert(parsed.vpsID).inserted {
                    throw HEVCParameterSetsError.duplicateParameterSet(
                        type: .vpsNUT, id: parsed.vpsID
                    )
                }
                vps.append(parsed)
            case HEVCNALUnitType.spsNUT.rawValue:
                let parsed = try Self.parseSPS(rbsp: rbsp)
                if !spsIDs.insert(parsed.spsID).inserted {
                    throw HEVCParameterSetsError.duplicateParameterSet(
                        type: .spsNUT, id: UInt8(clamping: parsed.spsID)
                    )
                }
                sps.append(parsed)
            case HEVCNALUnitType.ppsNUT.rawValue:
                let parsed = try Self.parsePPS(rbsp: rbsp)
                if !ppsIDs.insert(parsed.ppsID).inserted {
                    throw HEVCParameterSetsError.duplicateParameterSet(
                        type: .ppsNUT, id: UInt8(clamping: parsed.ppsID)
                    )
                }
                pps.append(parsed)
            default:
                continue
            }
        }

        // Best-effort PTL conflict detection between VPS and SPS referencing it.
        for spsUnit in sps {
            if let vpsUnit = vps.first(where: { $0.vpsID == spsUnit.vpsID }),
                vpsUnit.profileTierLevel != spsUnit.profileTierLevel
            {
                throw HEVCParameterSetsError.conflictingProfileTierLevel(
                    reason: "VPS(\(vpsUnit.vpsID)).profile_tier_level "
                        + "differs from SPS(spsID=\(spsUnit.spsID)).profile_tier_level"
                )
            }
        }

        guard !vps.isEmpty else {
            throw HEVCParameterSetsError.missingMandatoryParameterSet(type: .vpsNUT)
        }
        guard !sps.isEmpty else {
            throw HEVCParameterSetsError.missingMandatoryParameterSet(type: .spsNUT)
        }
        guard !pps.isEmpty else {
            throw HEVCParameterSetsError.missingMandatoryParameterSet(type: .ppsNUT)
        }

        return HEVCParameterSets(
            videoParameterSets: vps,
            sequenceParameterSets: sps,
            pictureParameterSets: pps
        )
    }

    /// Pack the parameter sets into the array form expected by
    /// ``HEVCDecoderConfigurationRecord``.
    ///
    /// The `hvcC` `arrays[]` field is a list of
    /// `(arrayCompleteness, nalUnitType, parameterSets[])` groups; this
    /// method emits one group per NAL unit type that is present, in the
    /// recommended VPS → SPS → PPS order.
    ///
    /// Each emitted ``HEVCParameterSet`` carries the **full NAL unit bytes**
    /// (2-byte NAL header + EBSP body); the writer adds the 2-byte length
    /// prefix when serialising the `hvcC` box.
    ///
    /// Reference: ISO/IEC 14496-15 §8.3.3.1.1.
    public func toHvcCArrays() -> [HEVCParameterSetArray] {
        var arrays: [HEVCParameterSetArray] = []

        if !videoParameterSets.isEmpty {
            arrays.append(
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .vpsNUT,
                    parameterSets: videoParameterSets.map {
                        Self.makeNALUnit(rbsp: $0.encode(), nalType: 32)
                    }
                )
            )
        }
        if !sequenceParameterSets.isEmpty {
            arrays.append(
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .spsNUT,
                    parameterSets: sequenceParameterSets.map {
                        Self.makeNALUnit(rbsp: $0.encode(), nalType: 33)
                    }
                )
            )
        }
        if !pictureParameterSets.isEmpty {
            arrays.append(
                HEVCParameterSetArray(
                    arrayCompleteness: true,
                    nalUnitType: .ppsNUT,
                    parameterSets: pictureParameterSets.map {
                        Self.makeNALUnit(rbsp: $0.encode(), nalType: 34)
                    }
                )
            )
        }
        return arrays
    }

    // MARK: - Internal helpers

    /// Normalise a NAL unit list to a homogeneous `[Data]` where each entry
    /// is exactly one NAL unit starting with the 2-byte NAL header.
    private static func normalize(
        nalUnits: [Data],
        format: HEVCNALFormat
    ) throws -> [Data] {
        switch format {
        case .rawRBSP, .ebspWithPrefix:
            return nalUnits
        case .lengthPrefixed(let prefixBytes):
            guard prefixBytes == 1 || prefixBytes == 2 || prefixBytes == 4 else {
                throw HEVCParameterSetsError.malformedNALUnit(
                    reason: "lengthPrefixed prefixBytes must be 1, 2, or 4"
                )
            }
            return try nalUnits.map { buffer in
                guard buffer.count >= Int(prefixBytes) else {
                    throw HEVCParameterSetsError.malformedNALUnit(
                        reason: "length-prefixed NAL truncated"
                    )
                }
                let bodyStart = buffer.index(buffer.startIndex, offsetBy: Int(prefixBytes))
                return buffer.subdata(in: bodyStart..<buffer.endIndex)
            }
        case .annexB:
            return try nalUnits.flatMap { try splitAnnexB($0) }
        }
    }

    /// Split an Annex B byte stream into individual NAL units.
    ///
    /// Start codes are `0x00 0x00 0x01` (3 bytes) or `0x00 0x00 0x00 0x01`
    /// (4 bytes) per ITU-T H.265 Annex B / ISO/IEC 14496-15 §A.
    private static func splitAnnexB(_ buffer: Data) throws -> [Data] {
        let bytes = Array(buffer)
        var units: [Data] = []
        var nalStart: Int?
        var index = 0

        while index < bytes.count {
            // Detect 0x000001 or 0x00000001 start code.
            let isThreeByteStart =
                index + 2 < bytes.count
                && bytes[index] == 0x00
                && bytes[index + 1] == 0x00
                && bytes[index + 2] == 0x01
            let isFourByteStart =
                index + 3 < bytes.count
                && bytes[index] == 0x00
                && bytes[index + 1] == 0x00
                && bytes[index + 2] == 0x00
                && bytes[index + 3] == 0x01

            if isFourByteStart {
                if let start = nalStart {
                    units.append(Data(bytes[start..<index]))
                }
                index += 4
                nalStart = index
            } else if isThreeByteStart {
                if let start = nalStart {
                    units.append(Data(bytes[start..<index]))
                }
                index += 3
                nalStart = index
            } else {
                index += 1
            }
        }
        if let start = nalStart, start < bytes.count {
            units.append(Data(bytes[start..<bytes.count]))
        }
        if units.isEmpty {
            throw HEVCParameterSetsError.malformedNALUnit(
                reason: "Annex B buffer carried no valid start code"
            )
        }
        return units
    }

    /// Construct a NAL-unit ``HEVCParameterSet`` from a parsed RBSP body
    /// plus a NAL unit type identifier. Uses the canonical NAL header
    /// (`nuh_layer_id == 0`, `nuh_temporal_id_plus1 == 1`).
    private static func makeNALUnit(rbsp: Data, nalType: UInt8) -> HEVCParameterSet {
        var nalBytes = Data()
        // byte 0: forbidden_zero_bit(1) | nal_unit_type(6) | nuh_layer_id_high(1)
        nalBytes.append((nalType & 0x3F) << 1)
        // byte 1: nuh_layer_id_low(5) | nuh_temporal_id_plus1(3) — canonical (0,1).
        nalBytes.append(0x01)
        nalBytes.append(NALRBSPDecoder.rbspToEBSP(rbsp))
        return HEVCParameterSet(rbspBytes: nalBytes)
    }

    /// Parse a VPS RBSP body; wraps the per-field parser with `malformedNALUnit`
    /// error translation so the aggregate surfaces a single typed error.
    private static func parseVPS(rbsp: Data) throws -> HEVCVideoParameterSet {
        do {
            return try HEVCVideoParameterSet.parse(rbsp: rbsp)
        } catch {
            throw HEVCParameterSetsError.malformedNALUnit(
                reason: "VPS body parse failed: \(error)"
            )
        }
    }

    private static func parseSPS(rbsp: Data) throws -> HEVCSequenceParameterSet {
        do {
            return try HEVCSequenceParameterSet.parse(rbsp: rbsp)
        } catch {
            throw HEVCParameterSetsError.malformedNALUnit(
                reason: "SPS body parse failed: \(error)"
            )
        }
    }

    private static func parsePPS(rbsp: Data) throws -> HEVCPictureParameterSet {
        do {
            return try HEVCPictureParameterSet.parse(rbsp: rbsp)
        } catch {
            throw HEVCParameterSetsError.malformedNALUnit(
                reason: "PPS body parse failed: \(error)"
            )
        }
    }
}

/// How a NAL unit is framed on input to ``HEVCParameterSets/extract(from:format:)``.
///
/// Reference: ITU-T H.265 §7.4.1 (NAL unit semantics) + ISO/IEC 14496-15 §A
/// (bytestream NAL unit format).
public enum HEVCNALFormat: Sendable, Hashable {

    /// The NAL body is already an RBSP (emulation-prevention bytes removed).
    /// Each input entry is `(2-byte NAL header) + (RBSP body)`. Suitable when
    /// the caller has already invoked ``NALRBSPDecoder/ebspToRBSP(_:)``.
    case rawRBSP

    /// The NAL body is an EBSP (emulation-prevention bytes present).
    /// Each input entry is `(2-byte NAL header) + (EBSP body)`.
    case ebspWithPrefix

    /// ISO BMFF length-prefixed framing.
    ///
    /// Each input entry begins with an `N`-byte big-endian length field
    /// (1, 2, or 4 bytes) followed by the NAL unit (`header + EBSP body`).
    /// `N` matches the `lengthSizeMinusOne + 1` field from `hvcC`.
    case lengthPrefixed(prefixBytes: UInt8)

    /// Annex B byte-stream framing.
    ///
    /// Each input entry may carry one or more concatenated NAL units
    /// separated by `0x000001` (3-byte) or `0x00000001` (4-byte) start
    /// codes per ITU-T H.265 Annex B. The extractor splits on the start
    /// codes; each recovered chunk is processed as
    /// ``HEVCNALFormat/ebspWithPrefix``.
    case annexB
}

/// Typed errors thrown by ``HEVCParameterSets/extract(from:format:)``.
public enum HEVCParameterSetsError: Error, Equatable {

    /// A NAL unit could not be parsed (truncated, invalid header byte,
    /// invalid prefix size, or missing Annex B start code).
    case malformedNALUnit(reason: String)

    /// The same parameter set id was encountered twice for the same NAL
    /// unit type.
    case duplicateParameterSet(type: HEVCNALUnitType, id: UInt8)

    /// VPS and SPS sharing the same `vps_video_parameter_set_id` carry
    /// inconsistent `profile_tier_level` payloads.
    case conflictingProfileTierLevel(reason: String)

    /// At least one VPS, one SPS, and one PPS are required for a valid
    /// ``HEVCParameterSets`` produced by ``HEVCParameterSets/extract(from:format:)``.
    case missingMandatoryParameterSet(type: HEVCNALUnitType)
}
