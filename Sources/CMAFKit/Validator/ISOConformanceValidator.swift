// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ISOConformanceValidator
//
// References:
// - ISO/IEC 14496-12 §4-§8 — Box structure + mandatory boxes
// - Apple QuickTime File Format Specification — historical reference
//
// Generic ISO Base Media File Format conformance validator. Applies to
// ANY ISO BMFF file (.mp4, .m4a, .mov, fragmented .m4s, HEIF, JPEG
// 2000, etc.) — independent of CMAF / DASH / HLS profile constraints.
//
// 8 spec-anchored rules I1-I8 per ISO/IEC 14496-12 §4-§8. Composable
// by higher-level validators (CMAFConformanceValidator,
// DASHConformanceValidator, LLHLSConformanceValidator) that need ISO
// structural checks plus profile-specific rules.

import Foundation

/// Generic ISO Base Media File Format conformance validator per
/// ISO/IEC 14496-12.
///
/// Validates ANY ISO BMFF file against the 8 spec-anchored structural
/// rules I1-I8. Independent of CMAF profile constraints — for
/// CMAF-specific validation use ``CMAFConformanceValidator`` (which
/// exposes this validator via ``CMAFConformanceValidator/isoValidator``).
///
/// **Use cases**:
/// - Standalone validation of arbitrary mp4 / fMP4 files (HLS init
///   segments, MOV captures, archive masters).
/// - Building block for CMAF / DASH / HLS validators.
/// - DRM provider tests that need ISO-layer sanity without CMAF noise.
///
/// References:
/// - ISO/IEC 14496-12 §4-§8 — Box structure + mandatory boxes
/// - Apple QuickTime File Format Specification — historical reference
///   (compatible subset)
public struct ISOConformanceValidator: Sendable {

    /// Validation level used by this instance.
    public let level: ISOConformanceLevel

    public init(level: ISOConformanceLevel = .strict) {
        self.level = level
    }

    /// Validate the in-memory representation of an ISO BMFF file (its
    /// top-level box list).
    ///
    /// - Parameter rootBoxes: parsed top-level boxes of the file.
    /// - Returns: a report listing all rule violations found.
    ///
    /// All 8 rules are evaluated in order I1 → I8; a violation on one
    /// rule does not short-circuit subsequent rules.
    public func validate(rootBoxes: [any ISOBox]) -> ISOConformanceReport {
        var issues: [ISOConformanceIssue] = []
        issues.append(contentsOf: checkRuleI1(rootBoxes: rootBoxes))
        issues.append(contentsOf: checkRuleI2(rootBoxes: rootBoxes))
        let moov = rootBoxes.compactMap { $0 as? MovieBox }.first
        if let moov {
            issues.append(contentsOf: checkRuleI3(moov: moov))
            issues.append(contentsOf: checkRuleI4(moov: moov))
            issues.append(contentsOf: checkRuleI5(moov: moov))
            issues.append(contentsOf: checkRuleI7(moov: moov))
            issues.append(contentsOf: checkRuleI8(moov: moov))
        }
        return ISOConformanceReport(issues: filtered(issues), level: level)
    }

