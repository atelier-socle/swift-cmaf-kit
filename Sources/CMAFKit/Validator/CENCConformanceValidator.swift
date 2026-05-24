// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CENCConformanceValidator
//
// References:
// - ISO/IEC 23001-7 §4 — Common Encryption File Format
// - ISO/IEC 23001-7 §4.5-§4.9 — sinf / frma / schm / schi / tenc /
//   pssh / senc / saiz / saio
// - DASH-IF Implementation Guidelines v5.0+ §6.3 — DRM bindings
//
// Generic Common Encryption conformance validator. Applies to ANY
// CENC-protected ISO BMFF file — independent of CMAF / DASH / HLS
// profile constraints.
//
// 8 spec-anchored rules C1-C8 per ISO/IEC 23001-7 §4.5-§4.9. Composed
// by higher-level validators (CMAFConformanceValidator,
// DASHConformanceValidator) when CENC protection is detected.

import Foundation

/// Common Encryption conformance validator per ISO/IEC 23001-7.
///
/// Validates ANY CENC-protected ISO BMFF file against the 8
/// spec-anchored cryptographic rules C1-C8. Independent of CMAF
/// profile constraints — for CMAF-specific CENC validation use
/// ``CMAFConformanceValidator/cencValidator``.
///
/// **Use cases**:
/// - Standalone CENC validation for DRM provider tests.
/// - Building block for CMAF / DASH validators composed via
///   ``CMAFConformanceValidator``.
/// - CMAFKitDRM integration tests (verify DRM-protected output is
///   well-formed against the CENC spec).
///
/// References:
/// - ISO/IEC 23001-7 §4 — Common Encryption File Format
/// - ISO/IEC 23001-7 §4.5-§4.9 — sinf / frma / schm / schi / tenc /
///   pssh / senc / saiz / saio
public struct CENCConformanceValidator: Sendable {

    public let level: CENCConformanceLevel

    public init(level: CENCConformanceLevel = .strict) {
        self.level = level
    }

    /// Validate the encrypted-track aspects of an ISO BMFF file's
    /// top-level box list. Non-encrypted files produce an empty
    /// report.
    public func validate(rootBoxes: [any ISOBox]) -> CENCConformanceReport {
        var issues: [CENCConformanceIssue] = []
        let moov = rootBoxes.compactMap { $0 as? MovieBox }.first

        if let moov {
            issues.append(contentsOf: checkRulesC1ThroughC5(moov: moov))
        }
        issues.append(contentsOf: checkRuleC6(rootBoxes: rootBoxes))
        if let moov {
            issues.append(contentsOf: checkRulesC7AndC8(moov: moov, rootBoxes: rootBoxes))
        }

        return CENCConformanceReport(issues: filtered(issues), level: level)
    }

