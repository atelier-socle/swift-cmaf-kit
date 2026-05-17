# swift-cmaf-kit

[![CI](https://github.com/atelier-socle/swift-cmaf-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/atelier-socle/swift-cmaf-kit/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/atelier-socle/swift-cmaf-kit/branch/main/graph/badge.svg)](https://codecov.io/gh/atelier-socle/swift-cmaf-kit)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%2014%20|%20iOS%2017%20|%20iPadOS%2017%20|%20tvOS%2017%20|%20watchOS%2010%20|%20visionOS%201%20|%20Linux-blue.svg)]()
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

![swift-cmaf-kit](./assets/banner.png)

> ⚠️ **Pre-release.** APIs ship at the 0.1.0 tag. Snippets below reflect the planned 0.1.0 surface.

swift-cmaf-kit is a pure-Swift, enterprise-grade implementation of ISOBMFF (ISO/IEC 14496-12), CMAF (ISO/IEC 23000-19), and Common Encryption (ISO/IEC 23001-7). Read, write, validate, and encrypt fMP4 / CMAF media end-to-end. Cross-platform from day one: macOS, iOS, iPadOS, tvOS, watchOS, visionOS, and Linux. Zero C vendoring. Swift 6.2 strict concurrency.

Part of the [Atelier Socle](https://www.atelier-socle.com) ecosystem. CMAFKit is the container and codec foundation that powers [swift-hls-kit](https://github.com/atelier-socle/swift-hls-kit) (0.7.0+) and the upcoming swift-dash-kit.

---

## Features

### Reading

- **ISOBMFF parsing** — Every box from ISO/IEC 14496-12 needed for streaming, with typed surfaces and unknown-box round-trip preservation
- **Track analysis** — Codec string (RFC 6381), duration, language, video dimensions, audio format, HDR / DV metadata, encryption surface
- **Sample tables** — `SampleLocator` with sample-accurate decoding / presentation / duration / size / offset queries and sync-sample helpers
- **Streaming reader** — `StreamingBoxReader` based on `AsyncThrowingStream` for files larger than RAM

### Writing

- **Init segments** — `CMAFInitSegmentWriter` for VOD; `CMAFFragmentWriter` actor for live streams
- **Media segments** — Audio, video, and muxed segments with monotonic `tfdt` and sample-accurate offsets
- **CMAF chunks** — Sub-fragment generation for `cmfl` low-latency HLS / DASH
- **Segment index** — `SegmentIndexBuilder` for `sidx` / `ssix`
- **MV-HEVC** — Stereoscopic packaging for Apple Vision Pro via `MVHEVCPackager`
- **IMSC1 subtitles** — W3C TTML to fMP4 segments via `IMSC1FragmentWriter`

### Validating

- **Structural** — `ISOStructuralValidator` against ISO/IEC 14496-12 box rules
- **CMAF profiles** — `CMAFConformanceValidator` for every brand (`cmfc`, `cmf2`, `chh1`, `chd1`, `cav1`, `caac`, `cac3`, `cec3`, `cmfl`, …)
- **CENC coherence** — `CENCValidator` cross-checks `tenc` / `senc` / `saiz` / `saio` / `sbgp` / `sgpd` / `pssh`
- **Codec configuration** — `CodecConfigurationValidator` matches sample-entry config against actual sample data

### Encrypting (Common Encryption)

- **All four schemes** — `cenc` (CTR), `cbc1` (CBC), `cens` (CTR pattern), `cbcs` (CBC pattern)
- **Pattern encryption** — `crypt_byte_block` / `skip_byte_block` for `cens` and `cbcs`
- **Multi-key + key rotation** — `sbgp` / `sgpd` with `seig` grouping type and `CENCKeyRotationBuilder`
- **PSSH passthrough** — Widevine, PlayReady, FairPlay, ClearKey system IDs via `PSSHBuilder` (CMAFKit does not fetch DRM licences)
- **Cross-platform crypto** — CryptoKit on Apple, `swift-crypto` on Linux

### Codecs covered

- **Video** — H.264 (avc1, avc3), HEVC (hvc1, hev1), MV-HEVC (hvc2, hev2, lhe1, lhv1 + lhcC), AV1 (av01), ProRes, Motion JPEG
- **Audio** — AAC-LC / HE-AAC v1 / v2 / xHE-AAC (mp4a), AC-3 (ac-3 / dac3), Enhanced AC-3 + Atmos JOC (ec-3 / dec3), Opus (`Opus` / dOps), FLAC (fLaC / dfLa), ALAC, Linear PCM, MP3
- **Subtitles** — IMSC1 / TTML (`stpp`)

### HDR metadata

- **HDR10** — `mdcv` (SMPTE ST 2086) + `clli` (CTA-861.3)
- **HDR10+** — SMPTE ST 2094-40 SEI passthrough
- **Dolby Vision** — `dvcC` / `dvvC` for profiles 5, 7, 8, 10 (with `dvBLSignalCompatibilityID` sub-flavor surface per addendum F.6)
- **HLG / PQ** — Colour signalling via `nclx` (ITU-R BT.2100)

### CLI

- **`cmafkit-cli`** — `info`, `dump`, `validate`, `extract-codec`, `codec-string`, `verify-cenc`, `verify-fragments`, `extract-sidx`, `hdr-info`

---

<details>
<summary><strong>Standards covered (collapsible)</strong></summary>

| Standard | Sections |
|---|---|
| ISO/IEC 14496-12 (ISOBMFF) | §4–§8, §12 (sample entries) |
| ISO/IEC 14496-14 (MP4) | §5 (esds binding) |
| ISO/IEC 14496-15 (NAL codecs) | §5 (AVC), §8 (HEVC), §8.4 (L-HEVC), Annex G (MV-HEVC) |
| ISO/IEC 14496-1 (Systems) | §7.2.6.5–7 (descriptors) |
| ISO/IEC 14496-3 (Audio) | §1.6.2.1 (AudioSpecificConfig) |
| ISO/IEC 23000-19 (CMAF) | §6–§7, Annex A |
| ISO/IEC 23001-7 (CENC) | §4, §8, §9, §10, §11 (all 4 schemes) |
| ISO/IEC 23001-8 (CICP) | §7, Annex A |
| ETSI TS 102 366 (AC-3 / E-AC-3) | §4, Annex E.1, F.2, F.3, F.6 |
| RFC 6381 | Codec string |
| RFC 7845 | Opus identification header |
| Opus-in-ISOBMFF | OpusSampleEntry, dOps |
| FLAC-in-ISOBMFF | FLACSampleEntry, dfLa |
| AV1 ISOBMFF binding v1.2 | av01, av1C |
| Apple ALAC | alac sample entry |
| SMPTE ST 2086 | mdcv |
| CTA-861.3 | clli |
| SMPTE ST 2094-10 | dvcC / dvvC |
| ITU-R BT.2100 | PQ + HLG via CICP |
| ISO 639-2/T | Language code packing |
| ITU-T H.264 / H.265 | SPS / PPS / VPS parsers |

</details>

---

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/swift-cmaf-kit.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "CMAFKit", package: "swift-cmaf-kit")
        ]
    )
]
```

### Requirements

- **Swift 6.2+** with strict concurrency
- **Library platforms**: macOS 14+, iOS 17+, iPadOS 17+, tvOS 17+, watchOS 10+, visionOS 1+
- **CLI platforms**: macOS 14+, Linux (Ubuntu 22.04+)
- **Dependencies**: `swift-crypto` (Linux only) and `swift-argument-parser` (CLI only)

---

## Quick start

### Library — read

```swift
import CMAFKit

