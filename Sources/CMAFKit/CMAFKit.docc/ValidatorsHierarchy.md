# Validators hierarchy

The five typed conformance validators shipped by CMAFKit, their
relationship, and when to compose them.

## Overview

CMAFKit ships five conformance validators that consume parsed media
and produce typed, non-throwing reports listing every violation
observed. Two abstraction layers are intentional:

- The **parsed-segment layer** consumes ``ParsedInitSegment`` +
  ``ParsedMediaSegment`` produced by the reader. The 0.1.0 surface
  lives here: ``CMAFConformanceValidator``, ``DASHConformanceValidator``,
  ``LLHLSConformanceValidator``.
- The **box-array layer** consumes the raw `[any ISOBox]` top-level
  box list. The 0.1.1 surface lives here:
  ``ISOConformanceValidator``, ``CENCConformanceValidator``. Suited
  for callers that don't (yet) parse to the high-level CMAF
  representation — HLSKit init segments, MOV captures, CMAFKitDRM
  provider tests.

The two layers coexist; ``CMAFConformanceValidator/isoValidator`` and
``CMAFConformanceValidator/cencValidator`` expose the box-array
validators as composition accessors for convenience.

## Parsed-segment layer (0.1.0)

### ``CMAFConformanceValidator``

Implements ISO/IEC 23000-19 §7 conformance rules — see
<doc:ConformanceValidators> for the rule table. Operates on the
``ParsedInitSegment`` + `[`` ``ParsedMediaSegment`` `]` produced by
``CMAFInitSegmentReader`` + ``CMAFMediaSegmentReader``.

### ``DASHConformanceValidator``

Implements ISO/IEC 23009-1 §6.3 DASH ISO BMFF profile rules
including `sidx` presence, `prft` NTP signalling, `emsg` timescale
alignment, segment-duration consistency, and timescale
recommendations.

### ``LLHLSConformanceValidator``

Implements IETF RFC 8216bis-15 §B Low-Latency HLS partial-chunk
rules — first-sample-sync iff INDEPENDENT, mfhd sequence
uniqueness, PART-TARGET duration enforcement, per-fragment tfdt
monotonicity.

All three emit ``CMAFValidationIssue`` instances aggregated in a
``CMAFValidationReport``.

## Box-array layer (0.1.1)

### ``ISOConformanceValidator``

Generic ISO Base Media File Format conformance validator per
ISO/IEC 14496-12 §4-§8. Eight spec-anchored rules (I1-I8):

| Rule | Reference | Severity |
|---|---|---|
| I1 — `ftyp` present and first | §4.3 | error / warning |
| I2 — `moov` unique | §8.2 | error |
| I3 — track IDs unique within `moov` | §8.3.3 | error |
| I4 — `mdhd.timescale` > 0 | §8.4.2 | error |
| I5 — `tkhd` present + non-zero `track_ID` | §8.3.2 | error |
| I6 — `mdat` declared size bounded by file | §8.1.1 | error |
| I7 — `dref` data references resolvable | §8.7.2 | error |
| I8 — container box parent/child structure | §8 | error |

Three entry points: ``ISOConformanceValidator/validate(rootBoxes:)``,
``ISOConformanceValidator/validate(data:)``,
``ISOConformanceValidator/validate(fileURL:)``. Two modes:
``ISOConformanceLevel/strict`` (every SHOULD violation reported as
warning) and ``ISOConformanceLevel/permissive`` (errors only — matches
real-world player tolerance).

Findings are ``ISOConformanceIssue`` aggregated in an
``ISOConformanceReport``.

Validating a minimal CMAF-shaped `ftyp` against the box-array
overload:

```swift
import CMAFKit

let ftyp = FileTypeBox(
    majorBrand: "cmfc",
    minorVersion: 0,
    compatibleBrands: ["iso6", "cmfc"]
)
let validator = ISOConformanceValidator()
let report = validator.validate(rootBoxes: [ftyp])
// report.issues(for: .I1_FileTypePresent).isEmpty == true
```

Picking up the same input from raw bytes or a file uses the async
overloads — both round-trip through the default ``BoxRegistry``
parser:

```swift
import Foundation
import CMAFKit

let data: Data = ...  // an init segment loaded from disk or HTTP
let dataReport = try await ISOConformanceValidator().validate(data: data)

let fileURL: URL = URL(fileURLWithPath: "/tmp/init.mp4")
let fileReport = try await ISOConformanceValidator().validate(fileURL: fileURL)
```

### Report inspection

``ISOConformanceReport/isConformant`` returns `true` iff no issue
carries the ``ISOConformanceIssue/Severity/error`` severity; SHOULD
violations are recorded as warnings and do not flip the flag.
``ISOConformanceReport/issues(of:)`` filters by severity;
``ISOConformanceReport/issues(for:)`` filters by typed rule:

```swift
import CMAFKit

