// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import CMAFKit

@Suite("CMAFKit smoke")
struct CMAFKitSmokeTests {
    @Test
    func versionIsTagged() {
        #expect(CMAFKitVersion == "0.1.0")
    }
}
