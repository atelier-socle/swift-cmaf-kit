// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// CMAFConformanceValidator — Session 7 additive composition
// accessors. Verifies that:
// - `isoValidator` and `cencValidator` are exposed and usable.
// - The two delegated validators can be invoked standalone.
// - The existing `validate(initSegment:mediaSegments:)` signature and
//   observable behaviour are unchanged.

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFConformanceValidator — composition accessors")
struct CMAFConformanceValidatorCompositionTests {

    @Test func exposesISOValidator() {
        let validator = CMAFConformanceValidator()
        // The accessor returns a strict-level instance.
        #expect(validator.isoValidator.level == .strict)
    }

    @Test func exposesCENCValidator() {
        let validator = CMAFConformanceValidator()
        #expect(validator.cencValidator.level == .strict)
    }

    @Test func isoValidatorUsableStandalone() {
        let validator = CMAFConformanceValidator()
        let report = validator.isoValidator.validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(),
                ISOFixtures.makeTrak(trackID: 1)
            ])
        ])
        #expect(report.isConformant)
    }

    @Test func cencValidatorUsableStandalone() {
        let validator = CMAFConformanceValidator()
        let report = validator.cencValidator.validate(
            rootBoxes: CENCFixtures.makeRootBoxes(
                scheme: .cenc, keyIdentifier: CENCFixtures.kid()))
        #expect(report.isConformant)
    }

    @Test func cencValidatorDetectsClearFile() {
        let validator = CMAFConformanceValidator()
        let clear: [any ISOBox] = [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(),
                ISOFixtures.makeTrak(trackID: 1)
            ])
        ]
        #expect(!validator.cencValidator.detectsCENCProtection(in: clear))
    }

    @Test func cencValidatorDetectsEncryptedFile() {
        let validator = CMAFConformanceValidator()
        let encrypted = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid())
        #expect(validator.cencValidator.detectsCENCProtection(in: encrypted))
    }
}