let report = ISOConformanceValidator().validate(rootBoxes: [])
let errors = report.issues(of: .error)
let i1Issues = report.issues(for: .I1_FileTypePresent)
// errors.contains where .rule == .I1_FileTypePresent
// !report.isConformant
```

### Per-rule check

Every rule is queryable individually — useful when emitting
per-section diagnostics or scoring partial conformance. Triggering
the I1 rule by passing an empty box list (no `ftyp`):

```swift
import CMAFKit

let report = ISOConformanceValidator().validate(rootBoxes: [])
let i1 = report.issues(for: .I1_FileTypePresent)
// i1.contains { $0.severity == .error }
```

### ``CENCConformanceValidator``

Generic Common Encryption conformance validator per ISO/IEC 23001-7
§4. Eight spec-anchored rules (C1-C8):

| Rule | Reference | Severity |
|---|---|---|
| C1 — `enca`/`encv`/`enct` → `sinf` | §4.5.1 | error |
| C2 — `sinf` → `frma` with valid original format | §4.5.2 | error |
| C3 — `sinf` → `schm` with scheme ∈ {cenc/cbc1/cens/cbcs} | §4.5.3 | error |
| C4 — `schi` → well-formed `tenc` | §4.5.4 | error |
| C5 — `tenc.default_KID` is 16 bytes | §4.6 | error |
| C6 — `pssh` well-formed (v1 has non-empty KID list) | §4.7 | error |
| C7 — `senc` / `saiz` / `saio` coherence | §4.8 + §4.9 | error |
| C8 — per-sample IV length matches `tenc.default_Per_Sample_IV_Size` | §4.6 + §4.8 | error |

Plus the ``CENCConformanceValidator/detectsCENCProtection(in:)``
helper to short-circuit clear (non-DRM) files.

Short-circuiting unencrypted inputs before running the full CENC
rule pipeline:

```swift
import CMAFKit

let rootBoxes: [any ISOBox] = ...  // parsed top-level boxes
let cencValidator = CENCConformanceValidator()

guard cencValidator.detectsCENCProtection(in: rootBoxes) else {
    // Clear content — no CENC rules apply.
    return
}
let report = cencValidator.validate(rootBoxes: rootBoxes)
```

Querying specific CENC rules — for example, verifying that every
encrypted sample entry carries its ``ProtectionSchemeInfoBox``
(`sinf`) per C1 / C3 / C4:

```swift
import CMAFKit

let report = CENCConformanceValidator().validate(rootBoxes: rootBoxes)
let c1 = report.issues(for: .C1_EncryptedSampleEntryHasSinf)
let c3 = report.issues(for: .C3_SinfHasValidSchm)
let c4 = report.issues(for: .C4_SchiHasTenc)
// Each list is empty on a conformant input.
```

## Composition

``CMAFConformanceValidator/isoValidator`` and
``CMAFConformanceValidator/cencValidator`` are additive accessors
shipped in 0.1.1 — the existing CMAF validator's parsed-segment
logic is unchanged. Callers needing standalone box-array validation
(HLSKit init-segment structural check, CMAFKitDRM provider
verification) can use the box-array validators directly without
constructing a parsed CMAF presentation.

```swift
import CMAFKit

let cmaf = CMAFConformanceValidator()

// Box-array layer reachable from the CMAF validator:
let isoReport = cmaf.isoValidator.validate(rootBoxes: rootBoxes)
let cencReport = cmaf.cencValidator.validate(rootBoxes: rootBoxes)

// Or instantiate the box-array validators directly — same surface:
let iso = ISOConformanceValidator()
let cenc = CENCConformanceValidator()
```

## Standards covered

- **ISO/IEC 14496-12 §4-§8** — Box structure + mandatory boxes
- **ISO/IEC 23001-7 §4** — Common Encryption File Format
- **ISO/IEC 23001-7 §4.5-§4.9** — `sinf` / `frma` / `schm` / `schi`
  / `tenc` / `pssh` / `senc` / `saiz` / `saio`
- **ISO/IEC 23000-19 §7** — CMAF conformance (parsed-segment layer)
- **ISO/IEC 23009-1 §6.3** — DASH ISO BMFF profile
- **IETF RFC 8216bis-15 §B** — LL-HLS partial-chunk rules

## See also

- <doc:ConformanceValidators>
- <doc:EncryptionSupport>
- ``ISOConformanceValidator``
- ``ISOConformanceReport``
- ``ISOConformanceIssue``
- ``ISOConformanceRule``
- ``ISOConformanceLevel``
- ``CENCConformanceValidator``
- ``CENCConformanceReport``
- ``CENCConformanceIssue``
- ``CENCConformanceRule``
- ``CENCConformanceLevel``
- ``CMAFConformanceValidator``
- ``DASHConformanceValidator``
- ``LLHLSConformanceValidator``
