// swift-tools-version:6.2
// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import PackageDescription

let package = Package(
    name: "swift-cmaf-kit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "CMAFKit",
            targets: ["CMAFKit"]
        ),
        .library(
            name: "CMAFKitDRM",
            targets: ["CMAFKitDRM"]
        ),
        .executable(
            name: "cmafkit-cli",
            targets: ["CMAFKitCLI"]
        ),
    ],
    dependencies: [
        // Linux-only crypto backend. Conditional in target deps below.
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            from: "3.0.0"
        ),
        // CLI argument parsing.
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.4.0"
        ),
        // DocC plugin for `swift package generate-documentation`.
        // (Spec omission: project-setup §6 did not list this; required by
        // Scripts/generate-docs.sh and the docc-deploy workflow.)
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin.git",
            from: "1.4.3"
        ),
    ],
    targets: [
        .target(
            name: "CMAFKit",
            dependencies: [
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            path: "Sources/CMAFKit",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .target(
            name: "CMAFKitDRM",
            dependencies: ["CMAFKit"],
            path: "Sources/CMAFKitDRM",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .executableTarget(
            name: "CMAFKitCLI",
            dependencies: [
                "CMAFKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/CMAFKitCLI"
        ),
        .testTarget(
            name: "CMAFKitTests",
            dependencies: ["CMAFKit"],
            path: "Tests/CMAFKitTests",
            resources: [
                // Session 12 will add: .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "CMAFKitDRMTests",
            dependencies: ["CMAFKitDRM", "CMAFKit"],
            path: "Tests/CMAFKitDRMTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
