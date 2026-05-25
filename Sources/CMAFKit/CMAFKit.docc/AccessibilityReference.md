# Accessibility primitives

Cross-format-neutral typed primitives for accessibility signalling in
CMAF deliveries. Consumed by HLSKit (`EXT-X-MEDIA` attributes) and
DASHKit (`<Role>` / `<Accessibility>` descriptors). EU Accessibility
Act (Directive 2019/882) compliant since 28 June 2025.

## Overview

Accessibility is mandated, not optional. The EU Accessibility Act
applies to consumer streaming services in scope as of 28 June 2025;
ETSI EN 301 549 §7.1 lists the technical requirements; FCC §79.4
mandates closed captioning for US online video; Apple HLS Authoring
§4.6 prescribes typed CHARACTERISTICS URIs. CMAFKit ships the
cross-format-neutral primitives that both HLSKit and DASHKit
consume, plus the EU compliance helper.

## The five typed primitives

- ``MediaSelectionRole`` — 16-case enum capturing a track's *purpose*
  within a presentation (`.main`, `.alternate`, `.commentary`,
  `.dub`, `.description`, `.forcedSubtitle`, `.captions`,
  `.subtitle`, `.sign`, `.emergency`, `.karaoke`,
  `.enhancedAudioIntelligibility`, `.transcript`, `.easyReader`,
  `.supplementary`, `.custom`).
- ``AccessibilityFeature`` — 16-case enum capturing *what
  accessibility need* the content addresses (closed/open captions,
  audio description, sign language interpretation, enhanced audio
  intelligibility, reduced flashing, high contrast, etc.).
- ``AccessibilityCharacteristic`` — 7 typed Apple HLS
  CHARACTERISTICS URIs (`public.accessibility.describes-video`,
  `public.accessibility.transcribes-spoken-dialog`,
  `public.accessibility.describes-music-and-sound`,
  `public.accessibility.enhances-speech-intelligibility`,
  `public.easy-to-read`,
  `public.accessibility.supplementary-content-for-user-consumption`,
  `public.auxiliary-content`) plus `.custom(uri:)` escape hatch.
- ``AudioPurpose`` — DVB-DASH TVA AudioPurposeCS:2007 codes 0..7
  (`.main`, `.audioDescription`, `.hearingImpaired`, `.translation`,
  `.supplementary`, `.emergency`, `.voiceover`, `.spokenSubtitle`).
- ``AccessibilityMetadata`` — the aggregate attached to a
  ``CMAFTrackConfiguration``.

## Cross-format mapping

Each role / feature carries its HLS CHARACTERISTICS URI(s) and DASH
scheme value via computed properties:

| Typed case | Apple HLS CHARACTERISTICS | DASH Role scheme value |
|---|---|---|
| ``MediaSelectionRole/description`` | `public.accessibility.describes-video` | `description` |
| ``MediaSelectionRole/captions`` | `public.accessibility.transcribes-spoken-dialog` + `public.accessibility.describes-music-and-sound` | `caption` |
| ``MediaSelectionRole/enhancedAudioIntelligibility`` | `public.accessibility.enhances-speech-intelligibility` | `enhanced-audio-intelligibility` |
| ``MediaSelectionRole/easyReader`` | `public.easy-to-read` | `easyreader` |
| ``MediaSelectionRole/forcedSubtitle`` | (HLS `FORCED=YES`) | `forced-subtitle` |
| ``MediaSelectionRole/sign`` | (HLS via CHARACTERISTICS + sign-language `LANGUAGE`) | `sign` |
| ``MediaSelectionRole/main`` | — | `main` |
| ``MediaSelectionRole/subtitle`` | — | `subtitle` |

