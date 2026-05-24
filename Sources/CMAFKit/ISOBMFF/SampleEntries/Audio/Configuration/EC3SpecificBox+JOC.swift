// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EC3SpecificBox — JOC accessors
//
// Derives the typed ``EC3JOCExtension`` from the existing
// ``EC3SpecificBox/ec3ExtensionTypeA`` byte (Annex F.6 trailer). No
// mutation of the underlying box — Option A integration strategy.
//
// References:
// - ETSI TS 102 366 V1.4.1 Annex F.6 — dec3 trailer byte layout
// - ETSI TS 102 366 V1.4.1 Annex H — JOC syntax + complexity

import Foundation

extension EC3SpecificBox {

    /// Typed JOC extension derived from the `ec3_extension_type_a`
    /// byte per ETSI TS 102 366 Annex F.6 + Annex H.
    ///
    /// Mapping:
    /// - ``ec3ExtensionTypeA`` `nil` → ``EC3JOCExtension/none``
    ///   (no extension flag set in the trailer).
    /// - `ec3_extension_type_a == 0` → ``EC3JOCExtension/none``
    ///   (flag set but no JOC complexity declared).
    /// - `ec3_extension_type_a != 0` →
    ///   ``EC3JOCExtension/bedAndObjects(complexityIndex:)`` with
    ///   `complexityIndex = ec3_extension_type_a & 0x1F` (Annex H.3
    ///   reserves five bits for the complexity index; upper bits are
    ///   reserved).
    ///
    /// The ``EC3JOCExtension/objectBased`` and
    /// ``EC3JOCExtension/channelBased`` variants are not signalled by
    /// the dec3 trailer alone — they require parsing the actual E-AC-3
    /// dependent substreams. Callers that have parsed the substreams
    /// may construct those cases directly.
    public var jocExtension: EC3JOCExtension {
        guard let typeA = ec3ExtensionTypeA else { return .none }
        let complexity = typeA & 0x1F
        if complexity == 0 { return .none }
        return .bedAndObjects(complexityIndex: complexity)
    }

    /// Convenience flag — `true` when this E-AC-3 stream carries Dolby
    /// Atmos via a JOC extension.
    ///
    /// Useful for HLSKit emitting `CHANNELS="16/JOC"` (Apple HLS
    /// Authoring §2.2.4) or DASHKit emitting Dolby Atmos
    /// `<SupplementalProperty>` (DASH-IF §6.3.4).
    public var carriesDolbyAtmos: Bool { jocExtension.isPresent }
}
