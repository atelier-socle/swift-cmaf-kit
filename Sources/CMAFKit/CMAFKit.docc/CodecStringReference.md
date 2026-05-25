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
`"avc1.42e01e"`, `"hvc1.2.4.L123.90"`, `"ec-3"`, `"alac"`,
`"ipcm"`). The configuration overload routes a parsed track through
the codec dispatch tables to produce the same string from a
high-level ``CMAFTrackConfiguration``.

## Canonical samples

### AVC (H.264) Baseline, Level 3.0

The Baseline profile / Level 3.0 example from RFC 6381 itself:

```swift
import CMAFKit

let builder = RFC6381CodecStringBuilder()
let avcBaseline = RFC6381CodecDescriptor.avc(
    sampleEntry: .avc1,
    profile: 0x42,
    constraint: 0xE0,
    level: 0x1E
)
let string = builder.codecString(for: avcBaseline)  // "avc1.42e01e"
```

The output is lowercase hexadecimal per the RFC 6381 convention.

### HEVC Main10, Level 4.1 (Apple HLS example)

The HEVC Main10 string used by Apple's HLS authoring guide:

```swift
import CMAFKit

let builder = RFC6381CodecStringBuilder()
let hevcMain10 = RFC6381CodecDescriptor.hevc(
    sampleEntry: .hvc1,
    profileSpace: 0,
    profile: 2,
    profileCompat: 0x4000_0000,
    tier: .main,
    level: 123,
    constraintFlags: Data([0x90, 0, 0, 0, 0, 0])
)
let string = builder.codecString(for: hevcMain10)
// "hvc1.2.4.L123.90"
```

Level 123 = 4.1 (Apple HLS Authoring §2.2.1).

### E-AC-3 with Dolby Atmos (JOC)

The JOC flag stays out of the codec string; ``EC3SpecificBox/carriesDolbyAtmos``
is signalled through the HLS `CHANNELS="16/JOC"` attribute or the
DASH `<SupplementalProperty>` instead:

```swift
import CMAFKit

let builder = RFC6381CodecStringBuilder()
let plain = builder.codecString(for: .ec3(joc: false))  // "ec-3"
let atmos = builder.codecString(for: .ec3(joc: true))   // "ec-3"
```

### Apple Lossless (ALAC)

ALAC has no variant tail — the codec string is bare:

```swift
let alac = RFC6381CodecStringBuilder().codecString(for: .alac)  // "alac"
```

### CMAF PCM (ipcm / fpcm / lpcm)

The three ISO/IEC 23003-5 PCM sample entries each have a bare codec
string matching the four-character sample-entry box type:

```swift
import CMAFKit

let builder = RFC6381CodecStringBuilder()
let integer = builder.codecString(for: .pcmIPCM)  // "ipcm"
let floating = builder.codecString(for: .pcmFPCM) // "fpcm"
let legacy = builder.codecString(for: .pcmLPCM)   // "lpcm"
```

### Dolby Vision

Dolby Vision Profile 5 / Level 6 (`dvh1.05.06`) for HEVC:

```swift
import CMAFKit

let dv = RFC6381CodecDescriptor.dolbyVision(
    sampleEntry: .dvh1,
    profile: .profile5,
    level: .level06
)
let string = RFC6381CodecStringBuilder().codecString(for: dv)
// "dvh1.05.06"
```

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
