# RFC 6381 codec strings

Typed construction and parsing of the codec strings consumed by HLS
`EXT-X-STREAM-INF CODECS` attribute (Apple HLS Authoring §2.2) and
DASH `AdaptationSet@codecs` attribute (DASH-IF Implementation
Guidelines §4) per IETF RFC 6381.

## Overview

The codec string is the byte-exact identifier players match against
their codec list to decide whether they can decode a presentation.
CMAFKit ships a typed bidirectional API: a 23-case discriminated
union (``RFC6381CodecDescriptor``) describes every codec family the
library supports, and a stateless builder (``RFC6381CodecStringBuilder``)
emits and parses the canonical string form.

## The typed descriptor

``RFC6381CodecDescriptor`` covers the full codec matrix CMAFKit
emits:

- AVC: `.avc(sampleEntry: .avc1|.avc3, profile:constraint:level:)`
- HEVC: `.hevc(sampleEntry: .hvc1|.hev1, profile:tier:level:...)`
- MV-HEVC: `.mvHEVC(...)` (`hvc2`)
- Dolby Vision: `.dolbyVision(sampleEntry: .dvh1|.dvhe|.dvav|.dav1, ...)`
- AV1: `.av1(...)`
- VP9: `.vp9(...)`, `.vp8`
- AAC: `.mp4a(audioObjectType:)`
- AC-3 / E-AC-3: `.ac3`, `.ec3(joc:)`
- AC-4: `.ac4(presentationID:)`
- MPEG-H 3D Audio: `.mpegH(sampleEntry: .mhm1|.mhm2, profileLevelIndication:)`
- Opus: `.opus`
- FLAC: `.flac`
- Apple Lossless: `.alac`
- CMAF PCM: `.pcmIPCM`, `.pcmFPCM`, `.pcmLPCM`
- Subtitles: `.webVTT`, `.imsc1Text`, `.imsc1Image`

## The builder

``RFC6381CodecStringBuilder`` is a stateless struct exposing two
public methods:

```swift
public func codecString(for descriptor: RFC6381CodecDescriptor) -> String
public func codecString(for configuration: CMAFTrackConfiguration) throws -> String
```

The descriptor overload generates the canonical string form (e.g.,
`"avc1.42E01E"`, `"hvc1.2.4.L120.B0"`, `"ec-3"`, `"alac"`,
`"ipcm"`). The configuration overload routes a parsed track through
the codec dispatch tables to produce the same string from a
high-level ``CMAFTrackConfiguration``.

## EC-3 JOC integration

E-AC-3 streams carrying Dolby Atmos via the JOC extension produce
the same `"ec-3"` codec string — JOC is signalled out-of-stream via
the HLS `CHANNELS="16/JOC"` attribute (Apple HLS Authoring §2.2.4)
or the DASH `<SupplementalProperty>` (DASH-IF §6.3.4). The builder
detects JOC via ``EC3SpecificBox/carriesDolbyAtmos`` and propagates
it on the descriptor's `joc: Bool` parameter. See
<doc:AudioCodecsReference>.

## Standards covered

- **IETF RFC 6381** — codec string construction
- **ISO/IEC 14496-15 §A.5** — CMAF `@codecs` attribute encoding
- **Apple HLS Authoring §2.2** — `EXT-X-STREAM-INF CODECS`
- **Apple HLS Authoring §2.2.4** — EC-3 / JOC delivery
- **DASH-IF Implementation Guidelines §4** — DASH `@codecs`
- **DASH-IF Implementation Guidelines §6.3.4** — Atmos signalling

## See also

- <doc:MVHEVCGuide>
- <doc:AudioCodecsReference>
- ``RFC6381CodecDescriptor``
- ``RFC6381CodecStringBuilder``
