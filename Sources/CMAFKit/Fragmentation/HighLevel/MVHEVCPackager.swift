// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MVHEVCPackager
//
// Reference: ISO/IEC 14496-15 §8.4 (multi-layer HEVC access unit /
// sample composition), ITU-T H.265 §F.7.3.1.2 (NAL header layer ID
// extraction), ITU-T H.265 §F (multi-layer extensions), Apple HEVC
// Stereo Video Profile §3.3 (hero eye signalling).
//
// High-level orchestrator that splits MV-HEVC access units across
// layers and produces per-layer sample bytes ready for
// ``CMAFMediaSegmentWriter`` consumption.
//
// Lifecycle doctrine — mirrors ``CMAFMediaSegmentWriter``:
// `stop()` is the canonical termination entry point. After `stop()`,
// every mutating method throws ``MVHEVCPackagerError/alreadyStopped``.
// `deinit` does NOT perform async work — actor isolation precludes it —
// so callers MUST call `stop()` before letting the packager go out of
// scope. The contract is documented; the discipline is enforced by the
// state machine on every call.

import Foundation

/// Splits MV-HEVC access units across layers and produces per-layer
/// sample bytes ready for ``CMAFMediaSegmentWriter`` consumption.
///
/// An MV-HEVC access unit is a sequence of NAL units interleaved across
/// layers; each NAL unit carries its `nuh_layer_id` in the NAL header.
/// The packager reads the layer ID from each NAL header per
/// ITU-T H.265 §F.7.3.1.2, groups the NAL units by layer, and produces
/// one ``LayerSampleOutput`` per layer for downstream `moof` + `mdat`
/// composition.
///
/// **Lifecycle**: this actor manages internal state (per-AU per-layer
/// buffers, decode-time tracking). Callers MUST call ``stop()`` before
/// letting the packager go out of scope, mirroring the
/// ``CMAFMediaSegmentWriter`` doctrine. After ``stop()``, every mutating
/// method throws ``MVHEVCPackagerError/alreadyStopped``.
///
/// **Hero layer resolution**: when the consumer provides a
/// ``HeroEyeInformationBox/HeroEye`` hint at init, the packager maps the
/// hero eye to a layer ID per the Apple Vision Pro Spatial Video
/// convention: `.leftEye` → layer 0 (base), `.rightEye` → layer 1
/// (extension). With `.none` or no hint, every ``LayerSampleOutput``
/// reports `isHeroLayer == false`.
///
/// References:
/// - ISO/IEC 14496-15 §8.4 — Multi-layer HEVC sample composition
/// - ITU-T H.265 §F.7.3.1.2 — NAL header layer ID extraction
/// - ITU-T H.265 §F — Multi-Layer Extensions
/// - Apple HEVC Stereo Video Profile §3.3 — hero eye signalling
public actor MVHEVCPackager {

    /// Lifecycle state.
    public enum State: Sendable, Equatable {
        /// Default state — `processAccessUnit` calls are honoured.
        case active
        /// ``stop()`` has been called; mutating methods throw.
        case stopped
    }

    /// Current lifecycle state.
    public private(set) var state: State = .active

    /// True after ``stop()``.
    public var isStopped: Bool { state == .stopped }

    /// The multi-layer configuration this packager was built from.
    /// `nonisolated` because it is a constant set at init.
    public nonisolated let configuration: MultiLayerHEVCConfiguration

    /// Hero layer ID resolved from the optional ``HeroEyeInformationBox/HeroEye``
    /// hint at init. `nil` when the consumer did not provide a hint or
    /// chose `.none` (truly stereoscopic — neither eye is preferred).
    /// `nonisolated` because it is a constant set at init.
    public nonisolated let heroLayerID: UInt8?

    private var perLayerBuffers: [UInt8: Data] = [:]
    private let layerLookup: Set<UInt8>
    private let lengthPrefixSize: Int

    /// Construct a packager for one MV-HEVC track.
    ///
    /// - Parameters:
    ///   - configuration: the multi-layer HEVC configuration describing
    ///     which layers are present and how they depend on each other.
    ///   - heroEye: optional hero-eye hint sourced from the
    ///     ``HeroEyeInformationBox`` carried alongside the sample entry.
    ///     Resolves to ``heroLayerID`` via the Apple Vision Pro Spatial
    ///     Video convention: `.leftEye` → layer 0, `.rightEye` → layer 1.
    public init(
        configuration: MultiLayerHEVCConfiguration,
        heroEye: HeroEyeInformationBox.HeroEye? = nil
    ) {
        self.configuration = configuration
        self.layerLookup = Set(configuration.layerIDs)
        // NALLengthSize.rawValue is already the prefix byte count (1, 2, or 4).
        self.lengthPrefixSize = Int(configuration.baseLayer.lengthSize.rawValue)
        switch heroEye {
        case .some(.leftEye):
            self.heroLayerID = configuration.layerIDs.first
        case .some(.rightEye):
            self.heroLayerID = configuration.layerIDs.dropFirst().first
        case .some(.none), nil:
            self.heroLayerID = nil
        }
    }

    /// Process one access unit (a single video frame's worth of
    /// interleaved NAL units across all layers).
    ///
    /// - Parameters:
    ///   - nalUnits: NAL unit byte buffers in the framing identified by
    ///     `format`. Caller pre-extracts the unit boundaries.
    ///   - timing: shared timing for every sample produced for this AU.
    ///   - format: NAL framing (`.rawRBSP`, `.ebspWithPrefix`,
    ///     `.lengthPrefixed`, `.annexB`). The packager normalises every
    ///     input to a (header + EBSP body) NAL unit and then prefixes
    ///     each per-layer sample with the configuration's
    ///     `lengthSizeMinusOne + 1` byte length per ISO/IEC 14496-15 §A.
    /// - Returns: one ``LayerSampleOutput`` per layer present in this
    ///   AU. Layers absent from the AU are omitted.
    /// - Throws:
    ///   - ``MVHEVCPackagerError/alreadyStopped`` — `processAccessUnit`
    ///     called after ``stop()``.
    ///   - ``MVHEVCPackagerError/malformedNALUnit(reason:)`` — invalid
    ///     NAL header, truncated buffer, or invalid `lengthPrefixed`
    ///     prefix size.
    ///   - ``MVHEVCPackagerError/unexpectedLayerID(_:)`` — a NAL unit's
    ///     `nuh_layer_id` is not present in the configuration's layer
    ///     list.
    public func processAccessUnit(
        _ nalUnits: [Data],
        timing: CMAFSampleTiming,
        format: HEVCNALFormat
    ) async throws -> [LayerSampleOutput] {
        guard state == .active else {
            throw MVHEVCPackagerError.alreadyStopped
        }

        let normalisedUnits = try Self.normalise(nalUnits: nalUnits, format: format)
        // Reset per-AU layer buffers without releasing storage capacity.
        for layerID in layerLookup {
            perLayerBuffers[layerID] = Data()
        }

        for nalUnit in normalisedUnits {
            guard nalUnit.count >= 2 else {
                throw MVHEVCPackagerError.malformedNALUnit(
                    reason: "NAL unit shorter than 2-byte header"
                )
            }
            let byte0 = nalUnit[nalUnit.startIndex]
            let byte1 = nalUnit[nalUnit.startIndex.advanced(by: 1)]
            let nalLayerID = ((byte0 & 0x01) << 5) | ((byte1 >> 3) & 0x1F)
            guard layerLookup.contains(nalLayerID) else {
                throw MVHEVCPackagerError.unexpectedLayerID(nalLayerID)
            }
            appendLengthPrefixedNAL(
                nalUnit,
                toLayer: nalLayerID
            )
        }

        var outputs: [LayerSampleOutput] = []
        outputs.reserveCapacity(perLayerBuffers.count)
        for layerID in configuration.layerIDs {
            guard let buffer = perLayerBuffers[layerID], !buffer.isEmpty else {
                continue
            }
            outputs.append(
                LayerSampleOutput(
                    layerID: layerID,
                    bytes: buffer,
                    timing: timing,
                    flags: .syncSample,
                    isHeroLayer: heroLayerID == layerID
                )
            )
        }
        return outputs
    }

    /// Reset the packager's per-AU state without stopping the actor.
    ///
    /// Use this between segments (e.g., after a seek) when the next
    /// access unit no longer follows the previous one in decode order.
    /// The configuration and hero layer resolution are preserved.
    public func reset() async {
        perLayerBuffers.removeAll(keepingCapacity: true)
    }

    /// Terminate the actor.
    ///
    /// After ``stop()``, every call to ``processAccessUnit(_:timing:format:)``
    /// throws ``MVHEVCPackagerError/alreadyStopped``. ``reset()`` is a
    /// no-op once stopped.
    ///
    /// Calling ``stop()`` more than once is idempotent (subsequent calls
    /// observe ``State/stopped`` and free no additional resources).
    ///
    /// Callers MUST invoke ``stop()`` before letting the packager go out
    /// of scope, mirroring the ``CMAFMediaSegmentWriter`` finalisation
    /// doctrine. The actor's deinit cannot await this method due to
    /// Swift actor-isolation constraints.
    public func stop() async {
        perLayerBuffers.removeAll(keepingCapacity: false)
        state = .stopped
    }

    // MARK: - Internal helpers

    private func appendLengthPrefixedNAL(_ nalUnit: Data, toLayer layerID: UInt8) {
        var prefix = Data()
        let length = UInt32(nalUnit.count)
        switch lengthPrefixSize {
        case 1:
            prefix.append(UInt8(clamping: length))
        case 2:
            let value = UInt16(clamping: length).bigEndian
            withUnsafeBytes(of: value) { prefix.append(contentsOf: $0) }
        case 4:
            let value = length.bigEndian
            withUnsafeBytes(of: value) { prefix.append(contentsOf: $0) }
        default:
            // lengthSize of 3 is reserved per ISO/IEC 14496-15. We
            // fall back to 4 bytes — defensive: this branch is not
            // reachable because NALLengthSize only allows 1/2/4.
            let value = length.bigEndian
            withUnsafeBytes(of: value) { prefix.append(contentsOf: $0) }
        }
        var buffer = perLayerBuffers[layerID] ?? Data()
        buffer.append(prefix)
        buffer.append(nalUnit)
        perLayerBuffers[layerID] = buffer
    }

    /// Normalise a NAL unit list to a homogeneous `[Data]` where each
    /// entry is exactly one NAL unit beginning with the 2-byte NAL
    /// header. Mirrors the helper in ``HEVCParameterSets/extract(from:format:)``
    /// but kept local to avoid a public-symbol promotion.
    private static func normalise(
        nalUnits: [Data],
        format: HEVCNALFormat
    ) throws -> [Data] {
        switch format {
        case .rawRBSP, .ebspWithPrefix:
            return nalUnits
        case .lengthPrefixed(let prefixBytes):
            guard prefixBytes == 1 || prefixBytes == 2 || prefixBytes == 4 else {
                throw MVHEVCPackagerError.malformedNALUnit(
                    reason: "lengthPrefixed prefixBytes must be 1, 2, or 4"
                )
            }
            return try nalUnits.map { buffer in
                guard buffer.count >= Int(prefixBytes) else {
                    throw MVHEVCPackagerError.malformedNALUnit(
                        reason: "length-prefixed NAL truncated"
                    )
                }
                let bodyStart = buffer.index(
                    buffer.startIndex, offsetBy: Int(prefixBytes)
                )
                return buffer.subdata(in: bodyStart..<buffer.endIndex)
            }
        case .annexB:
            return try nalUnits.flatMap { try splitAnnexB($0) }
        }
    }

    private static func splitAnnexB(_ buffer: Data) throws -> [Data] {
        let bytes = Array(buffer)
        var units: [Data] = []
        var nalStart: Int?
        var index = 0
        while index < bytes.count {
            let isThreeByte =
                index + 2 < bytes.count
                && bytes[index] == 0x00
                && bytes[index + 1] == 0x00
                && bytes[index + 2] == 0x01
            let isFourByte =
                index + 3 < bytes.count
                && bytes[index] == 0x00
                && bytes[index + 1] == 0x00
                && bytes[index + 2] == 0x00
                && bytes[index + 3] == 0x01
            if isFourByte {
                if let start = nalStart {
                    units.append(Data(bytes[start..<index]))
                }
                index += 4
                nalStart = index
            } else if isThreeByte {
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
            throw MVHEVCPackagerError.malformedNALUnit(
                reason: "Annex B buffer carried no valid start code"
            )
        }
        return units
    }
}

extension MVHEVCPackager {

    /// Per-layer output of ``MVHEVCPackager/processAccessUnit(_:timing:format:)``.
    public struct LayerSampleOutput: Sendable, Equatable, Hashable {
        /// `nuh_layer_id` of the layer this sample carries.
        public let layerID: UInt8

        /// Length-prefixed NAL units for this layer — CMAF sample bytes
        /// ready for `mdat`.
        public let bytes: Data

        /// Per-sample timing forwarded from the access-unit input.
        public let timing: CMAFSampleTiming

        /// Per-sample flags. Defaults to ``SampleFlags/syncSample``;
        /// callers may override per their slice-type analysis when
        /// feeding the output into a ``CMAFMediaSegmentWriter``.
        public let flags: SampleFlags

        /// `true` when this layer's `layerID` matches the packager's
        /// resolved ``MVHEVCPackager/heroLayerID``. Used by the writer
        /// to flag the monoscopic fallback view.
        public let isHeroLayer: Bool

        public init(
            layerID: UInt8,
            bytes: Data,
            timing: CMAFSampleTiming,
            flags: SampleFlags,
            isHeroLayer: Bool
        ) {
            self.layerID = layerID
            self.bytes = bytes
            self.timing = timing
            self.flags = flags
            self.isHeroLayer = isHeroLayer
        }
    }
}

/// Typed errors thrown by ``MVHEVCPackager``.
public enum MVHEVCPackagerError: Error, Equatable {
    /// A NAL unit could not be parsed (truncated, invalid header,
    /// invalid `lengthPrefixed` prefix size, or missing Annex B start
    /// code).
    case malformedNALUnit(reason: String)

    /// A NAL unit's `nuh_layer_id` is not present in the configuration's
    /// declared layer list.
    case unexpectedLayerID(_ layerID: UInt8)

    /// A mutating method was called after ``MVHEVCPackager/stop()``.
    case alreadyStopped

    /// The configuration has no base-layer record. Reserved for future
    /// failure modes — the current initializer does not throw.
    case configurationMissingBaseLayer
}