    /// Parse raw bytes and validate.
    public func validate(data: Data) async throws -> CENCConformanceReport {
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: data, using: registry)
        return validate(rootBoxes: boxes)
    }

    /// Read a file then validate.
    public func validate(fileURL: URL) async throws -> CENCConformanceReport {
        let data = try Data(contentsOf: fileURL)
        return try await validate(data: data)
    }

    /// True when the input contains at least one CENC-protected
    /// track. Useful to short-circuit clear (non-DRM) files.
    public func detectsCENCProtection(in rootBoxes: [any ISOBox]) -> Bool {
        guard let moov = rootBoxes.compactMap({ $0 as? MovieBox }).first else {
            return false
        }
        for track in moov.tracks where !encryptedSampleEntries(in: track).isEmpty {
            return true
        }
        return false
    }

    // MARK: - Permissive filter

    private func filtered(_ issues: [CENCConformanceIssue]) -> [CENCConformanceIssue] {
        switch level {
        case .strict: return issues
        case .permissive: return issues.filter { $0.severity == .error }
        }
    }

    // MARK: - Encrypted sample-entry discovery

    /// Encrypted sample entries inside a `trak` per their fourCC.
    /// `enca` / `encv` / `enct` are dispatched as either
    /// ``EncryptedAudioSampleEntry`` / ``EncryptedVideoSampleEntry``
    /// (typed), as ``RawSampleEntry`` (untyped fallback), or via
    /// ``UnknownBox`` when not parseable at all.
    private func encryptedSampleEntries(in track: TrackBox) -> [any ISOBox] {
        guard
            let stsd = track.media?
                .findChild(MediaInformationBox.self)?
                .findChild(SampleTableBox.self)?
                .findChild(SampleDescriptionBox.self)
        else { return [] }
        let encryptedFourCCs: Set<FourCC> = ["enca", "encv", "enct"]
        var result: [any ISOBox] = []
        for entry in stsd.entries where encryptedFourCCs.contains(entryFourCC(entry)) {
            result.append(entry)
        }
        return result
    }

    /// FourCC of a sample entry — accounting for ``RawSampleEntry``
    /// which uses a sentinel `boxType` and carries the real format in
    /// its ``RawSampleEntry/format`` field.
    private func entryFourCC(_ entry: any ISOBox) -> FourCC {
        if let raw = entry as? RawSampleEntry {
            return raw.format
        }
        return wireType(of: entry)
    }

    // MARK: - C1..C5: sample-entry-level CENC structure

    private func checkRulesC1ThroughC5(moov: MovieBox) -> [CENCConformanceIssue] {
        var issues: [CENCConformanceIssue] = []
        for track in moov.tracks {
            let trackID = track.trackHeader?.trackID ?? 0
            for entry in encryptedSampleEntries(in: track) {
                let fourCC = entryFourCC(entry)
                let context = "trackID: \(trackID), sampleEntry: \(fourCC)"
                let sinf: ProtectionSchemeInfoBox?
                if let audioEnc = entry as? EncryptedAudioSampleEntry {
                    sinf = audioEnc.protectionSchemeInfo
                } else if let videoEnc = entry as? EncryptedVideoSampleEntry {
                    sinf = videoEnc.protectionSchemeInfo
                } else {
                    sinf = nil
                }
                guard let sinf else {
                    // C1: enca/encv/enct without resolvable sinf.
                    issues.append(
                        CENCConformanceIssue(
                            ruleID: .C1_EncryptedSampleEntryHasSinf,
                            severity: .error,
                            message:
                                "Encrypted sample entry `\(fourCC)` does not carry a parseable `sinf` (ProtectionSchemeInfoBox).",
                            context: context))
                    continue
                }
                // C2: sinf.frma is non-Optional in our model; if its
                // dataFormat is the unrecognised sentinel `"    "`,
                // surface that as a C2 issue.
                let originalFourCC = sinf.originalFormat.dataFormat.description
                let isBlank = originalFourCC.allSatisfy { $0 == " " || $0 == "\0" }
                if isBlank || originalFourCC.isEmpty {
                    issues.append(
                        CENCConformanceIssue(
                            ruleID: .C2_SinfHasFrma,
                            severity: .error,
                            message:
                                "`sinf.frma` does not carry a valid original-format fourCC.",
                            context: context))
                }
                // C3: schm must be present and scheme_type ∈ {cenc, cbc1, cens, cbcs}.
                guard let schm = sinf.schemeType else {
                    issues.append(
                        CENCConformanceIssue(
                            ruleID: .C3_SinfHasValidSchm,
                            severity: .error,
                            message: "`sinf` is missing the mandatory `schm` (SchemeTypeBox).",
                            context: context))
                    continue
                }
                _ = schm  // schemeType enum already constrains to the 4 valid schemes
                // C4: schi must be present and carry tenc.
                guard let schi = sinf.schemeInformation else {
                    issues.append(
                        CENCConformanceIssue(
                            ruleID: .C4_SchiHasTenc,
                            severity: .error,
                            message:
                                "`sinf` is missing `schi` (SchemeInformationBox) carrying `tenc`.",
                            context: context))
                    continue
                }
                guard let tenc = schi.trackEncryption else {
                    issues.append(
                        CENCConformanceIssue(
                            ruleID: .C4_SchiHasTenc,
                            severity: .error,
                            message: "`schi` is missing the mandatory `tenc` (TrackEncryptionBox).",
                            context: context))
                    continue
                }
                // C5: tenc.default_KID must be 16 bytes. The
                // KeyIdentifier type enforces this at construction;
                // this check covers values reconstructed from raw
                // box bodies that bypass the typed constructor.
                if tenc.defaultKID.rawBytes.count != 16 {
                    issues.append(
                        CENCConformanceIssue(
                            ruleID: .C5_TencDefaultKIDSize,
                            severity: .error,
                            message:
                                "`tenc.default_KID` must be exactly 16 bytes (found \(tenc.defaultKID.rawBytes.count)).",
                            context: context))
                }
            }
        }
        return issues
    }

    // MARK: - C6: pssh boxes well-formed

    private func checkRuleC6(rootBoxes: [any ISOBox]) -> [CENCConformanceIssue] {
        // pssh may live at top-level (recommended by §4.7) or inside
        // moov. Collect from both locations.
        var psshBoxes: [ProtectionSystemSpecificHeaderBox] = []
        psshBoxes.append(contentsOf: rootBoxes.compactMap { $0 as? ProtectionSystemSpecificHeaderBox })
        if let moov = rootBoxes.compactMap({ $0 as? MovieBox }).first {
            psshBoxes.append(
                contentsOf: moov.findChildren(ProtectionSystemSpecificHeaderBox.self))
        }
        var issues: [CENCConformanceIssue] = []
        // §4.7: version 1 pssh MUST carry a non-empty KID list;
        // version 0 pssh MAY omit it. Iterate only version-1 entries
        // via the `where` clause to keep the SwiftLint `for_where`
        // rule satisfied.
        for (index, pssh) in psshBoxes.enumerated() where pssh.version == 1 {
            let kids = pssh.keyIdentifiers ?? []
            if kids.isEmpty {
                issues.append(
                    CENCConformanceIssue(
                        ruleID: .C6_PSSHWellFormed,
                        severity: .error,
                        message:
                            "Version-1 `pssh` must carry a non-empty KID list (entry \(index), System ID \(pssh.systemID.uuidString)).",
                        context:
                            "psshIndex: \(index), systemID: \(pssh.systemID.uuidString)"
                    ))
            }
            // Every KID in the list must be 16 bytes.
            for kid in kids where kid.rawBytes.count != 16 {
                issues.append(
                    CENCConformanceIssue(
                        ruleID: .C6_PSSHWellFormed,
                        severity: .error,
                        message:
                            "`pssh` KID list entry must be 16 bytes (found \(kid.rawBytes.count)).",
                        context: "psshIndex: \(index)"))
            }
        }
        return issues
    }

    // MARK: - C7 + C8: senc / saiz / saio coherence

    private func checkRulesC7AndC8(
        moov: MovieBox, rootBoxes: [any ISOBox]
    ) -> [CENCConformanceIssue] {
        // Build a track-ID → tenc map first so we know the IV size
        // expectation per track.
        var tencByTrackID: [UInt32: TrackEncryptionBox] = [:]
        for track in moov.tracks {
            guard let trackID = track.trackHeader?.trackID else { continue }
            for entry in encryptedSampleEntries(in: track) {
                let sinf: ProtectionSchemeInfoBox?
                if let audio = entry as? EncryptedAudioSampleEntry {
                    sinf = audio.protectionSchemeInfo
                } else if let video = entry as? EncryptedVideoSampleEntry {
                    sinf = video.protectionSchemeInfo
                } else {
                    sinf = nil
                }
                if let tenc = sinf?.schemeInformation?.trackEncryption {
                    tencByTrackID[trackID] = tenc
                }
            }
        }
        // Walk movie fragments at top level.
        var issues: [CENCConformanceIssue] = []
        for box in rootBoxes {
            guard let moof = box as? MovieFragmentBox else { continue }
            for traf in moof.findChildren(TrackFragmentBox.self) {
                issues.append(
                    contentsOf: checkTrackFragmentCENC(
                        traf: traf, tencByTrackID: tencByTrackID))
            }
        }
        return issues
    }

    private func checkTrackFragmentCENC(
        traf: TrackFragmentBox, tencByTrackID: [UInt32: TrackEncryptionBox]
    ) -> [CENCConformanceIssue] {
        var issues: [CENCConformanceIssue] = []
        let trackID = traf.findChild(TrackFragmentHeaderBox.self)?.trackID ?? 0
        let context = "trackID: \(trackID)"
        guard let senc = traf.findChild(SampleEncryptionBox.self) else {
            return []  // no encryption in this fragment — nothing to check
        }
        let saizBoxes = traf.findChildren(SampleAuxiliaryInformationSizesBox.self)
        // C7: saiz sampleCount SHOULD match senc.samples.count when
        // both present. Report once per fragment via the `first` mis-
        // matching entry.
        if let mismatched = saizBoxes.first(
            where: { Int($0.sampleCount) != senc.samples.count }
        ) {
            issues.append(
                CENCConformanceIssue(
                    ruleID: .C7_SencSaizSaioCoherent,
                    severity: .error,
                    message:
                        "`saiz.sample_count` (\(mismatched.sampleCount)) does not match `senc.samples.count` (\(senc.samples.count)).",
                    context: context))
        }
        // C8: per-sample IV lengths must match tenc.defaultPerSampleIVSize
        // (when defaultPerSampleIVSize is non-zero — zero IV size uses
        // the defaultConstantIV path instead).
        if let tenc = tencByTrackID[trackID] {
            let expectedIVSize = Int(tenc.defaultPerSampleIVSize.rawValue)
            if expectedIVSize > 0 {
                for (index, sample) in senc.samples.enumerated()
                where sample.initializationVector.count != expectedIVSize {
                    issues.append(
                        CENCConformanceIssue(
                            ruleID: .C8_PerSampleIVLengthConsistent,
                            severity: .error,
                            message:
                                "`senc` sample[\(index)] IV length \(sample.initializationVector.count) does not match `tenc.default_Per_Sample_IV_Size` \(expectedIVSize).",
                            context: context))
                    break
                }
            }
        }
        return issues
    }
}
