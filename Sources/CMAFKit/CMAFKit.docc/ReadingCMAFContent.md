# Reading CMAF content

Decode init and media segments back into typed track
configurations and per-sample structures.

## Overview

CMAFKit's reader surface mirrors the writer:
``CMAFInitSegmentReader`` is a stateless value type that turns
the bytes of an init segment (`ftyp` + `moov`) into a typed
``ParsedInitSegment``. ``CMAFMediaSegmentReader`` is an actor
that ingests media segment bytes (one segment at a time) and
yields typed ``CMAFParsedSample`` instances grouped by track.

The actor maintains per-track cross-segment state (last
`mfhd.sequence_number`, last `tfdt.baseMediaDecodeTime`) so
downstream conformance validators can reason about the entire
file rather than a single segment.

## Reading an init segment

Pass the init segment bytes to
``CMAFInitSegmentReader/init(bytes:)``. The reader walks the
`moov` tree, dispatches every sample entry through its typed
resolver (per codec), and surfaces a list of
``CMAFTrackConfiguration`` values via
``CMAFInitSegmentReader/tracks()``:

```swift
import CMAFKit

let initSegmentBytes: Data = /* loaded from disk or HTTP */
let reader = try await CMAFInitSegmentReader(bytes: initSegmentBytes)
let tracks = reader.tracks()
// tracks[0].trackID, tracks[0].kind (.video / .audio / .subtitle / .metadata)
```

Each ``CMAFTrackConfiguration`` carries the full typed surface
(codec configuration, dimensions / sample rate, language,
accessibility metadata, encryption parameters) ready to feed into a
writer or a downstream consumer.

## Multi-track init segment

Two-track init segments (video + audio is the canonical case) come
back with the same `tracks()` array — the caller filters by
``CMAFTrackKind``:

```swift
import CMAFKit

let reader = try await CMAFInitSegmentReader(bytes: initSegmentBytes)
let tracks = reader.tracks()
let video = tracks.first { $0.kind == .video }
let audio = tracks.first { $0.kind == .audio }
// video?.videoFields, audio?.audioFields are populated per kind
```

## Reading media segments

Instantiate ``CMAFMediaSegmentReader/init(initSegmentConfiguration:movieTimescale:trackEncryptionContexts:)``
with the track list recovered from the init reader, then call
``CMAFMediaSegmentReader/appendSegmentBytes(_:)`` once per segment:

```swift
import CMAFKit

let initReader = try await CMAFInitSegmentReader(bytes: initSegmentBytes)
let tracks = initReader.tracks()
let mediaReader = try CMAFMediaSegmentReader(
    initSegmentConfiguration: tracks,
    movieTimescale: 1000
)
let parsed = try await mediaReader.appendSegmentBytes(mediaSegmentBytes)
// parsed.samples carries the typed CMAFParsedSample list in decode order
```

The actor maintains cross-segment state — call
`appendSegmentBytes(_:)` repeatedly for a fragmented presentation
and the highest `mfhd.sequence_number` plus per-track
`baseMediaDecodeTime` accumulate on
``CMAFMediaSegmentReader/lastSequenceNumber`` and
``CMAFMediaSegmentReader/lastBaseMediaDecodeTimes``.

## Encryption metadata recovery

When the init segment declared an encrypted track, instantiate the
media reader with a `trackID → tenc` map so per-sample IVs and
subsample partitions can be resolved from `senc`:

```swift
import CMAFKit

let tenc: TrackEncryptionBox = /* from the init segment */
let mediaReader = try CMAFMediaSegmentReader(
    initSegmentConfiguration: tracks,
    movieTimescale: 1000,
    trackEncryptionContexts: [1: tenc]
)
let parsed = try await mediaReader.appendSegmentBytes(mediaSegmentBytes)
let firstIV = parsed.samples.first?.encryption?.initializationVector
```

Without the encryption context, encrypted samples come back without
the ``CMAFParsedSample/encryption`` payload — the structural read
still succeeds, but downstream decryption cannot resolve IVs.

## Notes

### `ParsedMediaSegment` payload

``CMAFMediaSegmentReader/appendSegmentBytes(_:)`` returns a
``ParsedMediaSegment`` carrying the segment's samples,
`mfhd.sequence_number` list, per-track
`tfdt.baseMediaDecodeTime`, any `sidx` / `prft` / `emsg`
metadata, and a `firstSampleIsSyncSample` flag.

Call ``CMAFMediaSegmentReader/finalize()`` to close the actor;
subsequent mutating calls throw.

### Closed captions

In-band CEA-608 / CEA-708 closed-caption payloads are
extracted via the SEI dispatch path; see <doc:ClosedCaptions>.

## See also

- <doc:WritingCMAFContent>
- <doc:ConformanceValidators>
- ``CMAFInitSegmentReader``
- ``CMAFMediaSegmentReader``
