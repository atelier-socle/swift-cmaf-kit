# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] — 2026-05-25

Refinement patch. Purely additive — every existing v0.1.1 call site
compiles unchanged. Public API surface is identical to v0.1.1; the
patch refines internal architecture, removes a dead dependency, and
enriches the DocC catalog with samples extracted from the existing
test suite (zero invention).

### Changed

- CLI architecture refactored to the idiomatic library-target + thin-
  executable pattern matching the peer ecosystem (`swift-hls-kit`,
  `swift-srt-kit`, `swift-rtmp-kit`, `swift-icecast-kit`). New
  `CMAFKitCommands` library target carries the command
  implementations; `CMAFKitCLI` remains as a thin `@main` wrapper.
  Unblocks `xcodebuild test -scheme swift-cmaf-kit-Package
  -destination 'platform=macOS'` on Apple platforms.

### Removed

- `swift-crypto` declared-but-unwired dependency (no `import Crypto`
  call sites existed in 0.1.0 / 0.1.1; verified by Phase A audit on
  2026-05-25).
- Stale "Session 12" planning comment in `Package.swift`
  `testTarget` resources.

### Documentation

- DocC catalog enriched with 94 new test-traceable `swift` code
  samples across 22 articles (CMAFKit + CMAFKitDRM). The catalog
  went from 14 swift code blocks to 113 ecosystem-wide. Every
  sample traces to an existing `@Test` (zero invention).
- `ProtocolBufferReader` / `ProtocolBufferWriter` public visibility
  legitimised with substantial doc comments (type-level wire-format
  enumeration, public-visibility justification, swift-protobuf
  fallback note, per-method `- Parameter` / `- Returns` / `- Throws`
  markup) + DocC reference in the `CMAFKitDRM` landing under
  "Internals exposed for extensibility".
- `CMAFKitCLI.docc/` migrated to `CMAFKitCommands.docc/` (the
  testable library owns the catalog, matching the peer-lib pattern).

### Fixed

- `MVHEVCGuide.md` — corrected two API bugs in the existing sample:
  `heroLayerID: 0` → `heroEye: .leftEye` (the `MVHEVCPackager.init`
  parameter is `heroEye:`, not `heroLayerID:`; `heroLayerID` is
  a derived `public nonisolated let` property); `try await
  packager.stop()` → `await packager.stop()` (the `stop()` method
  is `async` but not `throws`). Surfaced during S2 enrichment.
- `CodecStringReference.md` — corrected the prose codec-string
  examples to match actual output: `"avc1.42E01E"` →
  `"avc1.42e01e"` (the `RFC6381CodecStringBuilder` produces
  lowercase hexadecimal per RFC 6381), and the generic
  `"hvc1.2.4.L120.B0"` replaced with the test-anchored
  `"hvc1.2.4.L123.90"` (Apple HLS Authoring §2.2.1 example).
  Surfaced during S2 enrichment.

### Validation

- `xcodebuild test -scheme swift-cmaf-kit-Package -destination
  'platform=macOS'` works post-refactor (the headline behavioural
  validation of 0.1.2). The library-only scheme (`CMAFKit`) lacks a
  test action by SPM convention; the package-wide scheme is the
  correct invocation, matching the `swift-hls-kit` peer pattern.
- All existing tests preserved: 3 575 on macOS / 3 574 on Linux
  Docker.
- Coverage ≥ 92 % global maintained.
- Zero forbidden patterns introduced (9/9 clean).
- Zero public symbol removed since v0.1.1.

### Notes

- 0.1.2 is purely refinement — every existing v0.1.1 call site
  compiles unchanged.
- Public API surface is identical to v0.1.1 (refinement, not
  expansion).

## [0.1.1] — 2026-05-25

Patch release closing the no-compromise completion of the 0.1.0
surface. Required for HLSKit 0.7.0 migration and future DASHKit
0.1.0 enablement. Zero breaking change on the v0.1.0 public
surface. Zero public symbol removed since v0.1.0. Zero forbidden
patterns introduced.

### Added

#### Multi-view HEVC and Apple Vision Pro spatial video

- `HEVCParameterSets` aggregate — VPS/SPS/PPS triplet extracted
  from a NAL stream, per ITU-T H.265 §7.3.2 + ISO/IEC 14496-15
  §8.3.3.1.
