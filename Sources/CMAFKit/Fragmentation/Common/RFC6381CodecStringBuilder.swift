// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - RFC6381CodecStringBuilder
//
// Reference: IETF RFC 6381 — "The 'Codecs' and 'Profiles' Parameters
// for 'Bucket' Media Types", ISO/IEC 14496-15 §A.5 (CMAF codec parameter
// generation), Apple HLS Authoring Specification §2.2 (HLS codec string
// conventions), DASH-IF Implementation Guidelines §4 (DASH codec
// strings), AOMedia AV1 Codec ISO Media Format Binding §5 (AV1 codec
// string), ETSI TS 102 366 Annex H (E-AC-3 JOC), ISO/IEC 23008-3 §1
// (MPEG-H 3D Audio PLI).
//
// Public surface only — per-codec builder + parser helpers live in
// `RFC6381CodecStringBuilder+Internal.swift` so the main struct body
// stays within SwiftLint's `type_body_length` budget and each helper
// stays within `function_parameter_count`.

import Foundation

/// Builds and parses RFC 6381 `codecs=` attribute values for CMAF tracks.
///
/// The builder produces canonical, byte-identical codec strings that
/// match the dominant player-ecosystem conventions (ffprobe output,
/// Apple HLS authoring, DASH-IF reference). The parser handles
/// comma-separated multi-codec strings and is the inverse of the
/// builder — round-trip is byte-identical for every well-formed
/// descriptor.
///
/// References:
/// - IETF RFC 6381 — `Codecs` parameter syntax + examples
/// - ISO/IEC 14496-15 §A.5 — CMAF codec parameter generation
/// - Apple HLS Authoring Specification §2.2
/// - DASH-IF Implementation Guidelines §4
public struct RFC6381CodecStringBuilder: Sendable {

    public init() {}

    /// Build the canonical RFC 6381 codec string for a CMAF track
    /// configuration.
    ///
    /// Reads the codec from the track's `codecConfiguration` and emits
    /// the matching string. Sessions 5-6 wire the remaining audio codecs
    /// (ALAC, PCM ipcm/fpcm/lpcm); calling `codecString(for:)` on a
    /// track configured for those codecs throws
    /// ``RFC6381BuilderError/unsupportedCodec(reason:)`` until those
    /// sessions land.
    ///
    /// - Throws:
    ///   - ``RFC6381BuilderError/unsupportedCodec(reason:)`` — the codec
    ///     is recognised but its dispatch from
    ///     ``CMAFTrackConfiguration`` is not yet wired in 0.1.1.
    ///   - ``RFC6381BuilderError/missingConfiguration(codec:)`` — the
    ///     track configuration is missing data needed to build the
    ///     codec string for the declared codec.
    public func codecString(for configuration: CMAFTrackConfiguration) throws -> String {
        switch configuration.kind {
        case .video: return try Self.videoCodecString(for: configuration)
        case .audio: return try Self.audioCodecString(for: configuration)
        case .subtitle: return try Self.subtitleCodecString(for: configuration)
        case .metadata:
            throw RFC6381BuilderError.unsupportedCodec(
                reason: "metadata tracks do not have an RFC 6381 codec string"
            )
        }
    }

    /// Build the canonical codec string from a typed descriptor.
    ///
    /// This is the lower-level entry point — pass a fully-constructed
    /// descriptor and get the canonical string. Does not throw; the
    /// descriptor itself is the validation surface.
    public func codecString(for descriptor: RFC6381CodecDescriptor) -> String {
        switch descriptor {
        case .avc(let kind, let profile, let constraint, let level):
            let pp = String(format: "%02x", profile)
            let cc = String(format: "%02x", constraint)
            let ll = String(format: "%02x", level)
            return "\(kind.rawValue).\(pp)\(cc)\(ll)"
        case .hevc(let kind, let space, let prof, let compat, let tier, let lev, let flags):
            return Self.hevcCodecString(
                fourCC: kind.rawValue,
                profile: HEVCProfileDescriptor(
                    profileSpace: space, profile: prof, profileCompat: compat,
                    tier: tier, level: lev, constraintFlags: flags
                )
            )
        case .mvHEVC(let base, _, _):
            return Self.hevcCodecString(fourCC: "hvc2", profile: base)
        case .av1: return Self.av1CodecString(descriptor: descriptor)
        case .dolbyVision(let kind, let profile, let level):
            return "\(kind.rawValue).\(Self.zeroPadded2Decimal(profile.wireProfileNumber))"
                + ".\(Self.zeroPadded2Decimal(level.rawValue))"
        case .vp9: return Self.vp9CodecString(descriptor: descriptor)
        case .vp8: return "vp08"
        case .aac(let profile): return "mp4a.40.\(profile.rawValue)"
        case .ac3: return "ac-3"
        case .ec3: return "ec-3"
        case .ac4(let id): return id.map { "ac-4.\($0)" } ?? "ac-4"
        case .mpegH(let kind, let pli):
            return "\(kind.rawValue).0x\(String(format: "%02X", pli))"
        case .opus: return "Opus"
        case .flac: return "fLaC"
        case .alac: return "alac"
        case .pcmIPCM: return "ipcm"
        case .pcmFPCM: return "fpcm"
        case .pcmLPCM: return "lpcm"
        case .webVTT: return "wvtt"
        case .imsc1Text: return "stpp.ttml.im1t"
        case .imsc1Image: return "stpp.ttml.im1i"
        }
    }

    /// Parse a comma-separated RFC 6381 codec string into descriptors.
    ///
    /// Trims whitespace around commas (`"avc1.640028, mp4a.40.2"` → 2
    /// descriptors). Throws
    /// ``RFC6381BuilderError/malformedCodecString(input:reason:)`` on
    /// any parse failure, with the full input embedded for caller
    /// diagnostics.
    public func parse(_ codecString: String) throws -> [RFC6381CodecDescriptor] {
        let trimmed = codecString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw RFC6381BuilderError.malformedCodecString(
                input: codecString,
                reason: "input is empty after trimming whitespace"
            )
        }
        var descriptors: [RFC6381CodecDescriptor] = []
        for raw in trimmed.split(separator: ",") {
            let segment = raw.trimmingCharacters(in: .whitespaces)
            descriptors.append(
                try Self.parseSingleSegment(segment, fullInput: codecString)
            )
        }
        return descriptors
    }
}
