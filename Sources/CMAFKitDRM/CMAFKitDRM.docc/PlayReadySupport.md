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

## PRO record parsing

The PRO envelope wraps zero or more records. Each typed record is
preserved through parse + encode; `recordType: 0x0003` (Embedded
License Store) round-trips its opaque payload verbatim:

```swift
import Foundation
import CMAFKitDRM

let parsed = try PlayReadyInitData.parse(psshDataBytes)
for record in parsed.records {
    if case let .embeddedLicenseStore(data) = record {
        // data is the opaque License Store payload, preserved verbatim
        _ = data
    }
}
let reencoded = try PlayReadyInitData.encode(parsed)
// reencoded == psshDataBytes  (canonical)
```

## WRMHeader XML round-trip

A v4.1 WRMHEADER with a single KID round-trips through XML
encoding without losing the KID bytes:

```swift
import Foundation
import CMAFKitDRM

let kid = Data(repeating: 0x42, count: 16)
let header = PlayReadyInitData.WRMHeader(
    version: .v4_1,
    kids: [PlayReadyInitData.WRMHeader.KID(value: kid)]
)
let original = PlayReadyInitData(records: [.wrmHeader(header)])
let encoded = try PlayReadyInitData.encode(original)
let parsed = try PlayReadyInitData.parse(encoded)
// parsed.records.first carries the same .wrmHeader(header)
```

## Typed KID with `ALGID`

KIDs optionally carry an `ALGID` attribute (e.g., `"AESCTR"` or
`"COCKTAIL"`) and a `CHECKSUM`. The typed initializer surfaces
them as ``PlayReadyInitData/WRMHeader/KID/algorithmID`` and
``PlayReadyInitData/WRMHeader/KID/checksum``:

```swift
import Foundation
import CMAFKitDRM

let kid = Data(repeating: 0x42, count: 16)
let header = PlayReadyInitData.WRMHeader(
    version: .v4_1,
    kids: [
        PlayReadyInitData.WRMHeader.KID(
            value: kid,
            algorithmID: "AESCTR"
        )
    ]
)
// header.kids[0].algorithmID == "AESCTR"
```

## WRM XML 4.0 / 4.1 / 4.2 / 4.3 differences

The four versions differ in KID carriage (4.0 single via element
text; 4.1+ via the `KIDS` collection), and 4.2 introduced the
`DECRYPTORSETUP` child for offline / persistent licence hints
(carried forward in 4.3):

```swift
import Foundation
import CMAFKitDRM

let kid = Data(repeating: 0x42, count: 16)

let v40 = PlayReadyInitData.WRMHeader(
    version: .v4_0,
    kids: [PlayReadyInitData.WRMHeader.KID(value: kid)]
)

let v42 = PlayReadyInitData.WRMHeader(
    version: .v4_2,
    kids: [PlayReadyInitData.WRMHeader.KID(value: kid)],
    decryptorSetup: "ONDEMAND"
)
// v40.version != v42.version
// v42.decryptorSetup == "ONDEMAND"
```

## XML edge cases

Special characters in attribute values (e.g., `&` in a license
acquisition URL query string) survive encoding via standard XML
entity escaping. The decoded URL preserves the original string:

```swift
import Foundation
import CMAFKitDRM

let kid = Data(repeating: 0x42, count: 16)
let header = PlayReadyInitData.WRMHeader(
    version: .v4_1,
    kids: [PlayReadyInitData.WRMHeader.KID(value: kid)],
    licenseAcquisitionURL: URL(string: "https://license.example.com/playready?id=A%26B")
)
let original = PlayReadyInitData(records: [.wrmHeader(header)])
let encoded = try PlayReadyInitData.encode(original)
let parsed = try PlayReadyInitData.parse(encoded)
// LA_URL round-trips with the escaped %26 preserved
_ = parsed
```

## See also

- ``PlayReadyInitData``
- ``PlayReadyInitData/WRMHeader``
- ``PlayReadyInitData/WRMHeader/Version``
