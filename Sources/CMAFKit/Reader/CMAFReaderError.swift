// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFReaderError
//
// Reference: ISO/IEC 23000-19 (CMAF) and ISO/IEC 23001-7 (Common
// Encryption). Errors surfaced by the high-level CMAF reading
// path. Lower-level binary I/O errors propagate as ``ISOBoxError``
// or ``BinaryIOError``; this enum wraps semantic / structural
// inconsistencies that only surface once the box tree has been
// reconstructed.

import Foundation

/// Errors thrown by the high-level CMAF reading API.
public enum CMAFReaderError: Error, Sendable, Equatable {
    /// A box mandated by the standard is missing inside a parent
    /// container.
    case missingMandatoryBox(parent: FourCC, missing: FourCC)
    /// A box appeared at an ISO BMFF level where the standard
    /// forbids it.
    case unexpectedBoxAtLevel(parent: FourCC, found: FourCC)
    /// A `tfhd.trackID` referenced a track that is not part of the
    /// init segment's `moov`.
    case trackNotFound(trackID: UInt32)
    /// A sample's declared offset/size would read past the end of
    /// the carrying `mdat`.
    case sampleDataExceedsMDAT(trackID: UInt32, sampleIndex: UInt32)
    /// The reader needs the track's `TrackEncryptionBox` to parse
    /// `senc` (option B explicit dispatch) but no context was
    /// supplied in the constructor.
    case encryptionContextMissing(trackID: UInt32)
    /// The per-sample IV size found inside `senc` does not match
    /// the value declared in the init segment's `tenc`.
    case ivSizeMismatch(declared: UInt8, parsedFromSENC: UInt8)
    /// The init segment is structurally inconsistent (e.g.,
    /// declares more tracks in `mvhd.nextTrackID` than `moov`
    /// actually contains).
    case initSegmentInconsistency(reason: String)
    /// A media segment is inconsistent with its companion init
    /// segment (e.g., declares a track ID `moov` does not know).
    case mediaSegmentInconsistency(reason: String)
    /// A higher-level conformance validator surfaced one or more
    /// `.error`-severity issues.
    case validationFailed(report: CMAFValidationReport)
}
