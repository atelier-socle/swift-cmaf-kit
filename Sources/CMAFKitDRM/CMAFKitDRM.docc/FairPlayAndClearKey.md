# FairPlay & ClearKey support

Typed init-data decoding for Apple FairPlay Streaming Modular
DRM and the W3C EME ClearKey reference scheme.

## FairPlay (Modular DRM)

The Apple FairPlay Streaming system identifier
`94ce86fb-07ff-4f43-adb8-93d2fa968ca2` carries the Modular DRM
init-data binary format per Apple's "Offline FairPlay Streaming
Specification" and "FairPlay Streaming Programming Guide":

```
formatVersion        UInt8         1 byte    (0x01 = version 1)
kidCount             UInt32 BE              (network byte order)
KIDs                 16 * kidCount bytes
```

Classic HLS FairPlay (`EXT-X-KEY METHOD=SAMPLE-AES URI="skd://..."`)
does not carry a pssh box and is therefore out of scope for
``FairPlayInitData``; the typed parser only addresses the CMAF
Modular DRM variant where `pssh.data` is well-defined.

```swift
import CMAFKitDRM

let parsed = try FairPlayInitData.parse(psshDataBytes)
#expect(parsed.formatVersion == 1)
print("KIDs:", parsed.keyIDs.count)
```

## ClearKey

The W3C ClearKey system identifier
`1077efec-c0b2-4d02-ace3-3c1e52e2fb4b` carries a UTF-8 JSON
document per W3C Encrypted Media Extensions §9:

```json
{ "kids": ["base64url-key-id"], "type": "temporary" }
```

CMAFKitDRM decodes the JSON via Foundation `JSONDecoder` and
the base64url-encoded KIDs via the RFC 4648 §5 alphabet (no
padding; `-` for `+`, `_` for `/`).

```swift
import CMAFKitDRM

let parsed = try ClearKeyInitData.parse(psshDataBytes)
print("KIDs:", parsed.kids.count)
print("type:", parsed.type.rawValue)
```

The canonical encoder emits sorted keys without escaped
slashes so re-encoding produces a deterministic byte sequence.

## See also

- ``FairPlayInitData``
- ``ClearKeyInitData``
- ``ClearKeyInitData/KeyType``
