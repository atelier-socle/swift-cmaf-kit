# ``CMAFKitDRM``

Typed DRM init-data decoding for the nine publicly-registered
Common Encryption system identifiers, layered on top of
CMAFKit.

## Overview

`CMAFKitDRM` is an opt-in companion target that lifts the
opaque `pssh.data` bytes carried by ``CMAFKit/ProtectionSystemSpecificHeaderBox``
into provider-specific typed shapes. Four of the nine providers
publish a wire-format specification that CMAFKitDRM parses
fully (Widevine, PlayReady, FairPlay, ClearKey); the fifth
(Marlin) is partially documented and CMAFKitDRM types the
publicly-known portion (BBA URN); the remaining three
providers without a public specification (Nagra, Verimatrix,
Adobe Primetime) ship as byte-perfect opaque wrappers with the
closed-spec / deprecated-service status documented in the
file header of each type.

CMAFKitDRM never handles decryption keys or content. It only
decodes the typed `pssh.data` shape so consumers can route,
inspect, and forward the init data without losing any field.

## Dispatch

The entry point is ``CMAFKit/ProtectionSystemSpecificHeaderBox``
extended with ``CMAFKit/ProtectionSystemSpecificHeaderBox/typedInitData()``,
which routes on the box's `systemID` (UUID) into one of the typed
``TypedDRMInitData`` cases:

```swift
import CMAFKit
import CMAFKitDRM

let pssh: ProtectionSystemSpecificHeaderBox = ...  // from an init segment
let typed = try pssh.typedInitData()
switch typed {
case .widevine(let value):       // typed Widevine CencHeader
    _ = value.keyIDs
case .playReady(let value):      // typed PlayReady Object records
    _ = value.records
case .fairPlay(let value):       // typed FairPlay init data
    _ = value.keyIDs
case .clearKey(let value):       // typed ClearKey JWK
    _ = value.kids
case .marlin(let value):         // typed Marlin BBA URN
    _ = value.broadbandAssetIdentifier
case .chinaDRM(let value):       // typed ChinaDRM kids + inner payload
    _ = value.kids
case .nagra(let value),
     .verimatrix(let value),
     .adobePrimetime(let value): // opaque byte-perfect wrappers
    _ = value.rawBytes
case .unknown(let systemID, let raw):
    _ = (systemID, raw)
}
```

The same `pssh` byte sequence dispatches identically regardless of
provider — the framework knows the 9 system IDs and routes by UUID.

## Round-trip preservation

Every typed value re-encodes byte-identically to the input
`pssh.data` via ``TypedDRMInitData/encoded()``:

```swift
import CMAFKit
import CMAFKitDRM

let pssh: ProtectionSystemSpecificHeaderBox = ...
let typed = try pssh.typedInitData()
let reEncoded = try typed.encoded()
// reEncoded == pssh.data
```

This holds across all 9 providers — the parsed shape carries
enough information to reproduce the original wire bytes verbatim.
For closed-spec providers (Nagra, Verimatrix, AdobePrimetime) the
guarantee is mechanical (the typed value stores the raw bytes); for
typed providers it follows from the round-trip tests in the suite.

## Internals exposed for extensibility

The CencHeader Protocol Buffer wire format used by Widevine is
decoded and encoded by ``ProtocolBufferReader`` and
``ProtocolBufferWriter`` — minimal zero-dependency utilities
shipped under `Sources/CMAFKitDRM/Common/ProtocolBuffer/`. They are
public so consumers implementing a custom DRM provider
(conforming to ``DRMInitDataParsing``) can decode or emit
protocol-buffer-shaped init data without adding a third-party
dependency. The API surface is deliberately minimal — for full
Protocol Buffer compliance (`oneof`, `repeated`, embedded messages
with schema validation, JSON serialisation), adopt
[swift-protobuf](https://github.com/apple/swift-protobuf) directly.

## Topics

### Getting started

- <doc:GettingStartedWithDRM>
- <doc:KnownDRMSystems>

### Major providers (fully typed)

- ``WidevineInitData``
- ``PlayReadyInitData``
- ``FairPlayInitData``
- ``ClearKeyInitData``
- <doc:WidevineSupport>
- <doc:PlayReadySupport>
- <doc:FairPlayAndClearKey>

### Secondary providers

- ``MarlinInitData``
- ``ChinaDRMInitData``
- ``NagraInitData``
- ``VerimatrixInitData``
- ``AdobePrimetimeInitData``
- <doc:ClosedSpecProviders>

### Common types

- ``KnownDRMSystemID``
- ``DRMInitDataParsing``
- ``DRMSystemError``
- ``TypedDRMInitData``

### Protocol Buffer utilities

- ``ProtocolBufferReader``
- ``ProtocolBufferWriter``
