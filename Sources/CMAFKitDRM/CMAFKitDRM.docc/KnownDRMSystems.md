# Known DRM systems

The nine DRM systems CMAFKitDRM recognises, their canonical
UUIDs, and their public-spec status.

## Overview

The Common Encryption protection scheme info box (`sinf`)
identifies a DRM system by a 16-byte UUID assigned by the
DASH-IF "DRM System Identifiers" registry. CMAFKitDRM defines
the nine registered systems as a typed Swift enum
(``KnownDRMSystemID``) and dispatches each to its typed init-
data parser. Unrecognised UUIDs surface via
``KnownDRMSystemID/other(_:)``.

## The nine systems

| System | UUID | Wire format status |
|---|---|---|
| Widevine | `edef8ba9-79d6-4ace-a3c8-27dcd51d21ed` | Public — Protocol Buffer |
| PlayReady | `9a04f079-9840-4286-ab92-e65be0885f95` | Public — PRO + WRMHEADER XML |
| FairPlay Streaming | `94ce86fb-07ff-4f43-adb8-93d2fa968ca2` | Public — Modular DRM binary |
| W3C ClearKey | `1077efec-c0b2-4d02-ace3-3c1e52e2fb4b` | Public — JSON |
| Marlin | `5e629af5-38da-4063-8977-97ffbd9902d4` | Partial public — BBA URN |
| Nagra Connect | `adb41c24-2dbf-4a6d-958b-4457c0d27b95` | Closed |
| Verimatrix Multi-DRM | `9a27dd82-fde2-4725-8cbc-4234aa06ec09` | Closed |
| Adobe Primetime | `f239e769-efa3-4850-9c16-a903c6932efb` | Deprecated service (2020) |
| China DRM | `3d5e6d35-9b9a-41e8-b843-dd3c6e72c42c` | Public — GY/T 277.2 |

## UUID round-trip across the nine cases

``KnownDRMSystemID/init(uuid:)`` maps each registered UUID back to
its named case; ``KnownDRMSystemID/uuid`` reverses the mapping.
Round-trip holds for every entry in ``KnownDRMSystemID/allKnownCases``:

```swift
import CMAFKitDRM

for known in KnownDRMSystemID.allKnownCases {
    let recovered = KnownDRMSystemID(uuid: known.uuid)
    // recovered == known
    _ = recovered
}
```

## Forward-compat — `.other(UUID)`

Any UUID that isn't one of the nine published systems falls into
``KnownDRMSystemID/other(_:)`` carrying the original UUID. The
calling code can still inspect, log, or forward the system ID:

```swift
import CMAFKitDRM
import Foundation

let novel = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
let lifted = KnownDRMSystemID(uuid: novel)
if case let .other(uuid) = lifted {
    // uuid == novel
    _ = uuid
}
```

## Round-trip semantics

For each system:

- **Public spec, full typing**: parse + encode is byte-perfect
  for canonical inputs; semantically equivalent for inputs that
  use a non-canonical serialisation (Widevine field order;
  PlayReady XML whitespace).
- **Partial public spec**: typed fields are exact; the
  operator-specific tail is preserved as `innerPayload: Data`.
- **Closed spec / deprecated service**: parse + encode is
  byte-perfect via opaque wrapper. Typed fields are not
  attempted because no public specification exists to validate
  against.

## See also

- ``KnownDRMSystemID``
- ``TypedDRMInitData``
- <doc:ClosedSpecProviders>
