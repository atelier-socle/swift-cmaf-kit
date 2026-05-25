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

Building a minimal 2-layer stereo-pair VPS extension and round-tripping
it through the bitstream encoder:

```swift
import CMAFKit

let vpsExtension = HEVCVPSExtension(
    maxLayerCount: 2,
    layerIDs: [0, 1],
    layerDependencies: [
        LayerDependency(layerID: 0, dependsOnLayerIDs: []),
        LayerDependency(layerID: 1, dependsOnLayerIDs: [0])
    ],
    scalabilityMask: ScalabilityMask(raw: 0b0000_0000_0000_0010),
    dimensionIDLen: [1],
    dimensionID: [[0], [1]],
    directRefLayers: [[], [0]],
    viewIDValues: [0, 1],
    auxIDValues: [],
    outputLayerSets: [
        OutputLayerSet(layerSetIDx: 0, outputLayerFlags: [true, true])
    ]
)
var writer = BitWriter()
try vpsExtension.encode(to: &writer)
var reader = BitReader(writer.finish())
let recovered = try HEVCVPSExtension.parse(bitstream: &reader)
```

``LayerDependency`` declares which layers each non-base layer reads
from; ``OutputLayerSet`` enumerates the renderable layer combinations.
The encode/parse pair is byte-identical: the recovered extension
equals the original.

## ISOBMFF integration

The `hvc2` sample entry combines the base + extension layer with a
multi-layer configuration record:

- ``MVHEVCSampleEntry`` — the `hvc2` sample entry box.
- ``MultiLayerHEVCConfiguration`` — the typed aggregate carrying
  `hvcCBase` (base-layer `HEVCDecoderConfigurationRecord`),
  `hvcCExtension` (extension-layer record), and `layerDependencies`.

Building a 2-layer stereo `MultiLayerHEVCConfiguration` and round-tripping
it through the box encoder:

```swift
import CMAFKit

let configuration = MultiLayerHEVCConfiguration(
    baseLayer: baseRecord,
    extensionLayer: extensionRecord,
    layerIDs: [0, 1],
    temporalIDs: [0, 0],
    layerDependencies: [
        LayerDependency(layerID: 0, dependsOnLayerIDs: []),
        LayerDependency(layerID: 1, dependsOnLayerIDs: [0])
    ],
    viewIDs: [0, 1],
    outputLayerSetIDs: [0]
)
var writer = BinaryWriter()
configuration.encode(to: &writer)
var reader = BinaryReader(writer.data)
let recovered = try await MultiLayerHEVCConfiguration.parse(from: &reader)
```

Apple Spatial Video signalling lives in three extension boxes inside
the sample entry:

- ``ViewExtendedUsageBox`` (`vexu`) — wraps the typed view-extension
  family.
- ``StereoInformationBox`` (`stri`) — carries the stereo arrangement
  and the three Float32 millimetre distances (baseline, primary-eye
  offset, view-distance) per Apple's spatial-video signalling.
- ``HeroEyeInformationBox`` (`hero`) — identifies the primary view
  for fallback rendering.

Composing a 4K spatial-video `hvc2` sample entry with all three Apple
extension boxes attached:

```swift
import CMAFKit

let sampleEntry = MVHEVCSampleEntry(
    visualFields: VisualSampleEntryFields(width: 4096, height: 2160),
    hvcCBase: baseRecord,
    vexu: ViewExtendedUsageBox(viewIdentifier: 0, usageFlags: 0x01),
    stri: StereoInformationBox(stereoArrangement: .stereoLayered),
    hero: HeroEyeInformationBox(heroEye: .leftEye),
    multiLayerConfiguration: configuration
)
var writer = BinaryWriter()
sampleEntry.encode(to: &writer)
let registry = await BoxRegistry.defaultRegistry()
let reader = ISOBoxReader()
let parsed = try await reader.readBoxes(from: writer.data, using: registry)
let recovered = parsed.first as? MVHEVCSampleEntry
```

Each Apple extension box is also independently round-trippable through
the registry. ``ViewExtendedUsageBox`` (`vexu`) carries the view
identifier and per-view usage flags:

```swift
let vexu = ViewExtendedUsageBox(viewIdentifier: 0, usageFlags: 0x01)
```

``StereoInformationBox`` (`stri`) carries the arrangement enum (in
addition to the optional Float32 distances when produced from
parsed-out content):

```swift
let stri = StereoInformationBox(stereoArrangement: .stereoLayered)
```

``HeroEyeInformationBox`` (`hero`) names the primary eye for fallback
rendering when the player cannot render both views:

```swift
let hero = HeroEyeInformationBox(heroEye: .leftEye)
```

## Composition

``MVHEVCPackager`` is the actor-based entry point for fragmenting an
MV-HEVC stream:

```swift
import CMAFKit

let packager = MVHEVCPackager(
    configuration: configuration,
    heroEye: .leftEye
)
// ... append samples via the packager API
await packager.stop()
let stopped = await packager.isStopped  // true
```

The actor exposes `nonisolated` constants for the immutable
``MultiLayerHEVCConfiguration`` and ``MVHEVCPackager/heroLayerID``
(resolved from `heroEye` at init via the Apple Vision Pro
convention: `.leftEye` → layer 0, `.rightEye` → layer 1), so callers
can read them without awaiting actor isolation. The packager carries
an explicit `.active` / `.stopped` state machine — `stop()` transitions
into `.stopped` and is documented on the actor because deinit-time
assertion is not available in Swift 6.

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
