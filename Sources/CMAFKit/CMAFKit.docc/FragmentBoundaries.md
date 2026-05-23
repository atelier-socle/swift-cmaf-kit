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

## See also

- ``CMAFFragmentBoundary``
- ``CMAFPartialChunkBoundary``
- ``CMAFMediaSegmentWriter``
- <doc:WritingCMAFContent>
