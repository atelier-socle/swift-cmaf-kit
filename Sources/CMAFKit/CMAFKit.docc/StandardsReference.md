# Standards reference

The complete list of public specifications CMAFKit implements.

## Overview

CMAFKit's surface is derived from open public specifications.
Every typed value documented here cites the relevant standard
section so the implementation can be audited against the
authoritative text.

## Container formats

- **ISO/IEC 14496-12** (ISO Base Media File Format) — box
  hierarchy, sample-entry layout, edit lists, fragment
  composition, encryption boxes (`sinf`, `frma`, `schm`,
  `schi`, `tenc`, `senc`, `pssh`).
- **ISO/IEC 14496-14** (MPEG-4 Audio sample entry) — `mp4a`
  sample entry.
- **ISO/IEC 14496-15** (NAL unit structured video carriage) —
  `avcC`, `hvcC`, `vvcC` decoder configuration records.
- **ISO/IEC 14496-30** (Timed Text in ISO BMFF) — `wvtt`,
  `stpp`, `c608`, `c708` sample entries.
- **ISO/IEC 23000-19** (Common Media Application Format) — CMAF
  profile matrix, segment / fragment structure, conformance
  rules.
- **ISO/IEC 23001-7** (Common Encryption) — `cenc` / `cbc1` /
  `cens` / `cbcs` schemes.
- **ISO/IEC 23001-8** (Coding-independent code points) — colour
  primaries, transfer characteristics, matrix coefficients.
- **ISO/IEC 23009-1** (DASH ISO BMFF profile) — `sidx`,
  `styp`, `prft`, `emsg`.

## Codec bitstreams

- **ITU-T H.264** / **ISO/IEC 14496-10** (AVC) — SPS, PPS, NAL
  unit header, VUI, HRD parameters.
- **ITU-T H.265** / **ISO/IEC 23008-2** (HEVC) — VPS, SPS, PPS,
  Profile-Tier-Level, HRD, VUI, short-term reference picture
  sets, scaling list data, PPS extensions
  (range / multilayer / SCC / 3D).
- **AOMedia AV1** — sequence header, OBU framing, decoder
  model info.
- **WebM Project VP8** / **VP9** — codec configuration record.
- **MPEG-4 Visual** / **MP4V** — ES_Descriptor + DecoderConfig.
- **ETSI TS 102 366** (AC-3 / E-AC-3) — TOC, AC3SpecificBox.
- **ETSI TS 103 190-2** (AC-4) — AC4SpecificBox + presentation
  info.
- **IETF RFC 9639** (FLAC native format) — frame header,
  metadata blocks.
- **IETF RFC 8916** (Opus in MP4) — OpusSpecificBox.
- **ISO/IEC 14496-3** (AAC / GA / AudioSpecificConfig) — full
  GA-specific config parser.
- **ISO/IEC 23008-3** (MPEG-H 3D Audio) — `mhm1` / `mhm2`
  sample entries, MPEGHConfigurationBox.

## Adaptive streaming / transport

- **IETF RFC 8216bis-15** (HLS Authoring Specification + LL-HLS
  partial chunks) — partial-chunk timing, INDEPENDENT flag.
- **DASH-IF IOP** — DRM system ID registry.
- **SCTE-128** — DTVCC tunneling.
- **ATSC A/72 Part 3** — closed-caption SEI carriage.
- **DASH-IF Reference Content** — bitstream samples.

## Closed captions

- **CTA-608-E** (CEA-608) — channels 1-4, byte pairs.
- **CTA-708-E** (CEA-708) — DTVCC services 1-63, packet layout.

## Subtitles

- **W3C WebVTT** — text track format.
- **W3C TTML2** / **IMSC1** — text-profile + image-profile
  subtitle documents.

## Colour & metadata

- **ICC.1:2010** / **ICC.1:2022** — colour profile element
  types (mluc, profileSequenceDesc, textDescription, etc.).
- **SMPTE ST 2086** — mastering display colour volume.
- **CTA-861.3** — content light level info.

## DRM (CMAFKitDRM opt-in target)

- **DASH-IF DRM System Identifiers** registry.
- **Google Widevine** `CencHeader` Protocol Buffer schema
  (public).
- **Microsoft PlayReady Header Object** + **PlayReady Header
  XML** v4.0 / 4.1 / 4.2 / 4.3.
- **Apple FairPlay Streaming** Modular DRM init data format.
- **W3C Encrypted Media Extensions** ClearKey scheme.
- **Marlin Developer Community Marlin Broadband Specification**
  (BBA URN).
- **GY/T 277 / GY/T 277.2** (China DRM) — KID array layout.
- **IETF RFC 4648** §5 — base64url alphabet.

