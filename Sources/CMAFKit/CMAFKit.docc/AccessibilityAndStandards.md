# Accessibility & standards

CMAFKit's coverage of the accessibility-relevant subtitle,
caption, and metadata formats.

## Overview

Accessibility for streaming media is shaped by three pillars:
**subtitles** (translated dialogue and signage), **captions**
(transcribed dialogue + sound description for users who do not
hear the audio), and **metadata** (timed cues that drive
players, ad-insertion, and content protection workflows).

CMAFKit implements every public standard required for those
pillars at the container level.

## Subtitle tracks

- **WebVTT** — W3C "WebVTT: The Web Video Text Tracks Format"
  shipped as the `wvtt` sample entry per ISO/IEC 14496-30 §7.
- **IMSC1 text** — TTML2 profile per W3C TTML2 + IMSC1
  recommendations, shipped as the `stpp` sample entry with
  MIME `application/ttml+xml;codecs=im1t`.
- **IMSC1 image** — same `stpp` sample entry with auxiliary
  MIME `application/ttml+xml;codecs=im1i`.

## Closed captions

- **CEA-608** — CTA-608-E channels cc1–cc4 (NTSC field 1 and
  field 2). Carried out-of-band via the `c608` sample entry per
  ISO/IEC 14496-30 §11.2 or in-band via SEI per ATSC A/72.
- **CEA-708** — CTA-708-E DTVCC services 1–63 (extended service
  numbering supported). Carried out-of-band via `c708` per
  ISO/IEC 14496-30 §11.3 or in-band via DTVCC packets within
  the ATSC A/72 SEI carriage.

See <doc:ClosedCaptions> for the typed extraction surface.

## Timed metadata

CMAFKit supports four metadata-track shapes via
``CMAFTrackConfiguration/MetadataFields``:

- ID3v2 timed metadata (`id3 ` sample entry per the HLS / ID3
  timed-metadata recommendation)
- KLV (SMPTE ST 336) — `mett` sample entry with
  `application/smpte-336m-klv`
- Generic text metadata — `mett` sample entry with the
  caller's MIME type
- URI-scheme metadata — `urim` sample entry with the supplied
  URI scheme

## Language carriage

Track language is the ISO 639-2/T three-character code carried
in `mdhd.language` per ISO/IEC 14496-12 §8.4.2. CMAFKit accepts
the standard 3-character codes (`und` for undetermined).

## Standards index

| Standard | Section | Coverage |
|---|---|---|
| ISO/IEC 14496-12 | §8.4.2 | media-header language |
| ISO/IEC 14496-30 | §7 / §10 / §11.2 / §11.3 | wvtt / stpp / c608 / c708 |
| W3C WebVTT | full | wvtt sample entry |
| W3C TTML2 + IMSC1 | full | stpp text + image |
| CTA-608-E | full | CEA-608 channels |
| CTA-708-E | §6 | DTVCC packets |
| ATSC A/72 Part 3 | §6.2 | in-band SEI signalling |
| SCTE-128 | §8 | DTVCC tunneling |
| HLS / ID3 Timed Metadata recommendation | full | `id3 ` sample entry |
| SMPTE ST 336 | full | KLV metadata |

## See also

- <doc:ClosedCaptions>
- <doc:StandardsReference>
