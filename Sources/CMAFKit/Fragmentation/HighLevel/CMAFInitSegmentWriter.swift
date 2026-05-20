// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFInitSegmentWriter
//
// Reference: ISO/IEC 23000-19 §7.2 (CMAF Header / init segment) and
// ISO/IEC 14496-12 §4.3 (FileTypeBox) + §8.2 (MovieBox).
//
// Stateless writer that emits a complete CMAF init segment from a
// validated set of track configurations. The emitted byte stream
// consists of:
//
//   ftyp + (optional moov-level pssh boxes) + moov
//
// Same configuration → byte-identical output (deterministic). When
// any track configuration carries ``CMAFEncryptionParameters``, the
// writer:
//
//   1. Rewrites the sample-entry FourCC to `encv` / `enca` and
//      composes the full `sinf` / `frma` / `schm` / `schi` / `tenc`
//      group from Session 9.
//   2. Emits each provided `pssh` box at the `moov` level per
//      ISO/IEC 23001-7 §8.1.
//
// Audio tracks with non-zero ``AudioPriming.preSkip`` automatically
// receive an `edts/elst` with `mediaTime == preSkip` so playback
// skips the codec's encoder delay.

import Foundation

/// Stateless writer that emits a complete CMAF init segment.
public struct CMAFInitSegmentWriter: Sendable {

    /// Movie timescale emitted in `mvhd`. CMAFKit picks 1000
    /// (millisecond granularity) by default; consumers can override
    /// when the presentation requires a different convention.
    public let movieTimescale: UInt32

    /// Optional reference timestamp emitted in `mvhd.creationTime`
    /// and per-track `tkhd.creationTime` / `tkhd.modificationTime`.
    /// In seconds since 1904-01-01 00:00:00 UTC per ISO/IEC 14496-12
    /// §8.2.2. Default 0.
    public let referenceTimestamp: UInt64

    private let configurations: [CMAFTrackConfiguration]

    /// Construct a writer for one or more track configurations.
    ///
    /// - Throws: ``CMAFWriterError/configurationInvalid(reason:)``
    ///   when the supplied configurations violate the writer's
    ///   structural invariants (empty list, duplicate track IDs,
    ///   inconsistent profiles).
    public init(
        configurations: [CMAFTrackConfiguration],
        movieTimescale: UInt32 = 1000,
        referenceTimestamp: UInt64 = 0
    ) throws {
        guard !configurations.isEmpty else {
            throw CMAFWriterError.configurationInvalid(
                reason: "init segment requires at least one track"
            )
        }

        let trackIDs = configurations.map { $0.trackID }
        if Set(trackIDs).count != trackIDs.count {
            throw CMAFWriterError.configurationInvalid(
                reason: "track IDs must be unique"
            )
        }

        let profiles = Set(configurations.map { $0.profile })
        if profiles.count > 1 {
            throw CMAFWriterError.configurationInvalid(
                reason: "all tracks must share the same CMAFProfile"
            )
        }

        self.configurations = configurations
        self.movieTimescale = movieTimescale
        self.referenceTimestamp = referenceTimestamp
    }

    /// Emit the init segment bytes.
    ///
    /// The output is `ftyp` + moov-level `pssh` boxes (one per
    /// encryption parameter set, in track order) + `moov`.
    public func emit() throws -> Data {
        let ftyp = BrandComposer.makeFileTypeBox(configurations: configurations)
        let moov = try MovieTreeBuilder.makeMovieBox(
            configurations: configurations,
            referenceTimestamp: referenceTimestamp,
            movieTimescale: movieTimescale
        )

        var writer = BinaryWriter()
        ftyp.encode(to: &writer)
        moov.encode(to: &writer)
        return writer.data
    }
}
