# BCP 47 language tags

Typed BCP 47 / RFC 5646 language tags with ISO 639-2/T bridging for
the ISOBMFF `mdhd` box and RFC 4647 matching for HLS / DASH player
language selection.

## Overview

Language identification is everywhere in streaming media: the
ISOBMFF `mdhd` box carries a 3-character ISO 639-2 code, HLS
`EXT-X-MEDIA LANGUAGE` and DASH `@lang` expect BCP 47 tags, regional
content variants use script + region subtags. CMAFKit ships
``BCP47LanguageTag`` — a fully typed RFC 5646 §2.1 ABNF parser plus
the bridge between the ISO 639-2 carriage form and the BCP 47 wire
form, with an embedded snapshot of the IANA Language Subtag Registry
(2026-05).

## The typed primitive

``BCP47LanguageTag`` aggregates the RFC 5646 subtag hierarchy:

- ``PrimarySubtag`` — `.iso639_1`, `.iso639_3`, `.grandfathered`,
  `.privateUse`
- `extendedLanguage: String?` per §2.2.2 (e.g., `zh-yue` Cantonese)
- ``ISO15924Script`` — title-case 4-character script code
- ``Region`` — `.iso3166_1(alpha2)` or `.unM49(numeric)`
- `variants: [String]` per §2.2.5 (e.g., `de-CH-1996`)
- `extensions: [BCP47Extension]` per §2.2.6 (e.g., `u-co-phonebk`)
- `privateUse: [String]` per §2.2.7

The string initialiser walks the RFC 5646 §2.1 ABNF and the
canonical-form serialiser applies §4.5 case-normalisation (primary
lowercase, script title-case, region uppercase).

```swift
let tag = try BCP47LanguageTag("zh-Hant-TW")
// tag.primaryLanguage == .iso639_1("zh")
// tag.script?.code == "Hant"
// tag.region == .iso3166_1("TW")
// tag.canonicalForm == "zh-Hant-TW"
```

## ISO 639-2/T bridge

ISO BMFF `mdhd` carries language as 3 × 5-bit packed ISO 639-2 per
ISO/IEC 14496-12 §8.4.2.3. Real-world encoders are inconsistent
between the Bibliographic (/B) and Terminologic (/T) variants;
CMAFKit normalises to /T and prefers the shortest valid form (ISO
639-1 alpha-2 when available) per RFC 5646 §4.5:

```swift
let tag = try BCP47LanguageTag.fromISO6392T("fre")   // /B input
// tag.primaryLanguage == .iso639_1("fr")            // bridged + shortened

let back = tag.toISO6392T()                          // "fra" — /T form
```

The 20-entry /B↔/T mapping (`fre↔fra`, `ger↔deu`, `dut↔nld`,
`chi↔zho`, `cze↔ces`, `gre↔ell`, …) is embedded from ISO 639-2.

The ISOBMFF integration is additive on the existing box:

```swift
let mdhd: MediaHeaderBox = ...
let bcp47 = try mdhd.languageAsBCP47()  // BCP47LanguageTag
```

``CMAFTrackConfiguration/bcp47Language`` and
``CMAFTrackConfiguration/SubtitleFields/bcp47Language`` give
silent-degrade computed accessors for HLS/DASH manifest emission
contexts.

## RFC 4647 matching

Player language preferences are matched against rendition tags via
three schemes per IETF RFC 4647 §3:

```swift
let tag = try BCP47LanguageTag("en-US")
tag.matches("en", scheme: .basic)         // prefix match — true
tag.matches("zh-Hant", scheme: .extended) // wildcard skip — n/a
tag.matches("en-US-x-twain", scheme: .lookup)  // best-effort drop
```

- `.basic` per §3.3.1 — language range is a subtag-aligned prefix.
- `.extended` per §3.3.2 — range subtags appear in order with
  intervening tag subtags allowed; `*` matches any single subtag.
- `.lookup` per §3.4 — progressively drop trailing subtags from the
  range until a basic match succeeds; never end on a singleton.

The whole-range wildcard `*` per §2.2 matches anything in every
scheme.

## IANA Language Subtag Registry snapshot

The embedded ``IANALanguageSubtagRegistry`` snapshot is dated
2026-05 and exposes two-tier validation per subtag category: a
fast `isKnownXXX(_:)` lookup against the snapshot set plus a
syntactic `isWellFormedXXX(_:)` ABNF check. The default parser uses
the syntax check (permissive mode); strict-mode registry validation
is reserved for a follow-up.

## Standards covered

- **IETF RFC 5646 / BCP 47** — Tags for Identifying Languages
- **IETF RFC 4647** — Matching of Language Tags
- **ISO 639-1 / ISO 639-2 / ISO 639-3** — Language codes (B/T bridge)
- **ISO 15924** — Script codes
- **ISO 3166-1 alpha-2** — Country codes
- **UN M.49** — Supra-national numeric region codes
- **IANA Language Subtag Registry** — authoritative subtag list
- **ISO/IEC 14496-12 §8.4.2.3** — `mdhd` language carriage

## See also

- <doc:AccessibilityReference>
- ``BCP47LanguageTag``
- ``PrimarySubtag``
- ``ISO15924Script``
- ``Region``
- ``BCP47Extension``
- ``IANALanguageSubtagRegistry``
- ``BCP47Error``
