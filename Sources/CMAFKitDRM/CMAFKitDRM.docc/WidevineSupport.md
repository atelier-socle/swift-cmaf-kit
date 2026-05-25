# Widevine support

Typed `WidevineCencHeader` Protocol Buffer decoding for the
Google Widevine DRM system identifier.

## Overview

The Widevine system identifier
`edef8ba9-79d6-4ace-a3c8-27dcd51d21ed` carries a Protocol Buffer
proto2 message named `WidevineCencHeader` per Google's public
"Widevine DRM Architecture Overview" documentation.

CMAFKitDRM parses the message with a hand-written zero-
dependency wire-format reader (``ProtocolBufferReader`` /
``ProtocolBufferWriter``) so the DRM target carries no
external Swift package dependency.

## Field map

| # | Name | Type | CMAFKitDRM property |
|---|---|---|---|
| 1 | `algorithm` | enum (UNENCRYPTED / AESCTR) | ``WidevineInitData/algorithm`` |
| 2 | `key_id` | repeated bytes (16 each) | ``WidevineInitData/keyIDs`` |
| 3 | `provider` | string | ``WidevineInitData/provider`` |
| 4 | `content_id` | bytes | ``WidevineInitData/contentID`` |
| 5 | `track_type` | string (deprecated) | ``WidevineInitData/trackType`` |
| 6 | `policy` | string | ``WidevineInitData/policy`` |
| 7 | `crypto_period_index` | uint32 | ``WidevineInitData/cryptoPeriodIndex`` |
| 8 | `grouped_license` | bytes | ``WidevineInitData/groupedLicense`` |
| 9 | `protection_scheme` | uint32 (FourCC BE) | ``WidevineInitData/protectionScheme`` + ``WidevineInitData/protectionSchemeRaw`` |
| 10 | `crypto_period_seconds` | uint32 | ``WidevineInitData/cryptoPeriodSeconds`` |

## Canonical encoding

CMAFKitDRM emits fields in ascending field-number order. Any
``WidevineInitData`` value produced by ``WidevineInitData/parse(_:)``
followed by ``WidevineInitData/encode(_:)`` round-trips byte-
perfectly. In-the-wild inputs that use a different field order
parse correctly and re-encode to canonical order (Protocol
Buffer wire-format permits any field order; semantic
equivalence is the spec-defined invariant).

## Example

```swift
import CMAFKitDRM

let parsed = try WidevineInitData.parse(psshDataBytes)
print("KIDs:", parsed.keyIDs.count)
print("Provider:", parsed.provider ?? "(none)")
print("Scheme:", parsed.protectionScheme?.fourCC.description ?? "(unknown)")
```

## Basic round-trip

A minimal value with one key identifier round-trips byte-perfectly:

```swift
import Foundation
import CMAFKitDRM

let kid = Data(repeating: 0xAA, count: 16)
let original = WidevineInitData(keyIDs: [kid])
let encoded = try WidevineInitData.encode(original)
let parsed = try WidevineInitData.parse(encoded)
// parsed == original
```

## Permissive parsing

Empty input parses as all-nil optionals plus an empty `keyIDs`
array — useful for tolerating real-world malformed-but-empty
payloads:

```swift
import Foundation
import CMAFKitDRM

let parsed = try WidevineInitData.parse(Data())
// parsed.algorithm == nil
// parsed.keyIDs.isEmpty
// parsed.provider == nil
// parsed.contentID == nil
// parsed.policy == nil
```

## Full-field construction

Every public field has a typed setter on the initialiser. A full
value with algorithm, two KIDs, provider, content identifier,
policy, crypto-period index, grouped license, protection scheme,
and crypto-period seconds:

```swift
import Foundation
import CMAFKitDRM

let kid1 = Data(repeating: 0xAA, count: 16)
let kid2 = Data(repeating: 0xBB, count: 16)
let full = WidevineInitData(
    algorithm: .aesCTR,
    keyIDs: [kid1, kid2],
    provider: "test-provider",
    contentID: Data([0x01, 0x02, 0x03]),
    trackType: "VIDEO",
    policy: "policy-x",
    cryptoPeriodIndex: 5,
    groupedLicense: Data([0x99]),
    protectionScheme: .cenc,
    cryptoPeriodSeconds: 60
)
let encoded = try WidevineInitData.encode(full)
let parsed = try WidevineInitData.parse(encoded)
// parsed == full — every field preserved
```

## Edge-case error path

Malformed Protocol Buffer bytes throw a typed ``DRMSystemError``.
For example, a `key_id` field declared with a length less than the
mandatory 16 bytes per ISO/IEC 23001-7 §8.2:

```swift
import Foundation
import CMAFKitDRM

// Tag 0x12 = field 2 (key_id) with wire type 2; declared length 4
// is below the 16-byte UUID requirement.
let malformed = Data([0x12, 0x04, 0xAA, 0xBB, 0xCC, 0xDD])
do {
    _ = try WidevineInitData.parse(malformed)
} catch let error as DRMSystemError {
    // surfaces a structural-error case
    _ = error
}
```

## Key-rotation `cryptoPeriodIndex`

The `cryptoPeriodIndex` field (proto field 7) lets the license
server identify which crypto period the init data belongs to —
useful for keys that rotate periodically without renegotiating
the license:

```swift
import CMAFKitDRM

let original = WidevineInitData(cryptoPeriodIndex: 12345)
let encoded = try WidevineInitData.encode(original)
let parsed = try WidevineInitData.parse(encoded)
// parsed.cryptoPeriodIndex == 12345
```

## See also

- ``WidevineInitData``
- ``ProtocolBufferReader``
- ``ProtocolBufferWriter``
