# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### CMAFKit

- (Session 1) `HEVCParameterSets` aggregate type for HEVC VPS/SPS/PPS extraction from a NAL stream, per ITU-T H.265 §7.3.2 + ISO/IEC 14496-15 §8.3.3.1.
- (Session 2-3) MV-HEVC (Multi-View HEVC) complete container support — `MVHEVCSampleEntry` (`hvc2`), `MultiLayerHEVCConfiguration`, Apple HEVC Stereo Video Profile boxes (`vexu`, `stri`, `hero`), `MVHEVCPackager` actor, per ISO/IEC 14496-15 §8.4 + §I, ITU-T H.265 §F + §I, and Apple HEVC Stereo Video Profile.
- (Session 4) `RFC6381CodecStringBuilder` for canonical codec string generation and parsing, per IETF RFC 6381, ISO/IEC 14496-15 §A.5, Apple HLS Authoring §2.2, and DASH-IF Implementation Guidelines §4.
- (Session 5) `BCP47LanguageTag` typed struct + ISO 639-2/T ↔ BCP 47 bridge, per RFC 5646, RFC 4647, ISO 639-1/2/3, ISO 15924, ISO 3166-1, UN M.49, and the IANA Language Subtag Registry.
- (Session 6) `EC3JOCExtension` typed enum for first-class Dolby Atmos detection in E-AC-3 streams, per ETSI TS 102 366 Annex H.
- (Session 6) `ALACSampleEntry` + `ALACSpecificBox` for Apple Lossless audio (lossless distribution / archival), per Apple ALAC Reference Implementation (public 2011) + ISO/IEC 14496-12 §12.2.
- (Session 6) PCM sample entries — `IntegerPCMSampleEntry` (`ipcm`), `FloatingPointPCMSampleEntry` (`fpcm`), `LegacyPCMSampleEntry` (`lpcm`) + `PCMConfigurationBox` (`pcmC`), per ISO/IEC 23003-5 and ISO/IEC 14496-12 §12.2.3.
- (Session 7) `ISOConformanceValidator` — generic ISO BMFF structural validator (8 rules I1-I8), independent of CMAF profile, per ISO/IEC 14496-12 §4 + §8.
- (Session 7) `CENCConformanceValidator` — ISO/IEC 23001-7 Common Encryption validator (8 rules C1-C8), extracted from `CMAFConformanceValidator` for orthogonal validator composition.

### Removed

- (Session 1) Three placeholder modules `Sources/CMAFKit/CodecBitstream/`, `Sources/CMAFKit/CodecSampleEntries/`, `Sources/CMAFKit/CMAFProfiles/` (inert `_*Placeholder.swift` files, zero public surface — content was relocated during 0.1.0 implementation to flatter locations).

### Notes

- 19 new standards covered (cumulative total: 45+, vs 26 in 0.1.0).
- Test count: +~250 tests (cumulative ~3 150 from 2 896 in 0.1.0).
- Zero breaking change on the v0.1.0 public surface.
- Zero forbidden patterns.
- All 7 Apple targets build clean (macOS native, Mac Catalyst, iOS, iPadOS, tvOS, watchOS, visionOS); Linux builds clean with `canImport(AVFoundation)`-guarded fixtures only.

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