    /// Parse raw bytes and validate.
    ///
    /// - Throws: parse errors from the ISO BMFF reader.
    public func validate(data: Data) async throws -> ISOConformanceReport {
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: data, using: registry)
        var issues = validate(rootBoxes: boxes).issues
        issues.append(contentsOf: checkRuleI6(data: data, boxes: boxes))
        return ISOConformanceReport(issues: filtered(issues), level: level)
    }

    /// Read a file then validate.
    public func validate(fileURL: URL) async throws -> ISOConformanceReport {
        let data = try Data(contentsOf: fileURL)
        return try await validate(data: data)
    }

    // MARK: - Permissive filtering

    private func filtered(_ issues: [ISOConformanceIssue]) -> [ISOConformanceIssue] {
        switch level {
        case .strict:
            return issues
        case .permissive:
            return issues.filter { $0.severity == .error }
        }
    }

    // MARK: - I1: ftyp present and first (or after leading mdat/free/skip)

    private func checkRuleI1(rootBoxes: [any ISOBox]) -> [ISOConformanceIssue] {
        guard !rootBoxes.isEmpty else {
            return [
                ISOConformanceIssue(
                    ruleID: .I1_FileTypePresent,
                    severity: .error,
                    message: "File contains no top-level boxes; `ftyp` is required.")
            ]
        }
        let hasFtyp = rootBoxes.contains { $0 is FileTypeBox }
        guard hasFtyp else {
            return [
                ISOConformanceIssue(
                    ruleID: .I1_FileTypePresent,
                    severity: .error,
                    message:
                        "File is missing the mandatory `ftyp` (FileTypeBox) per ISO/IEC 14496-12 §4.3."
                )
            ]
        }
        // Position check: ftyp SHOULD be first, or follow leading
        // free / skip / mdat (per the streaming-friendly convention).
        let preambleAllowed: Set<FourCC> = ["free", "skip", "mdat"]
        var sawFtyp = false
        for box in rootBoxes {
            if box is FileTypeBox {
                sawFtyp = true
                break
            }
            let fourCC = wireType(of: box)
            if !preambleAllowed.contains(fourCC) {
                return [
                    ISOConformanceIssue(
                        ruleID: .I1_FileTypePresent,
                        severity: .warning,
                        message:
                            "`ftyp` SHOULD precede non-preamble boxes; saw `\(fourCC)` first.",
                        context: "first box: \(fourCC)")
                ]
            }
        }
        _ = sawFtyp
        return []
    }

    // MARK: - I2: moov exactly once if present

    private func checkRuleI2(rootBoxes: [any ISOBox]) -> [ISOConformanceIssue] {
        let count = rootBoxes.filter { $0 is MovieBox }.count
        guard count > 1 else { return [] }
        return [
            ISOConformanceIssue(
                ruleID: .I2_MovieBoxUnique,
                severity: .error,
                message:
                    "ISO BMFF file MUST contain at most one `moov` box (found \(count)).",
                context: "moov occurrences: \(count)")
        ]
    }

    // MARK: - I3: track IDs unique within moov

    private func checkRuleI3(moov: MovieBox) -> [ISOConformanceIssue] {
        var seen: Set<UInt32> = []
        var duplicates: Set<UInt32> = []
        for track in moov.tracks {
            guard let trackID = track.trackHeader?.trackID else { continue }
            if !seen.insert(trackID).inserted {
                duplicates.insert(trackID)
            }
        }
        return duplicates.sorted().map { dup in
            ISOConformanceIssue(
                ruleID: .I3_TrackIDsUnique,
                severity: .error,
                message: "Duplicate track ID \(dup) inside `moov`.",
                context: "trackID: \(dup)")
        }
    }

    // MARK: - I4: mdhd.timescale > 0

    private func checkRuleI4(moov: MovieBox) -> [ISOConformanceIssue] {
        var issues: [ISOConformanceIssue] = []
        for track in moov.tracks {
            guard let mdhd = track.media?.findChild(MediaHeaderBox.self) else {
                continue
            }
            guard mdhd.timescale == 0 else { continue }
            let trackID = track.trackHeader?.trackID ?? 0
            issues.append(
                ISOConformanceIssue(
                    ruleID: .I4_MediaHeaderTimescalePositive,
                    severity: .error,
                    message: "`mdhd.timescale` MUST be > 0 (track \(trackID) has 0).",
                    context: "trackID: \(trackID)"))
        }
        return issues
    }

    // MARK: - I5: tkhd present and non-zero track_ID

    private func checkRuleI5(moov: MovieBox) -> [ISOConformanceIssue] {
        var issues: [ISOConformanceIssue] = []
        for (index, track) in moov.tracks.enumerated() {
            guard let tkhd = track.trackHeader else {
                issues.append(
                    ISOConformanceIssue(
                        ruleID: .I5_TrackHeaderIDCoherent,
                        severity: .error,
                        message: "`trak` at index \(index) is missing `tkhd`.",
                        context: "trakIndex: \(index)"))
                continue
            }
            if tkhd.trackID == 0 {
                issues.append(
                    ISOConformanceIssue(
                        ruleID: .I5_TrackHeaderIDCoherent,
                        severity: .error,
                        message: "`tkhd.track_ID` MUST be non-zero (track index \(index)).",
                        context: "trakIndex: \(index)"))
            }
        }
        return issues
    }

    // MARK: - I6: mdat size bounded by file length (data overload only)

    private func checkRuleI6(
        data: Data, boxes: [any ISOBox]
    ) -> [ISOConformanceIssue] {
        // The reader has already verified bounds; this is a belt-and-
        // braces check for callers who may pass truncated data.
        var issues: [ISOConformanceIssue] = []
        for box in boxes where box is MediaDataBox {
            if let mdat = box as? MediaDataBox, mdat.data.count > data.count {
                issues.append(
                    ISOConformanceIssue(
                        ruleID: .I6_MediaDataSizeBounded,
                        severity: .error,
                        message:
                            "`mdat` declared size (\(mdat.data.count) bytes) exceeds file size (\(data.count) bytes)."
                    ))
            }
        }
        return issues
    }

    // MARK: - I7: dref entries resolvable

    private func checkRuleI7(moov: MovieBox) -> [ISOConformanceIssue] {
        var issues: [ISOConformanceIssue] = []
        for track in moov.tracks {
            guard
                let minf = track.media?.findChild(MediaInformationBox.self),
                let dinf = minf.findChild(DataInformationBox.self),
                let dref = dinf.findChild(DataReferenceBox.self)
            else {
                continue
            }
            let trackID = track.trackHeader?.trackID ?? 0
            for (index, entry) in dref.entries.enumerated() {
                if let urlEntry = entry as? DataEntryURLBox {
                    let selfContained =
                        (urlEntry.flags & DataEntryURLBox.flagSelfContained) != 0
                    if !selfContained, urlEntry.location.isEmpty {
                        issues.append(
                            ISOConformanceIssue(
                                ruleID: .I7_DataReferenceResolvable,
                                severity: .error,
                                message:
                                    "External `url ` data entry has empty location (track \(trackID), dref entry \(index)).",
                                context: "trackID: \(trackID), dref[\(index)]"))
                    }
                }
            }
        }
        return issues
    }

    // MARK: - I8: container structure coherence

    private func checkRuleI8(moov: MovieBox) -> [ISOConformanceIssue] {
        var issues: [ISOConformanceIssue] = []
        // moov SHALL contain exactly one mvhd.
        if moov.movieHeader == nil {
            issues.append(
                ISOConformanceIssue(
                    ruleID: .I8_BoxStructureCoherent,
                    severity: .error,
                    message: "`moov` is missing the mandatory `mvhd`.",
                    context: "parent: moov"))
        }
        // Every trak SHALL contain exactly one mdia.
        for (index, track) in moov.tracks.enumerated() where track.media == nil {
            issues.append(
                ISOConformanceIssue(
                    ruleID: .I8_BoxStructureCoherent,
                    severity: .error,
                    message: "`trak` at index \(index) is missing the mandatory `mdia`.",
                    context: "trakIndex: \(index)"))
        }
        return issues
    }
}
