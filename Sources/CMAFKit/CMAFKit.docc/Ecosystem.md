# Ecosystem

CMAFKit's place inside the Atelier Socle streaming ecosystem.

## Overview

CMAFKit is the container and codec foundation of a family of
pure-Swift libraries that together build a complete streaming
media stack. Each library has a single, narrow responsibility;
none of them imports another's transport, packaging, or
delivery code.

## The libraries

| Library | Role |
|---|---|
| **swift-cmaf-kit** (this library) | ISO BMFF / CMAF / Common Encryption container + codec foundation |
| **swift-hls-kit** | HLS playlists, segments, LL-HLS metadata — uses CMAFKit |
| **swift-dash-kit** (future) | DASH manifest + segment authoring — will use CMAFKit |
| **swift-rtmp-kit** | RTMP transport (publish + play) over TCP |
| **swift-srt-kit** | SRT transport (publish + play) over UDP |
| **swift-icecast-kit** | Icecast / Shoutcast HTTP audio streaming |
| **swift-capture-kit** | Audio + video capture (microphone, screen, camera) |

## How CMAFKit fits

- CMAFKit reads, writes, and validates the fragmented MP4 boxes
  that every modern streaming format wraps.
- HLSKit produces `.m3u8` playlists that reference CMAF
  segments authored with CMAFKit.
- The transport libraries (RTMP, SRT, Icecast) carry the raw
  bytes; they do not know about CMAF directly.
- CaptureKit produces the audio + video samples that
  CMAFMediaSegmentWriter packages.

## Integration patterns

### HLS — typed codec strings for `EXT-X-STREAM-INF`

HLSKit consumes CMAFKit's typed ``RFC6381CodecDescriptor`` to emit
the `CODECS` attribute on `EXT-X-STREAM-INF`. The string is
generated once from a typed descriptor — no string concatenation:

```swift
import CMAFKit

let avcBaseline = RFC6381CodecDescriptor.avc(
    sampleEntry: .avc1,
    profile: 0x42,
    constraint: 0xE0,
    level: 0x1E
)
let codecString = RFC6381CodecStringBuilder()
    .codecString(for: avcBaseline)
// "avc1.42e01e" — ready for EXT-X-STREAM-INF CODECS
```

See <doc:CodecStringReference> for the full typed-descriptor surface
covering every codec CMAFKit supports.

### DRM — parsing `pssh` in CMAFKit, typed dispatch in CMAFKitDRM

CMAFKit parses ``ProtectionSystemSpecificHeaderBox`` (`pssh`) as a
generic structural box — the `systemID` (DRM UUID), optional version-1
key identifiers, and the opaque `data` payload:

```swift
import CMAFKit

let pssh = ProtectionSystemSpecificHeaderBox(
    version: 1,
    systemID: UUID(),         // 16-byte DRM system identifier
    keyIdentifiers: [],
    data: Data()              // opaque per-provider payload
)
```

The optional companion library **CMAFKitDRM** adds a typed dispatch
extension `ProtectionSystemSpecificHeaderBox/typedInitData()` that
routes by `systemID` into typed init-data values (`Widevine`,
`PlayReady`, `FairPlay`, `ClearKey`, `Marlin`, `Verimatrix`, `Nagra`,
`Adobe`, `ChinaDRM`). Importing CMAFKitDRM adds the dispatch without
modifying the base box:

```swift
// In a target that depends on CMAFKitDRM:
//   import CMAFKitDRM
//   let typed = try pssh.typedInitData()
//   switch typed { case .widevine(let v): ...; case .playReady(let v): ...; }
```

The boundary is intentional: CMAFKit knows nothing about specific
DRM providers; CMAFKitDRM knows nothing about CMAF segments. The
extension stitches them at the `pssh` box only.

## Companion projects

- **swift-podcast-feed-maker** — Podcast / Atom feed generation.
- **swift-podcast-feed-vapor** — Vapor-shaped server adapters.

## See also

- <doc:GettingStarted>
- <doc:Architecture>
