# Getting started with CMAFKitDRM

Opt into typed DRM init-data decoding by importing both targets.

## Overview

CMAFKitDRM is delivered as a separate library product of the
same package. Consumers that do not need DRM typing depend on
`CMAFKit` only; consumers that do also import `CMAFKitDRM`.

## Install

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/swift-cmaf-kit.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "CMAFKit", package: "swift-cmaf-kit"),
            .product(name: "CMAFKitDRM", package: "swift-cmaf-kit")
        ]
    )
]
```

## Dispatch a pssh box to its typed init data

```swift
import CMAFKit
import CMAFKitDRM
import Foundation

let reader = try await CMAFInitSegmentReader(bytes: initSegmentBytes)
for pssh in reader.protectionSystemSpecificHeaders() {
    let typed = try pssh.typedInitData()
    switch typed {
    case .widevine(let value):
        print("Widevine: \(value.keyIDs.count) KID(s)")
    case .playReady(let value):
        print("PlayReady: \(value.records.count) record(s)")
    case .fairPlay(let value):
        print("FairPlay: \(value.keyIDs.count) KID(s)")
    case .clearKey(let value):
        print("ClearKey: type=\(value.type.rawValue)")
    default:
        print("Other / unrecognised: \(typed.systemID)")
    }
}
```

## Re-encode for round-trip

```swift
let bytes = try typed.encoded()
```

For the four fully-typed providers, `encoded()` returns
canonical bytes that round-trip byte-perfectly with the
decoder. For the closed-spec wrappers
(``NagraInitData`` / ``VerimatrixInitData`` /
``AdobePrimetimeInitData``), `encoded()` returns the original
bytes verbatim — the container layer is preserved even when the
inner format is closed.

## Error handling

Malformed init data throws a typed ``DRMSystemError`` — useful
for distinguishing structural problems from provider routing
failures. The dispatch never silently swallows errors:

```swift
import CMAFKit
import CMAFKitDRM
import Foundation

let pssh: ProtectionSystemSpecificHeaderBox = ...  // malformed FairPlay
do {
    _ = try pssh.typedInitData()
} catch let error as DRMSystemError {
    // routed to the typed FairPlay parser; surfaced an error
    print("DRM parse failed: \(error)")
}
```

## Forward-compat for unknown system IDs

Any UUID that isn't one of the nine published systems falls
through to ``TypedDRMInitData/unknown(systemID:rawBytes:)`` — the
init data is preserved verbatim, so the calling code can store it,
forward it across the wire, or route it to an external provider
plugin without losing fidelity:

```swift
import CMAFKit
import CMAFKitDRM
import Foundation

let novelSystem = UUID(uuidString: "12345678-9ABC-DEF0-1234-567890ABCDEF")!
let pssh = ProtectionSystemSpecificHeaderBox(
    version: 1,
    systemID: novelSystem,
    keyIdentifiers: [],
    data: Data([0x01, 0x02, 0x03])
)
let typed = try pssh.typedInitData()
if case let .unknown(systemID, rawBytes) = typed {
    // systemID == novelSystem
    // rawBytes == Data([0x01, 0x02, 0x03])
    _ = (systemID, rawBytes)
}
```

## See also

- <doc:KnownDRMSystems>
- <doc:ClosedSpecProviders>
