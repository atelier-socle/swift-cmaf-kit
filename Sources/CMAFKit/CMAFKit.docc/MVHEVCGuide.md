# Multi-view HEVC and Apple Vision Pro spatial video

First-class typed support for stereoscopic and multi-view HEVC
delivery per ISO/IEC 14496-15 §I and the Apple HLS Spatial Video
conventions (`vexu` / `stri` / `hero`).

## Overview

Multi-view HEVC carries two or more spatially coherent views inside a
single HEVC stream — the canonical use case is stereoscopic spatial
video for Apple Vision Pro. CMAFKit ships the complete chain: HEVC
bitstream extensions (VPS extension, multi-layer SPS), the ISOBMFF
sample entry (`hvc2`) with the multi-layer configuration record, the
Apple Spatial Video extension boxes (`vexu`, `stri`, `hero`), and a
high-level packager (``MVHEVCPackager``).

## HEVC bitstream foundation

``HEVCParameterSets`` aggregates the VPS / SPS / PPS triplet
extracted from a NAL stream, per ITU-T H.265 §7.3.2 + ISO/IEC
14496-15 §8.3.3.1.

Multi-layer HEVC adds two structures consumed by the sample-entry
configuration:

- ``HEVCVPSExtension`` — `vps_extension()` carrying scalability
  metadata (layer count, view IDs, layer dependencies) per ITU-T
  H.265 §F.7.3.2.1.
- ``HEVCMultiLayerSPS`` — per-non-base-layer SPS with the multi-layer
  extension per ITU-T H.265 §F + §I.

## ISOBMFF integration

The `hvc2` sample entry combines the base + extension layer with a
multi-layer configuration record:

- ``MVHEVCSampleEntry`` — the `hvc2` sample entry box.
- ``MultiLayerHEVCConfiguration`` — the typed aggregate carrying
  `hvcCBase` (base-layer `HEVCDecoderConfigurationRecord`),
  `hvcCExtension` (extension-layer record), and `layerDependencies`.

Apple Spatial Video signalling lives in three extension boxes inside
the sample entry:

- ``ViewExtendedUsageBox`` (`vexu`) — wraps the typed view-extension
  family.
- ``StereoInformationBox`` (`stri`) — carries the stereo arrangement
  and the three Float32 millimetre distances (baseline, primary-eye
  offset, view-distance) per Apple's spatial-video signalling.
- ``HeroEyeInformationBox`` (`hero`) — identifies the primary view
  for fallback rendering.

## Composition

``MVHEVCPackager`` is the actor-based entry point for fragmenting an
MV-HEVC stream:

```swift
let packager = MVHEVCPackager(
    configuration: configuration,
    heroLayerID: 0)
// ... append samples via the packager API
try await packager.stop()
```

The actor exposes `nonisolated` constants for the immutable
``MultiLayerHEVCConfiguration`` and `heroLayerID`, so callers can
read them without awaiting actor isolation. The packager carries an
explicit `.active` / `.stopped` state machine — the `stop()` contract
is documented on the actor because deinit-time assertion is not
available in Swift 6.

## Codec strings

The RFC 6381 codec string for `hvc2` is generated via the typed
``RFC6381CodecStringBuilder``. See <doc:CodecStringReference>.

## Standards covered

- **ITU-T H.265 §7.3.2** — VPS / SPS / PPS syntax (base layer)
- **ITU-T H.265 §F + §I** — multi-layer extensions
- **ISO/IEC 14496-15 §8** — HEVC carriage in ISO BMFF
- **ISO/IEC 14496-15 §I** — multi-layer HEVC carriage (`hvc2`)
- **ISO/IEC 14496-15 §A.5** — CMAF codec attribute construction
- **Apple HLS Spatial Video conventions** — `vexu` / `stri` / `hero`

## See also

- <doc:CodecStringReference>
- <doc:WritingCMAFContent>
- ``HEVCParameterSets``
- ``HEVCVPSExtension``
- ``HEVCMultiLayerSPS``
- ``MultiLayerHEVCConfiguration``
- ``MVHEVCSampleEntry``
- ``MVHEVCPackager``
- ``ViewExtendedUsageBox``
- ``StereoInformationBox``
- ``HeroEyeInformationBox``
