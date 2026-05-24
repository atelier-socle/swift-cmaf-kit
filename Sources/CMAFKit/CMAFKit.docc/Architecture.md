# Architecture

The eleven-module layered design of CMAFKit.

## Overview

CMAFKit follows a strict layered architecture. The dependency rules
are documented inline in each module. Lower layers cannot reference
upper layers.

- Layer 0 — BinaryIO
- Layer 1 — Media
- Layer 2 — ISOBMFF
- Layer 3 — Color, CodecSampleEntries, CodecBitstream
- Layer 4 — Encryption, Fragmentation
- Layer 5 — CMAFProfiles, Reader, Validator

## 0.1.1 additions

The 0.1.1 patch adds the following submodules (all purely additive,
respecting the layered constraints):

- `Sources/CMAFKit/Media/Languages/` — BCP 47 typed language tags.
  Sits at Layer 1 (Media). See <doc:LanguageTagsReference>.
- `Sources/CMAFKit/Media/Accessibility/` — cross-format
  accessibility primitives. Sits at Layer 1 (Media). See
  <doc:AccessibilityReference>.
- Typed members under `Sources/CMAFKit/ISOBMFF/SampleEntries/Audio/`
  for ALAC / PCM and the `EC3JOCExtension` typed enum +
  `EC3SpecificBox+JOC` extension. See <doc:AudioCodecsReference>.
- Members under `Sources/CMAFKit/Bitstreams/HEVC/` +
  `Sources/CMAFKit/ISOBMFF/SampleEntries/Video/` for multi-view
  HEVC. See <doc:MVHEVCGuide>.
- `Sources/CMAFKit/Fragmentation/Common/RFC6381CodecStringBuilder*.swift`
  for RFC 6381 codec strings. See <doc:CodecStringReference>.
- `Sources/CMAFKit/Validator/ISOConformanceValidator*.swift` +
  `CENCConformanceValidator*.swift` for the box-array-layer
  validators. See <doc:ValidatorsHierarchy>.

Every 0.1.1 addition preserves the v0.1.0 public surface
byte-identically — see the project CHANGELOG for the complete
audit trail.
