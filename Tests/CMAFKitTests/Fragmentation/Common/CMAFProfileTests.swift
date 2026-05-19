// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFProfile")
struct CMAFProfileTests {

    @Test
    func majorBrandsMatchStandard() {
        #expect(CMAFProfile.basic.majorBrand == "cmfc")
        #expect(CMAFProfile.multiStream.majorBrand == "cmf2")
        #expect(CMAFProfile.fragmented.majorBrand == "cmff")
        #expect(CMAFProfile.lowLatency.majorBrand == "cmfl")
        #expect(CMAFProfile.segmented.majorBrand == "cmfs")
        #expect(CMAFProfile.dash.majorBrand == "cmfd")
        #expect(CMAFProfile.hls.majorBrand == "cmfh")
    }

    @Test
    func compatibleBrandsAlwaysIncludeIso6AndCmfc() {
        for profile in CMAFProfile.allCases {
            #expect(profile.compatibleBrands.contains("iso6"))
            #expect(profile.compatibleBrands.contains("cmfc"))
        }
    }

    @Test
    func dashProfileAddsDashCompatibleBrands() {
        let brands = CMAFProfile.dash.compatibleBrands
        #expect(brands.contains("dash"))
        #expect(brands.contains("msdh"))
        #expect(brands.contains("cmfd"))
    }

    @Test
    func hlsProfileAddsCmfhBrand() {
        #expect(CMAFProfile.hls.compatibleBrands.contains("cmfh"))
    }

    @Test
    func codableRoundTrip() throws {
        for profile in CMAFProfile.allCases {
            let encoded = try JSONEncoder().encode(profile)
            let decoded = try JSONDecoder().decode(CMAFProfile.self, from: encoded)
            #expect(decoded == profile)
        }
    }

    @Test
    func equalityAcrossInstances() {
        #expect(CMAFProfile.basic == CMAFProfile.basic)
        #expect(CMAFProfile.basic != CMAFProfile.fragmented)
    }
}
