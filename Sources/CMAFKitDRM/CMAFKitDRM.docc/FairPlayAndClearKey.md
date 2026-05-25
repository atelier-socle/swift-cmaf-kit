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

### `formatVersion` byte invariant

Every conformant FairPlay Modular init data starts with the byte
`0x01` — ``FairPlayInitData/currentFormatVersion``. The encoder
emits this byte verbatim and the parser rejects any other value:

```swift
import Foundation
import CMAFKitDRM

let kid = Data(repeating: 0xAB, count: 16)
let original = FairPlayInitData(keyIDs: [kid])
let encoded = try FairPlayInitData.encode(original)
// encoded.first == 0x01
// encoded.first == FairPlayInitData.currentFormatVersion
```

### Multi-KID init data

The `kidCount` UInt32 (big-endian) lets a single FairPlay init
data carry multiple KIDs — useful when a track is bound to several
key identifiers (e.g., audio + video sharing a content key):

```swift
import Foundation
import CMAFKitDRM

let kids: [Data] = (0..<4).map { i in
    Data(repeating: 0x10 + UInt8(i), count: 16)
}
let original = FairPlayInitData(keyIDs: kids)
let encoded = try FairPlayInitData.encode(original)
let parsed = try FairPlayInitData.parse(encoded)
// parsed.keyIDs == kids
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

### Temporary vs persistent-license

``ClearKeyInitData/KeyType/temporary`` (the default) signals a
session-scoped key; ``ClearKeyInitData/KeyType/persistentLicense``
signals an offline-license workflow. Both round-trip through the
JSON wire format:

```swift
import Foundation
import CMAFKitDRM

let kid = Data(repeating: 0xAA, count: 16)

let temporary = ClearKeyInitData(kids: [kid], type: .temporary)
let tempBytes = try ClearKeyInitData.encode(temporary)
// tempBytes carries `"type":"temporary"`

let persistent = ClearKeyInitData(kids: [kid], type: .persistentLicense)
let persistBytes = try ClearKeyInitData.encode(persistent)
// persistBytes carries `"type":"persistent-license"`
```

### base64url-encoded KIDs

ClearKey KIDs are carried as base64url-encoded strings inside the
`"kids"` array, per the W3C EME §9 alphabet (RFC 4648 §5 — no
padding, `-` for `+`, `_` for `/`). The decoded bytes are the raw
16-byte UUID. The on-wire JSON for the 16-byte sequence
`AAECAwQFBgcICQoLDA0ODw` decodes to `Data([0x00, 0x01, ..., 0x0F])`:

```swift
import Foundation
import CMAFKitDRM

let payload = Data(
    #"{"kids":["AAECAwQFBgcICQoLDA0ODw"],"type":"temporary"}"#.utf8
)
let parsed = try ClearKeyInitData.parse(payload)
// parsed.kids == [Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
//                       0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F])]
// parsed.type == .temporary
```

## See also

- ``FairPlayInitData``
- ``ClearKeyInitData``
- ``ClearKeyInitData/KeyType``