- `HEVCVPSExtension`, `HEVCMultiLayerSPS`,
  `HEVCMultiLayerScalingListData` — multi-layer HEVC bitstream
  foundation per ITU-T H.265 §F + §I.
- `ViewExtendedUsageBox` (`vexu`), `StereoInformationBox` (`stri`),
  `HeroEyeInformationBox` (`hero`) — Apple HLS Spatial Video
  extension boxes.
- `MultiLayerHEVCConfiguration`, `MVHEVCSampleEntry` (`hvc2`),
  `MVHEVCPackager` actor — MV-HEVC composition for HLS Spatial
  Video delivery, per ISO/IEC 14496-15 §I.
- `EncodedCodec.mvHEVC` / `.mvHEVC10`, `VideoCodec.hvc2`,
  `VideoCodecConfiguration.mvHEVC(...)` — typed dispatch surface
  for the multi-view variant.
- `CMAFSampleTiming` — typed sample-timing wrapper.

#### Codec strings — RFC 6381

- `RFC6381CodecDescriptor` 23-case discriminated union spanning the
  full codec matrix CMAFKit emits.
- `RFC6381CodecStringBuilder` with bidirectional `codecString(for:)`
  and `parse(_:)` entry points, per IETF RFC 6381, ISO/IEC 14496-15
  §A.5, Apple HLS Authoring §2.2, DASH-IF Implementation Guidelines
  §4.

#### Language tags — BCP 47 / RFC 5646

- `BCP47LanguageTag` with full RFC 5646 §2.1 ABNF parser + §4.5
  canonicalisation.
- Companion types — `BCP47Error`, `PrimarySubtag`, `ISO15924Script`,
  `Region`, `BCP47Extension`.
- `IANALanguageSubtagRegistry` — embedded 2026-05 snapshot (ISO
  639-1, ISO 639-3, /B↔/T mapping, ISO 15924, ISO 3166-1, UN M.49,
  grandfathered, extended-language subtags).
- ISO 639-2/T bridge — `BCP47LanguageTag.fromISO6392T(_:)` +
  `toISO6392T()` with /B disambiguation and shortest-form preference.
- RFC 4647 matching — `.basic`, `.extended`, `.lookup` schemes with
  wildcard support.
- `MediaHeaderBox.languageAsBCP47()`,
  `CMAFTrackConfiguration.bcp47Language`,
  `SubtitleFields.bcp47Language` — additive typed accessors.

#### Accessibility primitives

- `MediaSelectionRole` (16-case enum capturing track purpose).
- `AccessibilityFeature` (16-case enum capturing accessibility need).
- `AccessibilityCharacteristic` (7 typed Apple URIs + `.custom`).
- `AudioPurpose` (DVB TVA AudioPurposeCS:2007 codes 0..7).
- `AccessibilityMetadata` aggregate with `allHLSCharacteristicURIs`,
  `canonicalDASHRoleValue`, and `carriesEUAccessibilityActFeature`
  derived getters.
- `AccessibilityError` typed errors.
- `CMAFTrackConfiguration.accessibility` +
  `SubtitleFields.accessibility` — additive storage (default `nil`
  preserves v0.1.0 back-compat).
- Standards: Apple HLS Authoring §4.6, ISO/IEC 23009-1
  §5.8.4-§5.8.5.5, DASH-IF IOP v5.0+ §6.6, DVB-DASH (ETSI TS 103
  285) §5.2, ETSI EN 301 549 §7.1, EU Directive 2019/882, W3C
  Media Accessibility User Requirements, FCC §79.4, CTA-2065, EBU
  Tech 3370.

#### Audio codecs

- `EC3JOCExtension` (5-case typed enum) +
  `EC3SpecificBox.jocExtension` + `EC3SpecificBox.carriesDolbyAtmos`
  — first-class Dolby Atmos detection in E-AC-3 streams per ETSI TS
  102 366 Annex H.
- `ALACSampleEntry` (`alac`) + `ALACSpecificBox` — Apple Lossless
  audio per Apple ALAC public specification.
- `PCMConfigurationBox` (`pcmC`) + `PCMSampleCodecKind` per ISO/IEC
  23003-5 §5.