``MediaSelectionRole/dashRoleSchemeIdUri`` and
``AudioPurpose/dashAccessibilitySchemeIdUri`` expose the canonical
`schemeIdUri` strings; ``MediaSelectionRole/fromDASHRoleValue(_:)``
and ``AudioPurpose/fromDASHSchemeValue(_:)`` reverse-parse DASH
input. ``MediaSelectionRole/fromDASHRoleValue(_:)`` accepts the
legacy `audio-description` synonym for `description` per DASH-IF
§6.6.

## The aggregate

``AccessibilityMetadata`` carries every signal a manifest emitter
needs, on a single value attached to a track:

```swift
let metadata = AccessibilityMetadata(
    role: .description,
    features: [.audioDescription],
    characteristics: [.describesVideo],
    audioPurpose: .audioDescription,
    isAutoSelect: true,
    associatedLanguage: try BCP47LanguageTag("en-US"))
```

Derived getters:

- ``AccessibilityMetadata/allHLSCharacteristicURIs`` — union of
  explicit characteristics and implicit URIs from role + features.
- ``AccessibilityMetadata/canonicalDASHRoleValue`` — the typed
  scheme value, or `customRoleValue` for `.custom`, or `nil` for
  `.transcript` (signalled via the Accessibility descriptor).
- ``AccessibilityMetadata/carriesEUAccessibilityActFeature`` — true
  when at least one EU Accessibility Act §I-relevant signal is
  present (audio description, closed captions, sign language, etc.).

The aggregate is wired onto the existing track types via
``CMAFTrackConfiguration/accessibility`` and
``CMAFTrackConfiguration/SubtitleFields/accessibility`` (both
defaulting to `nil` — back-compat with v0.1.0).

## Real-world fixtures

The test suite exercises canonical broadcaster fixtures end-to-end.
Each `AccessibilityMetadata` value below corresponds to a typed
`@Test` in the audited surface — the same values your manifest
emitter will produce for the equivalent input track.

### BBC iPlayer closed captions (en-GB)

Closed captions with both speech transcription and ambient-sound
description per BBC Subtitle Guidelines:

```swift
import CMAFKit

let bbcCaptions = AccessibilityMetadata(
    role: .captions,
    features: [.closedCaptions],
    characteristics: [.transcribesSpokenDialog, .describesMusicAndSound],
    isAutoSelect: true,
    associatedLanguage: try BCP47LanguageTag("en-GB")
)
// bbcCaptions.canonicalDASHRoleValue == "caption"
// bbcCaptions.carriesEUAccessibilityActFeature == true
```

### ARD / ZDF German Sign Language (gsg)

German Sign Language interpretation track — note the ISO 639-3
`gsg` (Deutsche Gebärdensprache) carried via the typed
``AccessibilityMetadata/signLanguage`` field:

```swift
import CMAFKit

let ardSign = AccessibilityMetadata(
    role: .sign,
    features: [.signLanguageInterpretation],
    isAutoSelect: false,
    signLanguage: try BCP47LanguageTag("gsg")
)
// ardSign.canonicalDASHRoleValue == "sign"
// ardSign.signLanguage?.primaryLanguage == .iso639_3("gsg")
// ardSign.carriesEUAccessibilityActFeature == true
```

### France-TV French Sign Language (fsl)

LSF (Langue des Signes Française) carried with the same shape — the
sign-language tag distinguishes the regional variant for downstream
player selection:

```swift
import CMAFKit

let franceTVLSF = AccessibilityMetadata(
    role: .sign,
    features: [.signLanguageInterpretation],
    signLanguage: try BCP47LanguageTag("fsl")
)
// franceTVLSF.signLanguage?.primaryLanguage == .iso639_3("fsl")
// franceTVLSF.carriesEUAccessibilityActFeature == true
```

### Disney+ forced subtitles

Forced subtitles cover foreign-language sections of an otherwise
single-language film. They are *not* an accessibility feature — the
helper correctly returns `false`:

