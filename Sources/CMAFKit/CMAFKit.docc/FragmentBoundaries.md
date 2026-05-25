# Fragment boundaries

Control when `CMAFMediaSegmentWriter` emits a fragment segment
and how LL-HLS partial chunks subdivide it.

## Overview

Per ISO/IEC 23000-19 §7.3, every CMAF media segment contains one
or more fragments; each fragment is a `moof` + `mdat` pair
carrying a run of samples. CMAFKit lets the caller choose where
fragment boundaries fall via the ``CMAFFragmentBoundary``
enumeration, and optionally where partial chunks land inside
each fragment via ``CMAFPartialChunkBoundary``.

## Fragment boundary cases

- ``CMAFFragmentBoundary/sampleCount(_:)`` — emit a fragment
  after every N samples.
- ``CMAFFragmentBoundary/durationSeconds(_:)`` — emit a
  fragment when the accumulated sample duration reaches the
  threshold.
- ``CMAFFragmentBoundary/onSyncSample`` — emit a fragment at
  every sync sample (typical for live AVC / HEVC with periodic
  IDR / CRA).
- ``CMAFFragmentBoundary/custom(_:)`` — predicate-driven
  boundary for custom segmenter policies.

## Partial chunk boundary cases

- ``CMAFPartialChunkBoundary/sampleCount(_:)`` — partial chunk
  every N samples.
- ``CMAFPartialChunkBoundary/durationSeconds(_:)`` — partial
  chunk every duration threshold (the LL-HLS PART-TARGET).

## SAP enforcement

The writer enforces ISO/IEC 23000-19 §7.3.5.1 — every video
fragment must begin at a Stream Access Point. If a non-sync
video sample arrives at a fragment-start position, the writer
throws a ``CMAFWriterError/cmafConformanceViolation(rule:)`` so
the bug is caught at the source.

## Emitting a single fragment

Configuring ``CMAFMediaSegmentWriter`` with a sample-count boundary
and appending samples until the boundary fires:

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

The writer accumulates samples until the boundary fires, then emits
a single ``CMAFFragmentSegment`` carrying the `moof` + `mdat` pair
and a 1-based `mfhd.sequence_number`.

## Multiple fragments per segment

Repeatedly crossing the boundary produces multiple
``CMAFFragmentSegment`` values, each with a monotonically increasing
``CMAFFragmentSegment/sequenceNumber``:

```swift
import CMAFKit

let writer = try CMAFMediaSegmentWriter(
    configuration: videoConfig,
    fragmentBoundary: .sampleCount(2)
)
var emitted: [CMAFFragmentSegment] = []
for _ in 0..<6 {
    emitted += try await writer.appendSample(sample, toTrack: 1)
}
// emitted.map { $0.sequenceNumber } == [1, 2, 3]
```

## Inspecting `moof` and `trun` after the fact

The fragment header carries the global sequence number; the track
run table carries the per-sample timing / size / flags:

```swift
import CMAFKit

let mfhd = MovieFragmentHeaderBox(sequenceNumber: 1)
// mfhd.sequenceNumber == 1
```

`trun` aggregates per-sample timing through ``TrackRunTable`` with
the four standard per-sample flags. Building a 2-sample run with
duration + size + flags + composition-time-offset:

```swift
import CMAFKit

let entries = [
    TrackRunEntry(
        sampleDuration: 1024,
        sampleSize: 100,
        sampleFlags: 0x0100_0000,
        sampleCompositionTimeOffset: 256
    ),
    TrackRunEntry(
        sampleDuration: 1024,
        sampleSize: 110,
        sampleFlags: 0x0101_0000,
        sampleCompositionTimeOffset: -512
    )
]
let perSampleFlags = TrackRunTable.flagSampleDuration
    | TrackRunTable.flagSampleSize
    | TrackRunTable.flagSampleFlags
    | TrackRunTable.flagSampleCompositionTimeOffsets
let table = TrackRunTable(
    entries: entries,
    perSampleFlags: perSampleFlags,
    version: 1
)
let trun = TrackRunBox(table: table)
```

The negative `sampleCompositionTimeOffset` requires `version: 1` —
version 0 only encodes unsigned offsets.

## See also

- ``CMAFFragmentBoundary``
- ``CMAFPartialChunkBoundary``
- ``CMAFMediaSegmentWriter``
- <doc:WritingCMAFContent>