- `IntegerPCMSampleEntry` (`ipcm`), `FloatingPointPCMSampleEntry`
  (`fpcm`), `LegacyPCMSampleEntry` (`lpcm`) — CMAF uncompressed
  audio sample entries per ISO/IEC 23003-5 §4 + ISO/IEC 14496-12
  §12.2.3.
- `AudioCodec.alac`, `.ipcm`, `.fpcm`, `.lpcm` cases.
- `AudioCodecConfiguration.alac`, `.integerPCM`, `.floatingPointPCM`,
  `.legacyPCM` cases.
- CMAF brands `cup1` / `cup2` per CMAF §7.5.2 (compatibility brands
  for the uncompressed-audio profile).

#### Validators

- `ISOConformanceValidator` — generic ISO BMFF structural validator
  with 8 rules (I1-I8) per ISO/IEC 14496-12 §4-§8.
- `CENCConformanceValidator` — generic Common Encryption validator
  with 8 rules (C1-C8) per ISO/IEC 23001-7 §4.5-§4.9.
- `ISOConformanceLevel` / `ISOConformanceRule` /
  `ISOConformanceIssue` / `ISOConformanceReport`.
- `CENCConformanceLevel` / `CENCConformanceRule` /
  `CENCConformanceIssue` / `CENCConformanceReport`.
- `CMAFConformanceValidator.isoValidator` +
  `CMAFConformanceValidator.cencValidator` — additive composition
  accessors (the existing CMAF validator's parsed-segment logic is
  unchanged).

### Documentation

- Six new DocC articles: `MVHEVCGuide`, `CodecStringReference`,
  `LanguageTagsReference`, `AccessibilityReference`,
  `AudioCodecsReference`, `ValidatorsHierarchy`.
- Landing `CMAFKit.md` Topics extended with 0.1.1 surface sections.
- `Architecture.md` updated with new `Media/Languages/` and
  `Media/Accessibility/` submodules + composition references.
- `StandardsReference.md` extended with 0.1.1 standards (~28 new
  spec covers added).
- `README.md` — "What's new in 0.1.1" section.

### Changed

- (purely additive — no breaking changes on the v0.1.0 surface)

### Deprecated

- (none)

### Removed

- Three placeholder modules
  `Sources/CMAFKit/CodecBitstream/`, `Sources/CMAFKit/CodecSampleEntries/`,
  `Sources/CMAFKit/CMAFProfiles/` (inert `_*Placeholder.swift`
  files, zero public surface — content was relocated during 0.1.0
  implementation to flatter locations).

### Fixed

- (no behavioural fixes — patch is pure addition; existing v0.1.0
  behaviour preserved byte-identically)

### Security

- (none — no security fixes)

### Notes

- ~28 new standards covered (cumulative total ~73, vs 45 in 0.1.0).
- Test count: +679 (2 896 in 0.1.0 → 3 575 in 0.1.1).
- Coverage ≥ 92 % global maintained throughout 0.1.1 implementation.
- Zero forbidden patterns introduced.
- All Apple targets build clean (macOS native, Mac Catalyst, iOS,
  iPadOS, tvOS, watchOS, visionOS); Linux builds clean with
  `canImport(AVFoundation)`-guarded fixtures only.

## [0.1.0] — 2026-05-23

Initial public release of the pure-Swift CMAF / ISO BMFF / Common Encryption foundation, the opt-in CMAFKitDRM extension covering nine publicly-registered DRM systems, and the `cmafkit-cli` companion executable.

### Added

#### CMAFKit

