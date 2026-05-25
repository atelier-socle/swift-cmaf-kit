# Writing CMAF content

Compose CMAF init and media segments from typed track
configurations and sample inputs.

## Overview

CMAFKit's writer surface is built around two value types:
``CMAFInitSegmentWriter`` for the file's `ftyp` + `moov`
prologue, and ``CMAFMediaSegmentWriter`` for the streaming
sequence of `moof` + `mdat` fragment segments. The latter is an
actor because it accumulates per-track state across calls
(monotonic `mfhd.sequence_number`, `tfdt.baseMediaDecodeTime`
per track, partial-chunk grouping under LL-HLS).

## Topics

### Init segment composition

Build a `CMAFTrackConfiguration` per track and pass them to
``CMAFInitSegmentWriter/init(configurations:movieTimescale:referenceTimestamp:)``.
The writer emits an `ftyp` box (with major brand selected from
the supplied ``CMAFProfile``) followed by a `moov` carrying the
typed sample-entry trees per ISO/IEC 14496-12 §8.

A single-track video init segment:

```swift
import CMAFKit

let writer = try CMAFInitSegmentWriter(configurations: [videoConfig])
let bytes = try writer.emit()
// `bytes` starts with `ftyp` then `moov`
```

A two-track video + audio init segment shares one
``CMAFInitSegmentWriter`` — the writer enforces unique
``CMAFTrackConfiguration/trackID`` values and a single shared
``CMAFTrackConfiguration/profile``:

```swift
import CMAFKit

let writer = try CMAFInitSegmentWriter(configurations: [
    videoConfig,   // trackID 1, .video
    audioConfig    // trackID 2, .audio
])
let bytes = try writer.emit()
// the emitted `moov` carries two `trak` boxes
```

### Media segment composition

For each track, instantiate ``CMAFMediaSegmentWriter``,
append samples via
``CMAFMediaSegmentWriter/appendSample(_:toTrack:)``, and call
``CMAFMediaSegmentWriter/finalize()`` to flush any pending
samples. Every fragment boundary returns one or more
``CMAFFragmentSegment`` values whose `bytes` field is the
complete segment payload ready to write to disk or push onto a
transport.

Configuring the writer with a fragment boundary and appending
samples until the boundary fires:

```swift
import CMAFKit

let writer = try CMAFMediaSegmentWriter(
    configuration: videoConfig,
    fragmentBoundary: .sampleCount(3)
)
var emitted: [CMAFFragmentSegment] = []
for _ in 0..<3 {
    emitted += try await writer.appendSample(sample, toTrack: 1)
}
// emitted.count == 1
// emitted.first?.sequenceNumber == 1
```

The actor exposes ``CMAFMediaSegmentWriter/state`` — useful for
diagnostic logging or asserting test expectations on the writer's
internal phase (`.empty`, `.openFragment`, `.finalized`):

```swift
import CMAFKit

let writer = try CMAFMediaSegmentWriter(
    configuration: videoConfig,
    fragmentBoundary: .sampleCount(10)
)
_ = try await writer.appendSample(sample, toTrack: 1)
let state = await writer.state
// state == .openFragment(trackID: 1, sampleCount: 1)
```

### Encryption

When a `CMAFTrackConfiguration` carries
``CMAFEncryptionParameters``, the writer rewrites the sample
entry to `encv` / `enca`, emits `sinf` / `schm` / `schi` /
`tenc` boxes per ISO/IEC 23001-7, and embeds `senc` boxes
inside each `traf` carrying the supplied per-sample IVs and
subsample partitions. The `pssh` boxes attached to the
encryption parameters are emitted at the `moov` level.

### Low-latency partial chunks

Configure ``CMAFMediaSegmentWriter`` with a
``CMAFPartialChunkBoundary`` (in addition to the fragment
boundary) to emit LL-HLS partial chunks per IETF RFC
8216bis-15 §B. Each chunk is exposed as a ``CMAFPartialChunk``
inside the parent ``CMAFFragmentSegment``.

## See also

- <doc:FragmentBoundaries>
- <doc:EncryptionSupport>
- ``CMAFInitSegmentWriter``
- ``CMAFMediaSegmentWriter``
