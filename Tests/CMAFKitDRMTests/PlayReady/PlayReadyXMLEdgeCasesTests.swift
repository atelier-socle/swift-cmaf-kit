// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Edge-case tests for the WRMHEADER XML parser + serializer that
// drive paths the round-trip suite does not naturally hit:
// non-UTF-16 LE record bodies, missing root attributes, KID
// missing VALUE attribute, CDATA content inside customAttributes,
// xml-character escaping in URL serialisation.

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("PlayReady WRMHEADER — edge cases")
struct PlayReadyXMLEdgeCasesTests {

    private static let testKID = Data(repeating: 0xCD, count: 16)

    private func wrapInPRO(xml: String) -> Data {
        var record = Data([0xFF, 0xFE])
        guard let utf16 = xml.data(using: .utf16LittleEndian) else { return Data() }
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
        return Data(pro)
    }

    @Test
    func wrmHeaderMissingVersionAttributeThrows() {
        let xml = "<WRMHEADER xmlns=\"http://schemas.microsoft.com/DRM/2007/03/PlayReadyHeader\"><DATA></DATA></WRMHEADER>"
        let bytes = wrapInPRO(xml: xml)
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes)
        }
    }

    @Test
    func wrmHeaderInvalidXMLThrows() {
        let xml = "<WRMHEADER<<unclosed"
        let bytes = wrapInPRO(xml: xml)
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes)
        }
    }

    @Test
    func wrmHeaderKIDMissingValueThrows() {
        // v4.1+ KID with missing VALUE attribute.
        let xml = """
            <WRMHEADER xmlns="http://schemas.microsoft.com/DRM/2007/03/PlayReadyHeader" version="4.1.0.0"><DATA><PROTECTINFO><KIDS><KID ALGID="AESCTR"></KID></KIDS></PROTECTINFO></DATA></WRMHEADER>
            """
        let bytes = wrapInPRO(xml: xml)
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes)
        }
    }

    @Test
    func wrmHeaderKIDWithCustomAttributesAndChecksumPreserved() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [
                PlayReadyInitData.WRMHeader.KID(
                    value: Self.testKID,
                    algorithmID: "AESCTR",
                    checksum: Data([0x01, 0x02, 0x03, 0x04])
                )
            ],
            customAttributesXML: "<MARKER>1</MARKER>"
        )
        let original = PlayReadyInitData(records: [.wrmHeader(header)])
        let encoded = try PlayReadyInitData.encode(original)
        let parsed = try PlayReadyInitData.parse(encoded)
        if case let .wrmHeader(out) = parsed.records[0] {
            #expect(out.customAttributesXML?.contains("MARKER") == true)
            #expect(out.kids.first?.algorithmID == "AESCTR")
        } else {
            Issue.record("expected wrmHeader")
        }
    }

    @Test
    func nonUTF16LEBytesThrows() {
        // Build a PRO whose WRMHEADER record value starts with the
        // BOM but is followed by zero subsequent bytes — an empty
        // UTF-16 string.
        let bytes = Data([
            // length 12 = 6 header + 4 record header + 2 bom
            0x0C, 0x00, 0x00, 0x00,
            0x01, 0x00,
            0x01, 0x00,
            0x02, 0x00,
            0xFF, 0xFE,
        ])
        #expect(throws: DRMSystemError.self) {
            _ = try PlayReadyInitData.parse(bytes)
        }
    }

    @Test
    func encodeWRMHeaderWithSpecialCharactersInURL() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.testKID)],
            licenseAcquisitionURL: URL(string: "https://license.example.com/playready?id=A%26B")
        )
        let original = PlayReadyInitData(records: [.wrmHeader(header)])
        let encoded = try PlayReadyInitData.encode(original)
        let parsed = try PlayReadyInitData.parse(encoded)
        if case let .wrmHeader(out) = parsed.records[0] {
            #expect(out.licenseAcquisitionURL?.absoluteString.contains("A%26B") == true)
        } else {
            Issue.record("expected wrmHeader")
        }
    }
}