- Pure-Swift ISO BMFF (ISO/IEC 14496-12) reader and writer with typed box hierarchy covering 100+ standard boxes.
- All seven CMAF profiles (`cmfc`, `cmf2`, `cmff`, `cmfl`, `cmfs`, `cmfd`, `cmfh`) per ISO/IEC 23000-19.
- Ten video codec sample entries: AVC (`avc1`/`avc3`), HEVC (`hvc1`/`hev1`), Dolby Vision (`dvh1`/`dvhe`) profiles 5/7/8/10, AV1 (`av01`), VP8 (`vp08`), VP9 (`vp09`), MPEG-4 Visual (`mp4v`).
- Eight audio codec sample entries: AAC (`mp4a`), AC-3 (`ac-3`), E-AC-3 (`ec-3`), AC-4 (`ac-4`), Opus, FLAC, MPEG-H 3D Audio (`mhm1`/`mhm2`).
- Three subtitle codecs: WebVTT (`wvtt`), IMSC1 text + image (`stpp`).
- Four metadata codecs: ID3 (`id3 `), KLV (`mett`), URI (`urim`), text metadata.
- Closed caption support: CEA-608 + CEA-708 in-band SEI extraction (ATSC A/72 + SCTE-128 cross-NAL DTVCC reassembly) + native `c608` / `c708` sample entries per ISO/IEC 14496-30 §11.
- All four Common Encryption schemes per ISO/IEC 23001-7: `cenc`, `cbc1`, `cens`, `cbcs`.
- Three typed conformance validators: CMAF (ISO/IEC 23000-19), DASH ISO BMFF profile + DASH-IF IOP (ISO/IEC 23009-1 §6.3), Low-Latency HLS (RFC 8216bis-15 §B).
- High-level reader (`CMAFInitSegmentReader`, `CMAFMediaSegmentReader` actor) and writer (`CMAFInitSegmentWriter`, `CMAFMediaSegmentWriter` actor).
- ICC colour profile reading and writing per ICC.1:2010 + ICC.1:2022, with spec-strict `mluc` element-relative offset encoding (Adobe / ColorSync / Argyll CMS cross-encoder interop verified).
- HDR support: HDR10 (SMPTE ST 2086 mastering display + CTA-861.3 content light level), HDR10+, HLG, Dolby Vision Profile 5/7/8/10.

#### CMAFKitDRM (opt-in second library product)

- `KnownDRMSystemID` enum with nine named cases plus `.other(UUID)` for forward compatibility, each citing its DASH-IF / W3C EME registry source.
- Typed parsers per the public spec ecosystem:
  - **Widevine** — full Protocol Buffer typing of `WidevineCencHeader` (10 fields) via a zero-dependency wire-format reader/writer.
  - **PlayReady** — PRO outer envelope plus WRMHEADER XML across versions 4.0, 4.1, 4.2, 4.3, with UTF-16 LE BOM round-trip.
  - **FairPlay Streaming** — Apple Modular DRM binary format.
  - **W3C ClearKey** — JSON per W3C EME §9 with custom base64url decoder per RFC 4648 §5.
  - **Marlin** — Marlin Broadband BBA URN plus inner payload.
  - **ChinaDRM** — KID array per GY/T 277.2 plus operator-extension inner payload.
  - **Nagra**, **Verimatrix**, **Adobe Primetime** — byte-perfect opaque wrappers with file-header documentation citing closed-spec or deprecated-service status (honest treatment of providers whose wire formats are not publicly specified).
- `ProtectionSystemSpecificHeaderBox.typedInitData()` dispatch extension enabling typed access to the `pssh` `data` field for every recognised DRM system, with `.unknown(systemID:rawBytes:)` fallback for forward compatibility.

#### cmafkit-cli

- `probe` — print per-track metadata for a CMAF init segment.
- `validate` — run the CMAF / DASH / LL-HLS conformance validator.
- `dump-tree` — print the ISO BMFF box hierarchy with sizes and types.
- `decrypt-init` — print typed DRM init data for every `pssh` box.
- Three output formats: text, json, table.
- Six stable exit codes covering distinct failure classes.
- Read-only by default; never handles decryption key material.

### Quality and conformance

- 2,896 Swift Testing cases across 357 suites.
- Linux parity verified on Swift 6.2 (`swift:6.2-jammy`).
- Six Apple platforms: macOS, iOS, iPadOS, tvOS, watchOS, visionOS.
- 93.44 % global line coverage; every file ≥ 90 % or precisely justified in `codecov.yml`.
- Zero external dependencies in CMAFKit and CMAFKitDRM. The CLI depends only on Apple's `swift-argument-parser`.
- DocC catalogue: 11 articles for CMAFKit, 7 articles for CMAFKitDRM, 1 for CMAFKitCLI. Zero DocC build warnings on both SPM and xcodebuild paths.

### Notes

- Pre-1.0 status: API may evolve before 1.0 based on community feedback.
- See the audit report at the time of release (`cmafkit-0_1_0-pre-tag-audit.md`) for the full standards coverage table and quality gate results.

[0.1.0]: https://github.com/atelier-socle/swift-cmaf-kit/releases/tag/0.1.0
