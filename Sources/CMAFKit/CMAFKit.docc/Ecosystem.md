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

## Companion projects

- **swift-podcast-feed-maker** — Podcast / Atom feed generation.
- **swift-podcast-feed-vapor** — Vapor-shaped server adapters.

## See also

- <doc:GettingStarted>
- <doc:Architecture>
