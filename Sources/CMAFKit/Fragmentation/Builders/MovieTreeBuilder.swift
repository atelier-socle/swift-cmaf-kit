// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MovieTreeBuilder
//
// Reference: ISO/IEC 14496-12 §8.2 (MovieBox / MovieHeaderBox),
// §8.7 (MovieExtendsBox / MovieExtendsHeaderBox / TrackExtendsBox).
//
// Composes the `moov` subtree for an init segment. For a fragmented
// CMAF presentation, `moov` always carries an `mvex` block so that
// readers know to expect `moof`+`mdat` fragments after the init.

import Foundation

/// Internal helper composing the `moov` subtree.
internal enum MovieTreeBuilder {

    /// Compose the `moov` for a set of track configurations.
    ///
    /// - Parameters:
    ///   - configurations: one or more track configurations.
    ///   - referenceTimestamp: the writer's reference timestamp used
    ///     in `mvhd` and per-`tkhd` creation_time / modification_time.
    ///   - movieTimescale: the movie-level timescale emitted in `mvhd`.
    ///   - fragmentDuration: optional total fragmented duration; when
    ///     non-nil the writer emits an `mehd` box. Set this only for
    ///     finite presentations (VOD); leave nil for live.
    static func makeMovieBox(
        configurations: [CMAFTrackConfiguration],
        referenceTimestamp: UInt64,
        movieTimescale: UInt32,
        fragmentDuration: UInt64? = nil
    ) throws -> MovieBox {
        precondition(!configurations.isEmpty, "MovieTreeBuilder requires at least one track")

        var children: [any ISOBox] = []

        let nextTrackID = (configurations.map { $0.trackID }.max() ?? 0) &+ 1
        let mvhd = MovieHeaderBox(
            version: 1,
            creationTime: referenceTimestamp,
            modificationTime: referenceTimestamp,
            timescale: movieTimescale,
            duration: fragmentDuration ?? 0,
            nextTrackID: nextTrackID
        )
        children.append(mvhd)

        // Per-DRM `pssh` boxes from any track's encryption parameters.
        // ISO/IEC 23001-7 §8.1.2 places these at the movie level.
        let psshBoxes =
            configurations
            .compactMap { $0.encryptionParameters?.psshBoxes }
            .flatMap { $0 }
        for pssh in psshBoxes {
            children.append(pssh)
        }

        // One `trak` per configuration.
        for configuration in configurations {
            let trak = try TrackTreeBuilder.makeTrackBox(
                configuration: configuration,
                referenceTimestamp: referenceTimestamp,
                movieTimescale: movieTimescale
            )
            children.append(trak)
        }

        // `mvex` with `mehd` (if duration known) + one `trex` per track.
        children.append(
            makeMovieExtends(
                configurations: configurations,
                fragmentDuration: fragmentDuration
            ))

        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        return MovieBox(header: moovHeader, children: children)
    }

    // MARK: - Sub-builders

    private static func makeMovieExtends(
        configurations: [CMAFTrackConfiguration],
        fragmentDuration: UInt64?
    ) -> MovieExtendsBox {
        var children: [any ISOBox] = []
        if let duration = fragmentDuration {
            children.append(MovieExtendsHeaderBox(version: 1, fragmentDuration: duration))
        }
        for configuration in configurations {
            children.append(
                TrackExtendsBox(
                    trackID: configuration.trackID,
                    defaultSampleDescriptionIndex: 1,
                    defaultSampleDuration: 0,
                    defaultSampleSize: 0,
                    defaultSampleFlags: configuration.defaultSampleFlags.rawValue
                ))
        }
        let mvexHeader = ISOBoxHeader(type: "mvex", size: 0, headerSize: 8)
        return MovieExtendsBox(header: mvexHeader, children: children)
    }
}
