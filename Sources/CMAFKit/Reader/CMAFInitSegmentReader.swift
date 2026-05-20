// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFInitSegmentReader
//
// Reference: ISO/IEC 23000-19 §7.2 (CMAF Header init segment) and
// ISO/IEC 14496-12 §4.3 (FileTypeBox) + §8.2 (MovieBox).
//
// Stateless reader that decodes a CMAF init segment into a typed
// ``ParsedInitSegment`` value: the recovered
// ``CMAFTrackConfiguration`` array, the movie timescale, the
// optional movie-extends-header fragment duration, and every
// moov-level `pssh` box.
//
// All parsing happens at construction; the accessors are
// O(1) reads of cached results.

import Foundation

/// Stateless reader for a CMAF init segment.
public struct CMAFInitSegmentReader: Sendable {

    /// The fully parsed init segment.
    public let parsed: ParsedInitSegment

    /// Parse the supplied bytes via ``BoxRegistry/defaultRegistry()``.
    ///
    /// - Throws:
    ///   - ``CMAFReaderError/missingMandatoryBox(parent:missing:)``
    ///     when a required ISO BMFF box is absent.
    ///   - ``CMAFReaderError/initSegmentInconsistency(reason:)`` when
    ///     the box tree decodes but the resulting structure is
    ///     internally inconsistent.
    public init(bytes: Data) async throws {
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        self.parsed = try CMAFInitSegmentReader.compose(boxes: boxes)
    }

    /// Construct directly from an already-parsed box list (for
    /// callers that have walked the registry themselves).
    public init(boxes: [any ISOBox]) throws {
        self.parsed = try CMAFInitSegmentReader.compose(boxes: boxes)
    }

    // MARK: - Public accessors

    public func tracks() -> [CMAFTrackConfiguration] {
        parsed.trackConfigurations
    }

    public func protectionSystemSpecificHeaders() -> [ProtectionSystemSpecificHeaderBox] {
        parsed.protectionSystemSpecificHeaders
    }

    public func movieTimescale() -> UInt32 {
        parsed.movieTimescale
    }

    public func fragmentDurationIfPresent() -> UInt64? {
        parsed.fragmentDuration
    }

    public func majorBrand() -> FourCC {
        parsed.majorBrand
    }

    public func compatibleBrands() -> [FourCC] {
        parsed.compatibleBrands
    }

    // MARK: - Composition

    private static func compose(boxes: [any ISOBox]) throws -> ParsedInitSegment {
        guard let ftyp = boxes.compactMap({ $0 as? FileTypeBox }).first else {
            throw CMAFReaderError.missingMandatoryBox(parent: "root", missing: "ftyp")
        }
        guard let moov = boxes.compactMap({ $0 as? MovieBox }).first else {
            throw CMAFReaderError.missingMandatoryBox(parent: "root", missing: "moov")
        }
        guard let mvhd = moov.movieHeader else {
            throw CMAFReaderError.missingMandatoryBox(parent: "moov", missing: "mvhd")
        }
        let profile = resolveProfile(majorBrand: ftyp.majorBrand)
        let psshBoxes = moov.children
            .compactMap { $0 as? ProtectionSystemSpecificHeaderBox }
        let trackConfigurations = try moov.tracks.map { trak in
            try CMAFTrackResolver.resolve(
                trak: trak,
                profile: profile,
                psshBoxes: psshBoxes
            )
        }
        let mehdDuration = moov.children
            .compactMap { $0 as? MovieExtendsBox }
            .first?
            .children
            .compactMap { $0 as? MovieExtendsHeaderBox }
            .first?
            .fragmentDuration
        return ParsedInitSegment(
            trackConfigurations: trackConfigurations,
            movieTimescale: mvhd.timescale,
            fragmentDuration: mehdDuration,
            protectionSystemSpecificHeaders: psshBoxes,
            majorBrand: ftyp.majorBrand,
            compatibleBrands: ftyp.compatibleBrands
        )
    }

    private static func resolveProfile(majorBrand: FourCC) -> CMAFProfile {
        switch majorBrand {
        case "cmfc": return .basic
        case "cmf2": return .multiStream
        case "cmff": return .fragmented
        case "cmfl": return .lowLatency
        case "cmfs": return .segmented
        case "cmfd": return .dash
        case "cmfh": return .hls
        default: return .basic
        }
    }
}
