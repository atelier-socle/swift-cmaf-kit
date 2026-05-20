// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Regression tests guarding the S9-class bug where a container box
// parser greedily consumes past its declared body and clobbers a
// trailing sibling. Every container audited in the Session 11
// verification report relies on the registry-carved body
// sub-reader for bounding (``ISOBoxReader.dispatchParse`` at
// lines 173-186), or carves its own body sub-reader (sinf,
// schi, dinf, sample-description, etc.). Each test below
// constructs a bytestream of the form
//
//     [container_with_known_children][trailing_sibling]
//
// then parses the bytestream through
// ``ISOBoxReader.readBoxes(from:using:)`` and asserts the trailing
// sibling is recovered intact. If a future change re-introduces
// the bug, the trailing sibling disappears from the parse result
// and the test fails loudly.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Container parser safety — trailing-sibling regressions")
struct ContainerParserSafetyTests {

    // MARK: - sinf (ProtectionSchemeInfoBox)

    @Test
    func sinfDoesNotOverConsumeTrailingSibling() async throws {
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "avc1"),
            schemeType: SchemeTypeBox(schemeType: .cenc),
            schemeInformation: SchemeInformationBox(
                trackEncryption: TrackEncryptionBox(
                    defaultIsProtected: true,
                    defaultPerSampleIVSize: .eight,
                    defaultKID: WriterFixtures.makeKID()
                )
            )
        )
        let sibling = FreeSpaceBox(
            onWireType: "free", payload: Data([0xAA, 0xBB, 0xCC, 0xDD])
        )
        let bytes = Self.encode(boxes: [sinf, sibling])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 2)
        #expect(parsed.first is ProtectionSchemeInfoBox)
        let recoveredSibling = try #require(parsed.last as? FreeSpaceBox)
        #expect(recoveredSibling.payload == Data([0xAA, 0xBB, 0xCC, 0xDD]))
    }

    // MARK: - schi (SchemeInformationBox)

    @Test
    func schiDoesNotOverConsumeTrailingSibling() async throws {
        let schi = SchemeInformationBox(
            trackEncryption: TrackEncryptionBox(
                defaultIsProtected: true,
                defaultPerSampleIVSize: .eight,
                defaultKID: WriterFixtures.makeKID()
            )
        )
        let sibling = FreeSpaceBox(onWireType: "free", payload: Data([0x11]))
        let bytes = Self.encode(boxes: [schi, sibling])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 2)
        #expect(parsed.first is SchemeInformationBox)
        let recoveredSibling = try #require(parsed.last as? FreeSpaceBox)
        #expect(recoveredSibling.payload == Data([0x11]))
    }

    // MARK: - mdia (MediaBox)

    @Test
    func mdiaDoesNotOverConsumeTrailingSibling() async throws {
        let mdia = MediaBox(
            header: Self.placeholderHeader(for: "mdia"),
            children: [Self.makeFreeChild(0xEE)]
        )
        let sibling = FreeSpaceBox(onWireType: "free", payload: Data([0xFA, 0xCE]))
        let bytes = Self.encode(boxes: [mdia, sibling])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 2)
        #expect(parsed.first is MediaBox)
        let recoveredSibling = try #require(parsed.last as? FreeSpaceBox)
        #expect(recoveredSibling.payload == Data([0xFA, 0xCE]))
    }

    // MARK: - minf (MediaInformationBox)

    @Test
    func minfDoesNotOverConsumeTrailingSibling() async throws {
        let minf = MediaInformationBox(
            header: Self.placeholderHeader(for: "minf"),
            children: [Self.makeFreeChild(0xBA)]
        )
        let sibling = FreeSpaceBox(onWireType: "free", payload: Data([0xDE]))
        let bytes = Self.encode(boxes: [minf, sibling])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 2)
        #expect(parsed.first is MediaInformationBox)
        let recoveredSibling = try #require(parsed.last as? FreeSpaceBox)
        #expect(recoveredSibling.payload == Data([0xDE]))
    }

    // MARK: - stbl (SampleTableBox)

    @Test
    func stblDoesNotOverConsumeTrailingSibling() async throws {
        let stbl = SampleTableBox(
            header: Self.placeholderHeader(for: "stbl"),
            children: [Self.makeFreeChild(0x77)]
        )
        let sibling = FreeSpaceBox(onWireType: "free", payload: Data([0x88]))
        let bytes = Self.encode(boxes: [stbl, sibling])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 2)
        #expect(parsed.first is SampleTableBox)
        let recoveredSibling = try #require(parsed.last as? FreeSpaceBox)
        #expect(recoveredSibling.payload == Data([0x88]))
    }

    // MARK: - dinf (DataInformationBox)

    @Test
    func dinfDoesNotOverConsumeTrailingSibling() async throws {
        let dinf = DataInformationBox(
            header: Self.placeholderHeader(for: "dinf"),
            children: [Self.makeFreeChild(0x42)]
        )
        let sibling = FreeSpaceBox(onWireType: "free", payload: Data([0x43]))
        let bytes = Self.encode(boxes: [dinf, sibling])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 2)
        #expect(parsed.first is DataInformationBox)
        let recoveredSibling = try #require(parsed.last as? FreeSpaceBox)
        #expect(recoveredSibling.payload == Data([0x43]))
    }

    // MARK: - traf (TrackFragmentBox)

    @Test
    func trafDoesNotOverConsumeTrailingSibling() async throws {
        let traf = TrackFragmentBox(
            header: Self.placeholderHeader(for: "traf"),
            children: [Self.makeFreeChild(0x21)]
        )
        let sibling = FreeSpaceBox(onWireType: "free", payload: Data([0x22]))
        let bytes = Self.encode(boxes: [traf, sibling])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 2)
        #expect(parsed.first is TrackFragmentBox)
        let recoveredSibling = try #require(parsed.last as? FreeSpaceBox)
        #expect(recoveredSibling.payload == Data([0x22]))
    }

    // MARK: - moof (MovieFragmentBox)

    @Test
    func moofDoesNotOverConsumeTrailingSibling() async throws {
        let moof = MovieFragmentBox(
            header: Self.placeholderHeader(for: "moof"),
            children: [Self.makeFreeChild(0x31)]
        )
        let sibling = FreeSpaceBox(onWireType: "free", payload: Data([0x32]))
        let bytes = Self.encode(boxes: [moof, sibling])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 2)
        #expect(parsed.first is MovieFragmentBox)
        let recoveredSibling = try #require(parsed.last as? FreeSpaceBox)
        #expect(recoveredSibling.payload == Data([0x32]))
    }

    // MARK: - edts (EditBox)

    @Test
    func edtsDoesNotOverConsumeTrailingSibling() async throws {
        let edts = EditBox(
            header: Self.placeholderHeader(for: "edts"),
            children: [
                EditListBox(
                    version: 1,
                    table: EditListTable(
                        entries: [
                            EditListEntry(
                                segmentDuration: 100,
                                mediaTime: 0,
                                mediaRateInteger: 1,
                                mediaRateFraction: 0
                            )
                        ],
                        version: 1
                    )
                )
            ]
        )
        let sibling = FreeSpaceBox(onWireType: "free", payload: Data([0xAB, 0xCD]))
        let bytes = Self.encode(boxes: [edts, sibling])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 2)
        #expect(parsed.first is EditBox)
        let recoveredSibling = try #require(parsed.last as? FreeSpaceBox)
        #expect(recoveredSibling.payload == Data([0xAB, 0xCD]))
    }

    // MARK: - deeply nested + multiple trailing siblings

    @Test
    func deeplyNestedContainerPreservesAllTrailingSiblings() async throws {
        // mdia[ minf[ stbl[ free ] ] ] || free1 || free2
        let stbl = SampleTableBox(
            header: Self.placeholderHeader(for: "stbl"),
            children: [Self.makeFreeChild(0x01)]
        )
        let minf = MediaInformationBox(
            header: Self.placeholderHeader(for: "minf"),
            children: [stbl]
        )
        let mdia = MediaBox(
            header: Self.placeholderHeader(for: "mdia"),
            children: [minf]
        )
        let s1 = FreeSpaceBox(onWireType: "free", payload: Data([0x10]))
        let s2 = FreeSpaceBox(onWireType: "free", payload: Data([0x20]))
        let bytes = Self.encode(boxes: [mdia, s1, s2])
        let parsed = try await Self.parse(bytes)
        #expect(parsed.count == 3)
        let mdiaParsed = try #require(parsed[0] as? MediaBox)
        #expect(mdiaParsed.children.first is MediaInformationBox)
        let s1Recovered = try #require(parsed[1] as? FreeSpaceBox)
        let s2Recovered = try #require(parsed[2] as? FreeSpaceBox)
        #expect(s1Recovered.payload == Data([0x10]))
        #expect(s2Recovered.payload == Data([0x20]))
    }

    // MARK: - Helpers

    private static func encode(boxes: [any ISOBox]) -> Data {
        var writer = BinaryWriter()
        for box in boxes {
            box.encode(to: &writer)
        }
        return writer.data
    }

    private static func parse(_ data: Data) async throws -> [any ISOBox] {
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        return try await reader.readBoxes(from: data, using: registry)
    }

    private static func placeholderHeader(for type: FourCC) -> ISOBoxHeader {
        // The encoder uses `writer.writeBox(type:body:)` which
        // rewrites the size after the body is emitted, so a 0 size
        // placeholder here is fine.
        ISOBoxHeader(type: type, size: 0, headerSize: 8)
    }

    private static func makeFreeChild(_ marker: UInt8) -> FreeSpaceBox {
        FreeSpaceBox(onWireType: "free", payload: Data([marker]))
    }
}
