// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for the WRMHEADER XML parser + serializer across the
// four supported versions (4.0 / 4.1 / 4.2 / 4.3).

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("PlayReadyInitData — WRMHEADER")
struct PlayReadyWRMHEADERTests {

    private static let testKID = Data(repeating: 0xCD, count: 16)
    private static let testKID2 = Data(repeating: 0x77, count: 16)

    private func roundTrip(
        _ header: PlayReadyInitData.WRMHeader
    ) throws -> PlayReadyInitData.WRMHeader {
        let init1 = PlayReadyInitData(records: [.wrmHeader(header)])
        let encoded = try PlayReadyInitData.encode(init1)
        let parsed = try PlayReadyInitData.parse(encoded)
        try #require(parsed.records.count == 1)
        guard case let .wrmHeader(out) = parsed.records[0] else {
            Issue.record("expected wrmHeader record")
            return header
        }
        return out
    }

    @Test
    func v40SingleKIDRoundTrip() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_0,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.testKID)]
        )
        let parsed = try roundTrip(header)
        #expect(parsed.version == .v4_0)
        #expect(parsed.kids.count == 1)
        #expect(parsed.kids.first?.value == Self.testKID)
    }

    @Test
    func v41SingleKIDRoundTrip() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.testKID)]
        )
        let parsed = try roundTrip(header)
        #expect(parsed.version == .v4_1)
        #expect(parsed.kids.first?.value == Self.testKID)
    }

    @Test
    func v41MultipleKIDsRoundTrip() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [
                PlayReadyInitData.WRMHeader.KID(value: Self.testKID),
                PlayReadyInitData.WRMHeader.KID(value: Self.testKID2)
            ]
        )
        let parsed = try roundTrip(header)
        #expect(parsed.kids.count == 2)
        #expect(Set(parsed.kids.map(\.value)) == [Self.testKID, Self.testKID2])
    }

    @Test
    func v42KIDRoundTripWithDecryptorSetup() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_2,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.testKID)],
            decryptorSetup: "ONDEMAND"
        )
        let parsed = try roundTrip(header)
        #expect(parsed.version == .v4_2)
        #expect(parsed.decryptorSetup == "ONDEMAND")
    }

    @Test
    func v43KIDRoundTrip() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_3,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.testKID)]
        )
        let parsed = try roundTrip(header)
        #expect(parsed.version == .v4_3)
    }

    @Test
    func headerWithLA_URL() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.testKID)],
            licenseAcquisitionURL: URL(string: "https://license.example.com/playready")
        )
        let parsed = try roundTrip(header)
        #expect(
            parsed.licenseAcquisitionURL?.absoluteString
                == "https://license.example.com/playready"
        )
    }

    @Test
    func headerWithLUI_URL() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.testKID)],
            licenseUIURL: URL(string: "https://ui.example.com/playready")
        )
        let parsed = try roundTrip(header)
        #expect(
            parsed.licenseUIURL?.absoluteString
                == "https://ui.example.com/playready"
        )
    }

    @Test
    func headerWithDomainServiceID() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.testKID)],
            domainServiceID: "atelier-socle"
        )
        let parsed = try roundTrip(header)
        #expect(parsed.domainServiceID == "atelier-socle")
    }

    @Test
    func headerWithChecksum() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.testKID)],
            checksum: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        )
        let parsed = try roundTrip(header)
        #expect(
            parsed.checksum
                == Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        )
    }

    @Test
    func kidWithAlgorithmIDPreserved() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [
                PlayReadyInitData.WRMHeader.KID(
                    value: Self.testKID, algorithmID: "AESCTR"
                )
            ]
        )
        let parsed = try roundTrip(header)
        #expect(parsed.kids.first?.algorithmID == "AESCTR")
    }

    @Test
    func unknownVersionThrows() {
        // Build a PRO whose WRMHEADER declares version "9.0.0.0".
        let xml = """
            <WRMHEADER xmlns="http://schemas.microsoft.com/DRM/2007/03/PlayReadyHeader" version="9.0.0.0"><DATA></DATA></WRMHEADER>
            """
        var record = Data([0xFF, 0xFE])
        guard let utf16 = xml.data(using: .utf16LittleEndian) else {
            Issue.record("Failed to encode UTF-16 LE")
            return
        }
        record.append(utf16)
        var pro: [UInt8] = []
        let totalLength = 6 + 4 + record.count
        let length = UInt32(totalLength)
        pro.append(UInt8(length & 0xFF))
        pro.append(UInt8((length >> 8) & 0xFF))
        pro.append(UInt8((length >> 16) & 0xFF))
        pro.append(UInt8((length >> 24) & 0xFF))
        pro.append(0x01)
        pro.append(0x00)
        pro.append(0x01)
        pro.append(0x00)
        let valLength = UInt16(record.count)
        pro.append(UInt8(valLength & 0xFF))
        pro.append(UInt8((valLength >> 8) & 0xFF))
        pro.append(contentsOf: record)
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(Data(pro))
        }
    }

    @Test
    func wrmHeaderRecordRoundTripsByteForByte() throws {
        let original = PlayReadyInitData(
            records: [
                .wrmHeader(
                    PlayReadyInitData.WRMHeader(
                        version: .v4_1,
                        kids: [
                            PlayReadyInitData.WRMHeader.KID(
                                value: Self.testKID, algorithmID: "AESCTR"
                            )
                        ]
                    )
                )
            ]
        )
        let encoded1 = try PlayReadyInitData.encode(original)
        // Re-parse and re-encode; canonical-order encoder should
        // produce identical bytes.
        let parsed = try PlayReadyInitData.parse(encoded1)
        let encoded2 = try PlayReadyInitData.encode(parsed)
        #expect(encoded1 == encoded2, "Encoder must be deterministic")
    }

    @Test
    func systemIDPropagates() {
        #expect(PlayReadyInitData.systemID == .playReady)
    }
}

@Suite("PlayReadyInitData — fixtures")
struct PlayReadyInitDataFixturesTests {

    /// Pattern A — canonical v4.1 PRO with a single KID.
    @Test
    func patternAV41OneKIDRoundTrip() throws {
        let kid = Data(repeating: 0x42, count: 16)
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [PlayReadyInitData.WRMHeader.KID(value: kid)]
        )
        let original = PlayReadyInitData(records: [.wrmHeader(header)])
        let encoded = try PlayReadyInitData.encode(original)

        // Round-trip parse then re-encode must equal the canonical
        // bytes the encoder produces.
        let parsed = try PlayReadyInitData.parse(encoded)
        let reencoded = try PlayReadyInitData.encode(parsed)
        #expect(reencoded == encoded)
    }

    /// Pattern B — synthesised v4.0 in-the-wild fixture with
    /// custom attributes. Semantic equivalence only since the
    /// CUSTOMATTRIBUTES inner XML round-trips through the
    /// canonical serializer.
    @Test
    func patternBV40WithCustomAttributes() throws {
        let kid = Data(repeating: 0x55, count: 16)
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_0,
            kids: [PlayReadyInitData.WRMHeader.KID(value: kid)],
            customAttributesXML: "<RELEASE>2026</RELEASE>"
        )
        let original = PlayReadyInitData(records: [.wrmHeader(header)])
        let encoded = try PlayReadyInitData.encode(original)
        let parsed = try PlayReadyInitData.parse(encoded)
        let reencoded = try PlayReadyInitData.encode(parsed)
        // Re-parse the re-encoded bytes; semantic equivalence
        // verified.
        let reparsed = try PlayReadyInitData.parse(reencoded)
        #expect(reparsed == parsed)
    }
}
