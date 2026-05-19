// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFWriterError
//
// Reference: ISO/IEC 23000-19 (CMAF) and ISO/IEC 14496-12 (ISO BMFF).
//
// Typed error enum surfaced by every fragmentation-writer code path.
// All malformed-input conditions throw an instance of this enum rather
// than crashing via `precondition`. Library invariants (impossible
// internal states) still use `precondition`.

import Foundation

/// Errors thrown by the CMAF fragmentation writers.
///
/// Every malformed user input — invalid configuration, sample that
/// breaks an invariant, fragment-boundary misuse — surfaces here.
/// Library invariants that cannot fail without a programming bug
/// remain on the `precondition` path.
public enum CMAFWriterError: Error, Sendable, Equatable {
    /// The supplied track or writer configuration is internally
    /// inconsistent (mismatched fields, missing mandatory data).
    case configurationInvalid(reason: String)
    /// A per-sample input violated an invariant
    /// (negative duration, zero-length bytes when prohibited, ...).
    case sampleInvalid(reason: String)
    /// The chosen fragment-boundary strategy cannot be satisfied
    /// with the supplied samples (e.g., `onSyncSample` with no sync
    /// sample yet observed).
    case fragmentBoundaryViolation(reason: String)
    /// A track's declared timescale does not match the timescale
    /// already observed for that track.
    case timescaleInconsistent(track: UInt32, expected: UInt32, actual: UInt32)
    /// A sample's encoded size cannot fit in the 32-bit field
    /// emitted by `trun` per ISO/IEC 14496-12 §8.8.8.
    case sampleSizeOverflow(sampleNumber: UInt32)
    /// A sample's decode time cannot fit in `tfdt`'s 64-bit field
    /// (this should not happen for any practically representable clip).
    case decodeTimeOverflow(sampleNumber: UInt32)
    /// The track is encrypted but no `CMAFEncryptionParameters` were
    /// supplied for it.
    case encryptionParametersMissing(track: UInt32)
    /// A per-sample IV is not the size declared by the track's
    /// `defaultPerSampleIVSize`.
    case encryptionIVSizeMismatch(declared: UInt8, actual: UInt8)
    /// The sum of `bytesOfClearData + bytesOfProtectedData` across a
    /// subsample partition does not equal the sample's encoded size.
    case subsamplePartitionExceedsSampleSize(
        sampleNumber: UInt32,
        partitionTotal: UInt32,
        sampleSize: UInt32
    )
    /// `emitSegmentIndex` was requested but the writer has produced
    /// no fragments yet.
    case sidxEmitWithoutFragments
    /// The named CMAF profile is unrecognised. Should not normally
    /// fire because `CMAFProfile` is exhaustive — reserved for
    /// forward-compatible deserialisation paths.
    case unsupportedCMAFProfile(profile: String)
    /// A composed structure violates a CMAF (ISO/IEC 23000-19)
    /// conformance rule that the writer enforces. The `rule` string
    /// names the rule for diagnostic purposes.
    case cmafConformanceViolation(rule: String)
}