let inspector = ISOFileInspector()
let info = try await inspector.inspect(URL(fileURLWithPath: "/path/to/file.mp4"))
print(info.majorBrand)          // e.g., "cmfc"
print(info.tracks.first?.codecString)  // e.g., "avc1.640028"
```

### Library — write

```swift
import CMAFKit

let writer = CMAFFragmentWriter(
    audioConfig: audioConfig,
    videoConfig: videoConfig
)
let initSegment = try await writer.generateMuxedInitSegment()
let mediaSegment = try await writer.generateMuxedMediaSegment(
    audio: audioFrames,
    video: videoFrames,
    segmentIndex: 0
)
```

### Library — validate

```swift
import CMAFKit

let validator = CMAFConformanceValidator(strict: true)
let report = try validator.validate(initSegment: data, against: .hevcHD)
guard report.isValid else {
    for issue in report.issues {
        print("\(issue.severity) — \(issue.isoSection): \(issue.message)")
    }
    return
}
```

### CLI

```bash
# Inspect a file
cmafkit-cli info myfile.mp4

# Print the box tree
cmafkit-cli dump myfile.mp4 --depth 5

# Validate against a CMAF profile
cmafkit-cli validate myfile.mp4 --profile cmf2 --strict

# Extract codec configuration
cmafkit-cli extract-codec myfile.mp4 --track 1 --format hvcC

# Generate RFC 6381 codecs= attribute
cmafkit-cli codec-string myfile.mp4
```

---

## Documentation

Full DocC documentation is published at <https://atelier-socle.github.io/swift-cmaf-kit/0.1.0/> after the 0.1.0 tag.

---

## License

Apache 2.0 — see [LICENSE](LICENSE).

---

## Ecosystem

- [swift-hls-kit](https://github.com/atelier-socle/swift-hls-kit) — HLS VOD + Live (depends on CMAFKit from 0.7.0)
- swift-dash-kit — MPEG-DASH (planned, depends on CMAFKit)
- [swift-capture-kit](https://github.com/atelier-socle/swift-capture-kit) — Unified media capture
- [swift-srt-kit](https://github.com/atelier-socle/swift-srt-kit) — Pure Swift SRT
- [swift-icecast-kit](https://github.com/atelier-socle/swift-icecast-kit) — Icecast / SHOUTcast
- [swift-rtmp-kit](https://github.com/atelier-socle/swift-rtmp-kit) — RTMP broadcast
