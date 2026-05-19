// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("Encryption — BoxRegistry integration")
struct EncryptionBoxRegistryIntegrationTests {

    @Test
    func registryExposesAllEncryptionFourCCs() async {
        let registry = await BoxRegistry.defaultRegistry()
        let expected: [FourCC] = ["frma", "schm", "schi", "sinf", "tenc", "pssh"]
        for fourCC in expected {
            let parser = await registry.parser(for: fourCC)
            #expect(parser != nil, "registry missing parser for \(fourCC)")
        }
    }

    @Test
    func sencIsExcludedFromDefaultRegistry() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "senc")
        #expect(parser == nil)
    }

    @Test
    func sinfParsedThroughDefaultDispatch() async throws {
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "avc1"),
            schemeType: SchemeTypeBox(schemeType: .cenc),
            schemeInformation: SchemeInformationBox(
                trackEncryption: TrackEncryptionBox(
                    version: 0,
                    defaultIsProtected: true,
                    defaultPerSampleIVSize: .eight,
                    defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0xAA, count: 16))
                )
            )
        )
        var writer = BinaryWriter()
        sinf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ProtectionSchemeInfoBox)
        #expect(parsed == sinf)
    }

    @Test
    func psshParsedThroughDefaultDispatch() async throws {
        let widevineUUID = try #require(UUID(uuidString: "EDEF8BA9-79D6-4ACE-A3C8-27DCD51D21ED"))
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [KeyIdentifier(rawBytes: Data(repeating: 0xBB, count: 16))],
            data: Data([0x01, 0x02, 0x03])
        )
        var writer = BinaryWriter()
        pssh.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ProtectionSystemSpecificHeaderBox)
        #expect(parsed == pssh)
    }

    @Test
    func sinfNestedInSampleTablePathFindable() async throws {
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "hvc1"),
            schemeType: SchemeTypeBox(schemeType: .cbcs),
            schemeInformation: SchemeInformationBox(
                trackEncryption: TrackEncryptionBox(
                    version: 1,
                    defaultCryptByteBlock: 1,
                    defaultSkipByteBlock: 9,
                    defaultIsProtected: true,
                    defaultPerSampleIVSize: .zero,
                    defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0x77, count: 16)),
                    defaultConstantIV: try ConstantIV(rawBytes: Data(repeating: 0x55, count: 16))
                )
            )
        )
        let stblHeader = ISOBoxHeader(type: "stbl", size: 0, headerSize: 8)
        let stbl = SampleTableBox(header: stblHeader, children: [sinf])
        var writer = BinaryWriter()
        stbl.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsedSinf = reader.findBox(at: "stbl/sinf", in: boxes)
        let typed = try #require(parsedSinf as? ProtectionSchemeInfoBox)
        #expect(typed.schemeType?.schemeType == .cbcs)
    }

    @Test
    func psshNestedInMoovPath() async throws {
        let playReadyUUID = try #require(UUID(uuidString: "9A04F079-9840-4286-AB92-E65BE0885F95"))
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 0,
            systemID: playReadyUUID,
            keyIdentifiers: nil,
            data: Data([0xFE, 0xED])
        )
        let mvhd = MovieHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: 0,
            nextTrackID: 1
        )
        let moovHeader = ISOBoxHeader(type: "moov", size: 0, headerSize: 8)
        let moov = MovieBox(header: moovHeader, children: [mvhd, pssh])

        var writer = BinaryWriter()
        moov.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let result = reader.findBox(at: "moov/pssh", in: boxes)
        let typed = try #require(result as? ProtectionSystemSpecificHeaderBox)
        #expect(typed.systemID == pssh.systemID)
    }

    @Test
    func multiplePsshSiblingsBothParsed() async throws {
        let widevineUUID = try #require(UUID(uuidString: "EDEF8BA9-79D6-4ACE-A3C8-27DCD51D21ED"))
        let playReadyUUID = try #require(UUID(uuidString: "9A04F079-9840-4286-AB92-E65BE0885F95"))
        let pssh1 = ProtectionSystemSpecificHeaderBox(
            version: 1, systemID: widevineUUID, keyIdentifiers: [], data: Data()
        )
        let pssh2 = ProtectionSystemSpecificHeaderBox(
            version: 1, systemID: playReadyUUID, keyIdentifiers: [], data: Data()
        )
        var writer = BinaryWriter()
        pssh1.encode(to: &writer)
        pssh2.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.count == 2)
        let firstParsed = try #require(boxes[0] as? ProtectionSystemSpecificHeaderBox)
        let secondParsed = try #require(boxes[1] as? ProtectionSystemSpecificHeaderBox)
        #expect(firstParsed.systemID == widevineUUID)
        #expect(secondParsed.systemID == playReadyUUID)
    }

    @Test
    func encryptionBoxesPlayWellWithOtherRegistryEntries() async throws {
        let ftyp = FileTypeBox(
            majorBrand: "isom",
            minorVersion: 0x200,
            compatibleBrands: ["isom", "cmfc"]
        )
        let fairPlayUUID = try #require(UUID(uuidString: "94CE86FB-07FF-4F43-ADB8-93D2FA968CA2"))
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 0,
            systemID: fairPlayUUID,
            keyIdentifiers: nil,
            data: Data([0xCA, 0xFE])
        )
        var writer = BinaryWriter()
        ftyp.encode(to: &writer)
        pssh.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.count == 2)
        #expect((boxes[0] as? FileTypeBox)?.majorBrand == "isom")
        #expect((boxes[1] as? ProtectionSystemSpecificHeaderBox)?.data == Data([0xCA, 0xFE]))
    }

    @Test
    func tencParsedThroughDefaultDispatch() async throws {
        let tenc = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0xCC, count: 16))
        )
        var writer = BinaryWriter()
        tenc.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackEncryptionBox)
        #expect(parsed == tenc)
    }
}