```swift
import CMAFKit

let disneyForced = AccessibilityMetadata(
    role: .forcedSubtitle,
    features: [.forcedSubtitles],
    isForced: true,
    associatedLanguage: try BCP47LanguageTag("en")
)
// disneyForced.canonicalDASHRoleValue == "forced-subtitle"
// disneyForced.isForced == true
// disneyForced.carriesEUAccessibilityActFeature == false
```

## DASH role mapping

``AccessibilityMetadata/canonicalDASHRoleValue`` emits the typed
``MediaSelectionRole``'s DASH `Role` scheme value — useful when an
HLS-shaped pipeline branches into a DASH manifest emitter:

```swift
import CMAFKit

let metadata = AccessibilityMetadata(role: .captions)
// metadata.canonicalDASHRoleValue == "caption"
```

The 16-case ``MediaSelectionRole`` round-trips through
``MediaSelectionRole/fromDASHRoleValue(_:)``; `.transcript` returns
`nil` because it ships via the DASH `Accessibility` descriptor, not
`Role`.

## DVB-DASH AudioPurpose emission

``AudioPurpose`` carries the DVB-DASH TVA AudioPurposeCS:2007 codes
0..7. ``AudioPurpose/dashSchemeValue`` produces the canonical
single-digit string for the `<Accessibility>` descriptor:

```swift
import CMAFKit

let metadata = AccessibilityMetadata(
    role: .description,
    features: [.audioDescription],
    audioPurpose: .audioDescription,
    isAutoSelect: true,
    associatedLanguage: try BCP47LanguageTag("en-US")
)
// metadata.audioPurpose?.dashSchemeValue == "1"
```

## EU Accessibility Act compliance

``AccessibilityMetadata/carriesEUAccessibilityActFeature`` returns
`true` when the metadata signals at least one of: audio description
(`features` or `role`), extended audio description, closed captions,
sign language interpretation, captions role, sign role, description
role. This is the single helper a manifest validator queries to
detect EU §I compliance gaps:

```swift
import CMAFKit

let audioDescription = AccessibilityMetadata(features: [.audioDescription])
// audioDescription.carriesEUAccessibilityActFeature == true

let plainStereo = AccessibilityMetadata.empty
// plainStereo.carriesEUAccessibilityActFeature == false
```

## Standards covered

- **Apple HLS Authoring Specification §4.6.1-§4.6.5, §4.7** —
  `EXT-X-MEDIA` attributes (CHARACTERISTICS, AUTOSELECT, FORCED,
  DEFAULT, INSTREAM-ID, ASSOC-LANGUAGE)
- **Apple Media Accessibility Documentation** —
  `public.accessibility.*` URIs
- **ISO/IEC 23009-1 §5.8.4.2** — DASH `Role` descriptor
- **ISO/IEC 23009-1 §5.8.4.3** — DASH `Accessibility` descriptor
- **ISO/IEC 23009-1 §5.8.5.5** — `urn:mpeg:dash:role:2011`
- **DASH-IF Implementation Guidelines v5.0+ §6.6** — accessibility
- **DVB-DASH (ETSI TS 103 285) §5.2** — TVA AudioPurpose
- **TVA Metadata CS `urn:tva:metadata:cs:AudioPurposeCS:2007`** —
  codes 0..7
- **W3C Media Accessibility User Requirements**
- **W3C WCAG 2.2 §2.3.1** — Three Flashes or Below Threshold
- **ETSI EN 301 549 §7.1** — EU accessibility ICT
- **EU Directive 2019/882** — European Accessibility Act
- **FCC §79.4** — US online video closed captioning
- **CTA-2065** — Closed Captioning Style guide
- **EBU Tech 3370** — Audio Description bindings
- **IETF RFC 8216bis** — HLS specification

## See also

- <doc:LanguageTagsReference>
- <doc:AccessibilityAndStandards>
- ``MediaSelectionRole``
- ``AccessibilityFeature``
- ``AccessibilityCharacteristic``
- ``AudioPurpose``
- ``AccessibilityMetadata``
- ``AccessibilityError``
