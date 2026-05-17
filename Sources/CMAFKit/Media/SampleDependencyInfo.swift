// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleDependencyInfo
//
// Reference: ISO/IEC 14496-12 §8.5.2.2 (sdtp — sample dependency type box).

import Foundation

/// Sample dependency information per ISO/IEC 14496-12 §8.5.2.2 (`sdtp`).
public struct SampleDependencyInfo: Sendable, Hashable {
    /// How this sample depends on previously decoded samples.
    public let dependsOn: DependencyClass

    /// Whether other samples depend on this one.
    public let isDependedOn: DependencyClass

    /// Whether this sample contains redundant coding.
    public let hasRedundancy: DependencyClass

    /// Two-bit dependency classification per ISO/IEC 14496-12 §8.5.2.2.
    public enum DependencyClass: UInt8, Sendable, Hashable {
        /// Information not known.
        case unknown = 0
        /// Yes.
        case yes = 1
        /// No.
        case no = 2
        /// Reserved by the spec.
        case reserved = 3
    }

    public init(
        dependsOn: DependencyClass,
        isDependedOn: DependencyClass,
        hasRedundancy: DependencyClass
    ) {
        self.dependsOn = dependsOn
        self.isDependedOn = isDependedOn
        self.hasRedundancy = hasRedundancy
    }
}
