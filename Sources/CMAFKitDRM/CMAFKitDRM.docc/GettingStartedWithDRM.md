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

## See also

- <doc:KnownDRMSystems>
- <doc:ClosedSpecProviders>
