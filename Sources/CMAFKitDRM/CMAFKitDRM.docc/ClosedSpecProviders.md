# Closed-spec & secondary providers

Typed treatment for Marlin (partial public spec) and ChinaDRM
(GY/T 277.2 public spec); opaque-wrapper treatment for Nagra,
Verimatrix, and Adobe Primetime — the three systems whose
`pssh.data` wire format is not publicly documented.

## Overview

The DASH-IF "DRM System Identifiers" registry assigns UUIDs for
nine production DRM systems. Four are fully typed by CMAFKitDRM
(Widevine, PlayReady, FairPlay, ClearKey — see their dedicated
articles). The remaining five are documented here:

- **Marlin** — partially public; CMAFKitDRM types the Broadband
  Asset Identifier (BBA URN) portion via
  ``MarlinInitData/BroadbandAssetIdentifier``.
- **ChinaDRM** — fully public (GY/T 277.2); CMAFKitDRM types the
  KIDs list and preserves the operator-specific tail as an
  opaque `innerPayload: Data`.
- **Nagra Connect**, **Verimatrix Multi-DRM**, **Adobe Primetime**
  — closed-spec / deprecated-service. CMAFKitDRM ships these as
  opaque wrappers (``NagraInitData``, ``VerimatrixInitData``,
  ``AdobePrimetimeInitData``) with a public `rawBytes: Data`
  carrying the original `pssh.data` bytes verbatim. The static
  `parse(_:)` entry point constructs the wrapper without
  attempting to decode the payload; the static `encode(_:)`
  entry point returns the preserved bytes unchanged. Round-trip
  is byte-perfect on arbitrary input.

This is not a limitation that CMAFKitDRM will overcome in a
future release of the same library — it is an honest reflection
of the public-spec ecosystem. If and when these vendors
publish their wire format, those wrappers can be expanded with
typed accessors without breaking source compatibility
(`rawBytes` remains available as the canonical wire form).

## Why opaque is correct here

The alternative — inventing field names and offsets based on
reverse-engineering — would produce typed values that cannot
be validated against the spec, would diverge from the vendor's
actual behaviour as their format evolves, and would lull
consumers into trusting incorrect decoding. The container
layer of CMAFKit preserves these bytes byte-perfectly without
needing to interpret them; that is enough for archival,
forwarding, and routing.

## Status note per provider

- **Nagra Connect** — wire format proprietary, distributed
  under NDA to certified Nagra licensees.
- **Verimatrix Multi-DRM** — wire format proprietary,
  distributed under commercial agreement.
- **Adobe Primetime** — service discontinued by Adobe in 2020;
  the historical wire format is partially documented in
  archived Adobe specifications but is no longer maintained.

## Marlin BBA URN

``MarlinInitData/BroadbandAssetIdentifier`` exposes the typed
KID + URN pair extracted from the BBA portion of a Marlin
init data. The URN follows the form `urn:marlin:kid:<hex>`:

```swift
import Foundation
import CMAFKitDRM

let kidHex = "0123456789abcdef0123456789abcdef"
let bytes = Data("urn:marlin:kid:\(kidHex)".utf8)
let parsed = try MarlinInitData.parse(bytes)
// parsed.broadbandAssetIdentifier?.urn == "urn:marlin:kid:\(kidHex)"
// parsed.broadbandAssetIdentifier?.kid.count == 16
```

## ChinaDRM kids + inner payload

``ChinaDRMInitData`` carries the typed `kids` array plus the
operator-specific `innerPayload: Data` (preserved verbatim per
GY/T 277.2). Both fields round-trip byte-perfectly:

```swift
import Foundation
import CMAFKitDRM

let kid = Data(repeating: 0x42, count: 16)
let original = ChinaDRMInitData(
    kids: [kid],
    innerPayload: Data([0xCA, 0xFE, 0xBA, 0xBE])
)
let encoded = try ChinaDRMInitData.encode(original)
let parsed = try ChinaDRMInitData.parse(encoded)
// parsed.kids == [kid]
// parsed.innerPayload == Data([0xCA, 0xFE, 0xBA, 0xBE])
```

## Opaque wrapper — canonical pattern

The three opaque wrappers share the identical
`(init(rawBytes:), parse, encode)` shape. Nagra serves as the
canonical example below; **``VerimatrixInitData`` and
``AdobePrimetimeInitData`` share the same surface** — substitute
the type name and the sample is identical:

```swift
import Foundation
import CMAFKitDRM

let bytes = Data([0x00, 0xFF, 0x7F, 0x80, 0x12, 0x34, 0x56, 0x78])
let parsed = try NagraInitData.parse(bytes)
let reencoded = try NagraInitData.encode(parsed)
// reencoded == bytes
```

## Opaque byte-preservation contract

The wrapper guarantees byte-perfect preservation regardless of
the input shape — there is no size cap, no canonicalisation, no
field reordering. The library treats the payload as opaque:

```swift
import Foundation
import CMAFKitDRM

let large = Data(repeating: 0x42, count: 1024)
let parsed = try NagraInitData.parse(large)
// parsed.rawBytes == large
let reencoded = try NagraInitData.encode(parsed)
// reencoded == large
```

## PSSH dispatch to closed-spec providers

The PSSH dispatch routes by `systemID` (UUID) and produces the
typed wrapper without inspecting the payload:

```swift
import Foundation
import CMAFKit
import CMAFKitDRM

let bytes = Data([0xAA, 0xBB, 0xCC, 0xDD])
let pssh = ProtectionSystemSpecificHeaderBox(
    version: 1,
    systemID: KnownDRMSystemID.nagra.uuid,
    keyIdentifiers: [],
    data: bytes
)
let typed = try pssh.typedInitData()
if case let .nagra(value) = typed {
    // value.rawBytes == bytes
    _ = value
}
// try typed.encoded() == bytes
```

The same dispatch shape routes Verimatrix and Adobe Primetime
inputs to their typed wrappers (``TypedDRMInitData/verimatrix(_:)``
and ``TypedDRMInitData/adobePrimetime(_:)``) — substitute the
system identifier:

```swift
import CMAFKitDRM

let verimatrixID = KnownDRMSystemID.verimatrix.uuid
let adobeID = KnownDRMSystemID.adobePrimetime.uuid
// dispatch as above with .verimatrix(_) / .adobePrimetime(_) cases
_ = (verimatrixID, adobeID)
```

## See also

- ``MarlinInitData``
- ``ChinaDRMInitData``
- ``NagraInitData``
- ``VerimatrixInitData``
- ``AdobePrimetimeInitData``
- <doc:KnownDRMSystems>