## 0.1.1 additions

### Multi-view HEVC (Sessions 1-3)

- **ITU-T H.265** §F + §I — multi-layer extensions (VPS extension,
  multi-layer SPS).
- **ISO/IEC 14496-15 §I** — multi-layer HEVC carriage (`hvc2`).
- **Apple HLS Spatial Video conventions** — `vexu` / `stri` / `hero`
  extension boxes.

### Codec strings (Session 4)

- **IETF RFC 6381** — typed codec string construction + parsing
  for all 23 codec families CMAFKit emits.
- **ISO/IEC 14496-15 §A.5** — CMAF `@codecs` attribute encoding.

### Language tags (Session 5)

- **IETF RFC 5646 / BCP 47** — Tags for Identifying Languages.
- **IETF RFC 4647** — Matching of Language Tags.
- **ISO 639-1** / **ISO 639-2** / **ISO 639-3** — language codes
  with Bibliographic/Terminologic bridging.
- **ISO 15924** — script codes.
- **ISO 3166-1 alpha-2** — country codes.
- **UN M.49** — supra-national numeric region codes.
- **IANA Language Subtag Registry** — embedded 2026-05 snapshot.

### Accessibility primitives (Session 5.5)

- **Apple HLS Authoring Specification §4.6.1-§4.6.5, §4.7** —
  `EXT-X-MEDIA` attributes (CHARACTERISTICS, AUTOSELECT, FORCED,
  DEFAULT, INSTREAM-ID, ASSOC-LANGUAGE).
- **Apple Media Accessibility Documentation** —
  `public.accessibility.*` URIs.
- **ISO/IEC 23009-1 §5.8.4.2-§5.8.4.3** — DASH `Role` +
  `Accessibility` descriptors.
- **ISO/IEC 23009-1 §5.8.5.5** — `urn:mpeg:dash:role:2011` scheme.
- **DASH-IF Implementation Guidelines v5.0+ §6.6** — accessibility
  bindings.
- **DVB-DASH (ETSI TS 103 285) §5.2** — TVA AudioPurpose
  classification scheme.
- **TVA Metadata CS `urn:tva:metadata:cs:AudioPurposeCS:2007`** —
  codes 0..7.
- **W3C Media Accessibility User Requirements**.
- **W3C WCAG 2.2 §2.3.1** — Three Flashes or Below Threshold.
- **ETSI EN 301 549 §7.1** — EU accessibility ICT.
- **EU Directive 2019/882** — European Accessibility Act
  (28 June 2025).
- **FCC §79.4** — US online video closed captioning.
- **CTA-2065** — Closed Captioning Style guide.
- **EBU Tech 3370** — Audio Description bindings.

### Audio codecs (Session 6)

- **ETSI TS 102 366 V1.4.1 Annex F.6** — `dec3` trailer byte
  (`ec3_extension_type_a`).
- **ETSI TS 102 366 V1.4.1 Annex H** — E-AC-3 JOC syntax +
  complexity index.
- **DASH-IF Implementation Guidelines v5.0+ §6.3.4** — Dolby Atmos
  DASH signalling.
- **DASH-IF Implementation Guidelines v5.0+ §6.3.7** — DASH
  uncompressed audio bindings.
- **Apple HLS Authoring §2.2.4** — EC-3 with JOC delivery
  (`CHANNELS="16/JOC"`).
- **Apple ALAC public specification** — 24-byte
  `ALACSpecificConfig` magic cookie.
- **ISO/IEC 14496-12 §12.2.3 + §12.2.3.2** — version 1 audio
  sample entry (used by `lpcm`).
- **ISO/IEC 23003-5 §4** — CMAF uncompressed audio sample entries
  (`ipcm` / `fpcm`).
- **ISO/IEC 23003-5 §5** — `PCMConfigurationBox` (`pcmC`).
- **CMAF (ISO/IEC 23000-19) §7.5.2** — uncompressed-audio profile
  + `cup1` / `cup2` brands.

### Validators (Session 7)

- **ISO/IEC 14496-12 §4-§8** — explicit ISO BMFF structural
  conformance (``ISOConformanceValidator``).
- **ISO/IEC 23001-7 §4.5-§4.9** — explicit Common Encryption
  cryptographic conformance (``CENCConformanceValidator``).

## See also

- <doc:AccessibilityAndStandards>
- <doc:ConformanceValidators>
- <doc:EncryptionSupport>
- <doc:MVHEVCGuide>
- <doc:CodecStringReference>
- <doc:LanguageTagsReference>
- <doc:AccessibilityReference>
- <doc:AudioCodecsReference>
- <doc:ValidatorsHierarchy>
