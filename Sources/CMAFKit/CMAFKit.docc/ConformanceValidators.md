# Conformance validators

Verify CMAF, DASH, and LL-HLS conformance for parsed init and
media segments.

## Overview

CMAFKit ships three typed validators that consume the typed
``ParsedInitSegment`` + ``ParsedMediaSegment`` values produced
by the reader and surface a ``CMAFValidationReport`` listing
every conformance violation.

The validators are stateless structs (`Sendable`); each `validate`
call produces a fresh report. Issues carry a severity, the rule
reference (a string like `"ISO/IEC 23000-19 §7.3.5.1"`), a
description, an optional track ID, and an optional segment
index.

## CMAFConformanceValidator

Implements ISO/IEC 23000-19 §7 conformance rules:

| Rule | Reference | Severity |
|---|---|---|
| First sample of every fragment is a Stream Access Point | §7.3.5.1 | error |
| All samples in a fragment share `tfhd.trackID` | §7.4.2 | info |
| Every media-segment track ID is declared by the init segment | §7.3.5.2 | error |
| Encrypted-track samples carry `senc` metadata | ISO/IEC 23001-7 §7.2 | error |
| Per-sample IV length matches `tenc.defaultPerSampleIVSize` | ISO/IEC 23001-7 §8.2 | error |
| `ftyp.compatible_brands` contains the mandatory `iso6` + `cmfc` brands | §6 | error |
| `mfhd.sequence_number` monotonically increases | §7.4.1 | error |
| `tfdt.baseMediaDecodeTime` monotonically advances per track | ISO/IEC 14496-12 §8.8.13 | error |

## DASHConformanceValidator

Implements ISO/IEC 23009-1 §6.3 conformance rules including
`sidx` presence, `prft` NTP signalling, `emsg` timescale
alignment, segment-duration consistency, and timescale
recommendations.

## LLHLSConformanceValidator

Implements IETF RFC 8216bis-15 §B partial-chunk rules
including first-sample-sync iff INDEPENDENT, mfhd sequence
uniqueness, PART-TARGET duration enforcement, and per-fragment
tfdt monotonicity.

## See also

- ``CMAFValidationReport``
- ``CMAFValidationIssue``
- ``ParsedInitSegment``
- ``ParsedMediaSegment``
