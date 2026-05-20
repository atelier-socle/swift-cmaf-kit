// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFMediaSegmentWriter — construction-time validators
//
// Reference: ISO/IEC 23000-19 (CMAF) §6 and §7 conformance rules,
// ISO/IEC 23009-1 §6.3 (DASH ISO BMFF profile), IETF RFC 8216bis-13
// §B.4.1 (LL-HLS partial chunks), and ISO/IEC 23001-7 (Common
// Encryption) per-scheme constraints.
//
// Houses the static `validate(...)` helper that
// ``CMAFMediaSegmentWriter.init`` invokes before storing any state.
// Kept in a separate file so the actor's primary type body stays
// within the project's structural-length convention.

import Foundation

extension CMAFMediaSegmentWriter {

    /// Construction-time conformance gate. Throws on every rule
    /// CMAFKit chooses to enforce at writer init.
    internal static func validate(
        configuration: CMAFTrackConfiguration,
        fragmentBoundary: CMAFFragmentBoundary,
        partialChunkBoundary: CMAFPartialChunkBoundary?,
        emitSegmentIndex: Bool
    ) throws {
        try validateTrackKindEncryption(configuration: configuration)
        try validateDolbyVision(configuration: configuration)
        try validateMPEGHProfile(configuration: configuration)
        try validateEncryptionCoherence(configuration: configuration)
        try validateDASHProfile(
            configuration: configuration,
            partialChunkBoundary: partialChunkBoundary,
            emitSegmentIndex: emitSegmentIndex
        )
        try validateLowLatencyProfile(
            configuration: configuration,
            partialChunkBoundary: partialChunkBoundary
        )
        try validateSidxFragmentReachability(
            fragmentBoundary: fragmentBoundary,
            emitSegmentIndex: emitSegmentIndex
        )
    }

    private static func validateTrackKindEncryption(
        configuration: CMAFTrackConfiguration
    ) throws {
        switch configuration.kind {
        case .subtitle, .metadata:
            if configuration.encryptionParameters != nil {
                throw CMAFWriterError.cmafConformanceViolation(
                    rule:
                        "ISO/IEC 23001-7: Common Encryption is only defined for audio "
                        + "and video sample types; subtitle and metadata tracks must "
                        + "not carry CMAFEncryptionParameters"
                )
            }
        case .video, .audio:
            break
        }
    }

    private static func validateDolbyVision(
        configuration: CMAFTrackConfiguration
    ) throws {
        guard let video = configuration.videoFields else { return }
        if video.codec == .dvh1 || video.codec == .dvhe {
            if video.dolbyVisionConfiguration == nil {
                throw CMAFWriterError.cmafConformanceViolation(
                    rule:
                        "Dolby Vision Profile track must carry a "
                        + "DolbyVisionConfigurationBox (dvcC) in its VideoFields"
                )
            }
        }
    }

    private static func validateMPEGHProfile(
        configuration: CMAFTrackConfiguration
    ) throws {
        guard let audio = configuration.audioFields,
            audio.codec == .mpegHMain || audio.codec == .mpegHMultiStream
        else { return }
        switch configuration.profile {
        case .multiStream, .fragmented, .lowLatency:
            break
        default:
            throw CMAFWriterError.cmafConformanceViolation(
                rule:
                    "ISO/IEC 23000-19 \u{00A7}6.5: MPEG-H 3D Audio requires the "
                    + "multi-stream or fragmented CMAF profile"
            )
        }
    }

    private static func validateEncryptionCoherence(
        configuration: CMAFTrackConfiguration
    ) throws {
        guard let encryption = configuration.encryptionParameters else { return }
        if encryption.scheme == .cbcs, let iv = encryption.defaultConstantIV {
            if iv.rawBytes.count != 16 {
                throw CMAFWriterError.cmafConformanceViolation(
                    rule:
                        "ISO/IEC 23001-7 \u{00A7}10.4: cbcs default_constant_IV "
                        + "must be exactly 16 bytes"
                )
            }
        }
        if encryption.scheme == .cens || encryption.scheme == .cbcs {
            if encryption.defaultPerSampleIVSize == .zero
                && encryption.defaultConstantIV == nil
            {
                throw CMAFWriterError.cmafConformanceViolation(
                    rule:
                        "ISO/IEC 23001-7: pattern schemes cens/cbcs require either "
                        + "a non-zero defaultPerSampleIVSize or a defaultConstantIV"
                )
            }
        }
    }

    private static func validateDASHProfile(
        configuration: CMAFTrackConfiguration,
        partialChunkBoundary: CMAFPartialChunkBoundary?,
        emitSegmentIndex: Bool
    ) throws {
        guard configuration.profile == .dash else { return }
        if !emitSegmentIndex {
            throw CMAFWriterError.cmafConformanceViolation(
                rule:
                    "ISO/IEC 23009-1 \u{00A7}6.3: DASH CMAF segments must carry a "
                    + "Segment Index (sidx); enable emitSegmentIndex"
            )
        }
        if partialChunkBoundary != nil {
            throw CMAFWriterError.cmafConformanceViolation(
                rule:
                    "ISO/IEC 23009-1: DASH CMAF segments do not use LL-HLS "
                    + "partial chunks; remove the partialChunkBoundary"
            )
        }
    }

    private static func validateLowLatencyProfile(
        configuration: CMAFTrackConfiguration,
        partialChunkBoundary: CMAFPartialChunkBoundary?
    ) throws {
        guard configuration.profile == .lowLatency else { return }
        if partialChunkBoundary == nil {
            throw CMAFWriterError.cmafConformanceViolation(
                rule:
                    "IETF RFC 8216bis \u{00A7}B.4.1: the low-latency CMAF profile "
                    + "requires partialChunkBoundary to be set"
            )
        }
    }

    private static func validateSidxFragmentReachability(
        fragmentBoundary: CMAFFragmentBoundary,
        emitSegmentIndex: Bool
    ) throws {
        guard emitSegmentIndex else { return }
        if case .sampleCount(let target) = fragmentBoundary, target == UInt32.max {
            throw CMAFWriterError.sidxEmitWithoutFragments
        }
    }
}
