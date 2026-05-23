# Atelier Socle — streaming media showcase

CMAFKit sits inside a family of pure-Swift libraries that
together build a complete streaming media stack. Each library
has a single, narrow responsibility; none of them imports
another's transport, packaging, or delivery code. This page
maps the family.

## Mission

Build reference, audit-grade Swift libraries for streaming
media. Pure Swift wherever possible (no C vendoring). Strict
Swift 6 concurrency. Standards-first: every public symbol cites
the specification section it implements. Cross-platform from
day one (macOS, iOS, iPadOS, tvOS, watchOS, visionOS, Linux).

## The six core libraries

### swift-cmaf-kit (this repository)

ISO Base Media File Format + Common Media Application Format
foundation. Reads, writes, validates, and surfaces typed
metadata for fragmented MP4 / CMAF media. Implements the
ISO/IEC 14496-12, ISO/IEC 23000-19, ISO/IEC 23001-7
specifications end-to-end.

Provides two library products: `CMAFKit` (the container + codec
foundation) and `CMAFKitDRM` (opt-in typed DRM init-data
decoding for the nine Common Encryption system identifiers).

### swift-hls-kit

HLS playlist generation, manifest validation, and segment
authoring. Depends on CMAFKit for the segment-level container.
Implements IETF RFC 8216bis-15 including LL-HLS partial chunks,
EXT-X-KEY signalling, byterange addressing, and
INTERSTITIAL / DATERANGE timed metadata.

### swift-rtmp-kit

Pure-Swift implementation of the RTMP transport protocol over
TCP. Publish + play. Used as one of the transport options by
the broader Atelier Socle ingest pipeline.

### swift-srt-kit

Pure-Swift implementation of the SRT (Secure Reliable
Transport) protocol over UDP. Publish + play. Built for low-
latency contribution and last-mile delivery.

### swift-icecast-kit

Icecast / Shoutcast HTTP-based audio streaming. Source-client
and listener-side. Targets the lightweight HTTP-streaming
audio use case (radio, podcast distribution, ambient audio).

### swift-capture-kit

Audio + video capture primitives. Reads from microphones,
screens, and cameras across Apple platforms. Produces sample
buffers consumable by CMAFKit's media-segment writer or by
the transport libraries directly.

## Companion projects

- **swift-podcast-feed-maker** — Atom / RSS / podcast feed
  generation.
- **swift-podcast-feed-vapor** — Vapor-shaped server adapters
  for podcast feed delivery.

## Composition example

A live-streaming pipeline can be assembled by composing the
above libraries:

```
CaptureKit (microphone + camera)
        │  CMSampleBuffer / AudioBufferList
        ▼
CMAFKit  (CMAFMediaSegmentWriter)
        │  CMAFFragmentSegment.bytes
        ▼
HLSKit   (playlist composer + segment storage)
        │  .m3u8 + .m4s files
        ▼
SRTKit / RTMPKit / IcecastKit  (transport to CDN / origin)
```

No library imports another's transport layer directly; the
contract is "a stream of bytes" at every boundary.

## The future libraries roadmap

- **swift-dash-kit** — MPEG-DASH manifest authoring; will
  depend on CMAFKit for the segment-level container, mirroring
  HLSKit's design.
- **swift-rtp-kit** — Real-Time Protocol (RFC 3550) for
  WebRTC / SIP / SRTP-bearing applications.
- **swift-rist-kit** — Reliable Internet Stream Transport
  (TR-06-1) for low-latency contribution.
- **swift-webrtc-kit** — Pure-Swift WebRTC SFU / peer client
  for real-time audio + video.

## Engineering principles

- **Standards-first**: every public symbol carries a doc
  comment citing the specification section it implements.
- **Zero hidden globals**: no singletons, no shared mutable
  state.
- **Strict concurrency**: every public type is `Sendable`. No
  `@unchecked Sendable`, no `nonisolated(unsafe)`, no
  `@preconcurrency`.
- **Honest opacity**: when a vendor wire format is not publicly
  documented (Nagra, Verimatrix, Adobe Primetime), we ship a
  byte-perfect opaque wrapper with the closed-spec status
  documented in the file header — rather than fake-typing
  fields we cannot validate.
- **Zero compromises on tests**: every public symbol is
  exercised by a typed Swift Testing case; every fragment of
  bitstream parsing has a round-trip test.
- **Cross-platform**: every release runs the full test suite
  on the six Apple platforms (macOS, iOS, iPadOS, tvOS,
  watchOS, visionOS) and on Linux (Swift 6.2 toolchain in
  Docker).

## Repository links

- swift-cmaf-kit — this repository
- swift-hls-kit — https://github.com/atelier-socle/swift-hls-kit
- swift-rtmp-kit — https://github.com/atelier-socle/swift-rtmp-kit
- swift-srt-kit — https://github.com/atelier-socle/swift-srt-kit
- swift-icecast-kit — https://github.com/atelier-socle/swift-icecast-kit
- swift-capture-kit — https://github.com/atelier-socle/swift-capture-kit

## License

All Atelier Socle libraries ship under the Apache 2.0 license.
