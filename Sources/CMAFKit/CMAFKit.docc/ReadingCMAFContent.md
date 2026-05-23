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

## Topics

### Init segment

Pass the init segment bytes to
``CMAFInitSegmentReader/init(bytes:)``. The reader walks the
`moov` tree, dispatches every sample entry through its typed
resolver (per codec), and surfaces a list of
``CMAFTrackConfiguration`` values via
``CMAFInitSegmentReader/tracks()``.

### Media segments

Instantiate
``CMAFMediaSegmentReader/init(initSegmentConfiguration:movieTimescale:trackEncryptionContexts:)``
with the track list recovered from the init reader, plus a
`[trackID: TrackEncryptionBox]` map when any track is
encrypted. Each call to
``CMAFMediaSegmentReader/appendSegmentBytes(_:)`` returns a
``ParsedMediaSegment`` carrying the segment's samples,
`mfhd.sequence_number` list, per-track
`tfdt.baseMediaDecodeTime`, any `sidx` / `prft` / `emsg`
metadata, and a `firstSampleIsSyncSample` flag.

Call ``CMAFMediaSegmentReader/finalize()`` to close the actor;
subsequent mutating calls throw.

### Encryption metadata

When the init segment declared an encrypted track and the
reader was instantiated with the corresponding `tenc` context,
each ``CMAFParsedSample`` carries an
``CMAFSampleInput/EncryptionMetadata`` value with the per-sample
IV and optional subsample partitions resolved from the segment's
`senc` box.

### Closed captions

In-band CEA-608 / CEA-708 closed-caption payloads are
extracted via the SEI dispatch path; see <doc:ClosedCaptions>.

## See also

- <doc:WritingCMAFContent>
- <doc:ConformanceValidators>
- ``CMAFInitSegmentReader``
- ``CMAFMediaSegmentReader``
