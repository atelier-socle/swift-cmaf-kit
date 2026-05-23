# PlayReady support

Typed PRO + WRMHEADER decoding for the Microsoft PlayReady DRM
system identifier across versions 4.0 / 4.1 / 4.2 / 4.3.

## Overview

The PlayReady system identifier
`9a04f079-9840-4286-ab92-e65be0885f95` carries a PlayReady
Object (PRO): a little-endian length-prefixed envelope of one
or more records. CMAFKitDRM decodes:

- the PRO outer structure (`length`, `recordCount`, per-record
  `recordType` / `recordLength` / `recordValue`),
- record type `0x0001` (PlayReady Header XML) — UTF-16 LE
  encoded WRMHEADER document parsed via Foundation `XMLParser`
  (or `FoundationXML` on Linux),
- record type `0x0003` (Embedded License Store) — preserved
  verbatim,
- any other record type — preserved as
  ``PlayReadyInitData/Record/other(recordType:value:)``.

## WRMHEADER version coverage

| Version | Single KID | Multiple KIDs | DECRYPTORSETUP | Notes |
|---|---|---|---|---|
| 4.0 | ✓ (text content) | — | — | First public version |
| 4.1 | ✓ (`VALUE` attribute) | ✓ (`<KIDS>` element) | — | KIDS introduced |
| 4.2 | ✓ | ✓ | ✓ | Offline + persistent licence hints |
| 4.3 | ✓ | ✓ | ✓ | Latest documented version |

Optional WRMHEADER children covered:

- `KID` (4.0) or `KIDS` (4.1+) carrying one or more KIDs
- `CHECKSUM` (document-level)
- `LA_URL` (License Acquisition URL)
- `LUI_URL` (License UI URL)
- `DS_ID` (Domain Service ID)
- `CUSTOMATTRIBUTES` (verbatim XML preserved as a string)
- `DECRYPTORSETUP` (4.2+)

## Canonical encoding

CMAFKitDRM emits WRMHEADER children in a deterministic order
(KID/KIDS, then CHECKSUM, then LA_URL / LUI_URL, then DS_ID,
then CUSTOMATTRIBUTES, then DECRYPTORSETUP) with sorted
attribute order. This yields byte-perfect round-trip for
values CMAFKitDRM produces; in-the-wild inputs with a
different child order re-encode to canonical form (semantic
equivalence retained).

## Example

```swift
import CMAFKitDRM

let parsed = try PlayReadyInitData.parse(psshDataBytes)
for record in parsed.records {
    if case let .wrmHeader(header) = record {
        print("version:", header.version.rawValue)
        print("KIDs:", header.kids.count)
        print("LA_URL:", header.licenseAcquisitionURL?.absoluteString ?? "(none)")
    }
}
```

## See also

- ``PlayReadyInitData``
- ``PlayReadyInitData/WRMHeader``
- ``PlayReadyInitData/WRMHeader/Version``
