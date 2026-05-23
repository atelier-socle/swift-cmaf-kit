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

## See also

- ``WidevineInitData``
- ``ProtocolBufferReader``
- ``ProtocolBufferWriter``
