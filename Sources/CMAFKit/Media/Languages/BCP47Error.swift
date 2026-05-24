// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BCP47Error
//
// Reference: IETF RFC 5646 §2.1 (ABNF syntax) — the parser throws on
// every spec violation; the error includes the full input string + a
// specific reason so callers see exactly what failed.

import Foundation

/// Typed errors thrown by ``BCP47LanguageTag`` parsing and bridging.
public enum BCP47Error: Error, Equatable {

    /// Tag does not conform to RFC 5646 §2.1 ABNF syntax.
    ///
    /// `input` is the full failing string; `reason` is a short
    /// human-readable explanation. Use both for diagnostic logging.
    case malformedTag(input: String, reason: String)

    /// Primary subtag is well-formed but not recognised by the embedded
    /// IANA Language Subtag Registry snapshot (strict-mode parsing only).
    case unknownPrimarySubtag(_ value: String)

    /// Extended-language subtag is well-formed but not recognised by the
    /// embedded IANA registry snapshot.
    case unknownExtendedLanguage(_ value: String)

    /// Script subtag is not a valid 4-character title-case code OR not
    /// in the IANA registry snapshot.
    case unknownScript(_ value: String)

    /// Region subtag is neither valid ISO 3166-1 alpha-2 nor valid
    /// UN M.49 numeric.
    case unknownRegion(_ value: String)

    /// ISO 639-2/B code without a known /T mapping. The bridge cannot
    /// disambiguate; the caller must fix the upstream encoder.
    /// (Should be rare — the ISO 639-2 standard defines a /T for every /B.)
    case ambiguousISO6392B(_ value: String, candidates: [String])

    /// ISO 639-2 code that is neither well-formed (3 lowercase ASCII
    /// letters) nor in any /B-to-/T mapping nor in the /T registry.
    case unknownISO6392Code(_ value: String)
}
