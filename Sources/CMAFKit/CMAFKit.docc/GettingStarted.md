# Getting started with CMAFKit

The shortest path from an empty Swift target to a CMAF init
segment on disk.

## Overview

This walkthrough authors an init segment for a single AVC video
track, writes it to a temporary file, reads it back, and prints
the recovered track configuration. Every line compiles against
the public CMAFKit surface.

## Install

Declare CMAFKit as a Swift Package Manager dependency:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/swift-cmaf-kit.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "CMAFKit", package: "swift-cmaf-kit")
        ]
    )
]
```

For DRM init-data typing, add the optional `CMAFKitDRM`
product:

```swift
.product(name: "CMAFKitDRM", package: "swift-cmaf-kit")
```

## Write a minimal init segment

```swift
import CMAFKit
import Foundation

let avcConfig = AVCDecoderConfigurationRecord(
    profileIndication: .baseline,
    profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
    levelIndication: .level3,
    lengthSize: .fourBytes,
    sequenceParameterSets: [AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))],
    pictureParameterSets: [AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))]
)

let track = CMAFTrackConfiguration(
    trackID: 1,
    kind: .video,
    profile: .basic,
    timescale: 90_000,
    language: "und",
    videoFields: CMAFTrackConfiguration.VideoFields(
        width: 1920,
        height: 1080,
        codec: .avc1,
        codecConfiguration: .avc(avcConfig),
        frameRate: .init(numerator: 30, denominator: 1)
    )
)

let initBytes = try CMAFInitSegmentWriter(configurations: [track]).emit()
```

## Read it back

```swift
let reader = try await CMAFInitSegmentReader(bytes: initBytes)
let recovered = reader.tracks()
print("track count:", recovered.count)
print("codec:", recovered[0].videoFields?.codec ?? "(none)")
```

## Next steps

- <doc:WritingCMAFContent> — full writer surface
- <doc:ReadingCMAFContent> — reader actor + parsed samples
- <doc:ConformanceValidators> — CMAF / DASH / LL-HLS rules
- <doc:EncryptionSupport> — Common Encryption schemes
- <doc:Ecosystem> — sibling libraries in Atelier Socle
