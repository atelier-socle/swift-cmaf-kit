// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("BrandComposer")
struct BrandComposerTests {

    @Test
    func basicProfileFtyp() {
        let ftyp = BrandComposer.makeFileTypeBox(profile: .basic)
        #expect(ftyp.majorBrand == "cmfc")
        #expect(ftyp.compatibleBrands.contains("iso6"))
        #expect(ftyp.compatibleBrands.contains("cmfc"))
    }

    @Test
    func dashProfileStypIncludesDashBrands() {
        let styp = BrandComposer.makeSegmentTypeBox(profile: .dash)
        #expect(styp.majorBrand == "cmfd")
        #expect(styp.compatibleBrands.contains("dash"))
        #expect(styp.compatibleBrands.contains("msdh"))
    }

    @Test
    func extraCompatibleBrandsAppended() {
        let ftyp = BrandComposer.makeFileTypeBox(
            profile: .lowLatency,
            extraCompatibleBrands: ["hev1"]
        )
        #expect(ftyp.compatibleBrands.contains("hev1"))
        #expect(ftyp.compatibleBrands.contains("cmfl"))
    }

    @Test
    func duplicatesRemovedPreservingOrder() {
        let ftyp = BrandComposer.makeFileTypeBox(
            profile: .basic,
            extraCompatibleBrands: ["iso6", "cmfc", "cmf2"]
        )
        let counts = ftyp.compatibleBrands.reduce(into: [:] as [FourCC: Int]) { acc, b in
            acc[b, default: 0] += 1
        }
        for (_, value) in counts {
            #expect(value == 1)
        }
        #expect(ftyp.compatibleBrands.contains("cmf2"))
    }

    @Test
    func ftypAndStypHaveDistinctBoxTypes() {
        let ftyp = BrandComposer.makeFileTypeBox(profile: .basic)
        let styp = BrandComposer.makeSegmentTypeBox(profile: .basic)
        #expect(FileTypeBox.boxType == "ftyp")
        #expect(SegmentTypeBox.boxType == "styp")
        #expect(ftyp.majorBrand == styp.majorBrand)
    }

    @Test
    func ftypByteForByteRoundTrip() async throws {
        let original = BrandComposer.makeFileTypeBox(profile: .hls)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FileTypeBox)
        #expect(parsed == original)
    }

    @Test
    func stypByteForByteRoundTrip() async throws {
        let original = BrandComposer.makeSegmentTypeBox(profile: .lowLatency)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SegmentTypeBox)
        #expect(parsed == original)
    }
}
