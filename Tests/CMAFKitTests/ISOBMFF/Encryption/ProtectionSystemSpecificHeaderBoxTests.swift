// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ProtectionSystemSpecificHeaderBox (pssh)")
struct ProtectionSystemSpecificHeaderBoxTests {

    // Common DRM SystemIDs from the ISO Common Encryption registry.
    private static let widevineUUIDString = "EDEF8BA9-79D6-4ACE-A3C8-27DCD51D21ED"
    private static let playReadyUUIDString = "9A04F079-9840-4286-AB92-E65BE0885F95"
    private static let fairPlayUUIDString = "94CE86FB-07FF-4F43-ADB8-93D2FA968CA2"
    private static let clearKeyUUIDString = "1077EFEC-C0B2-4D02-ACE3-3C1E52E2FB4B"
    private static let marlinUUIDString = "5E629AF5-38DA-4063-8977-97FFBD9902D4"

    private func roundTrip(
        _ box: ProtectionSystemSpecificHeaderBox
    ) async throws -> ProtectionSystemSpecificHeaderBox {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? ProtectionSystemSpecificHeaderBox)
    }

    @Test
    func v1WidevineWithOneKIDRoundTrip() async throws {
        let widevineUUID = try #require(UUID(uuidString: Self.widevineUUIDString))
        let kid = KeyIdentifier(rawBytes: Data(repeating: 0x11, count: 16))
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [kid],
            data: Data([0x08, 0x01, 0x12, 0x10] + Array(repeating: UInt8(0xCC), count: 16))
        )
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
    }

    @Test
    func v1PlayReadyRoundTrip() async throws {
        let playReadyUUID = try #require(UUID(uuidString: Self.playReadyUUIDString))
        let kids = [
            KeyIdentifier(rawBytes: Data(repeating: 0xAB, count: 16)),
            KeyIdentifier(rawBytes: Data(repeating: 0xCD, count: 16))
        ]
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: playReadyUUID,
            keyIdentifiers: kids,
            data: Data([0x12, 0x34, 0x56, 0x78])
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.keyIdentifiers?.count == 2)
        #expect(parsed.systemID == playReadyUUID)
    }

    @Test
    func v0RoundTrip() async throws {
        let fairPlayUUID = try #require(UUID(uuidString: Self.fairPlayUUIDString))
        let box = ProtectionSystemSpecificHeaderBox(
            version: 0,
            systemID: fairPlayUUID,
            keyIdentifiers: nil,
            data: Data([0xDE, 0xAD, 0xBE, 0xEF])
        )
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.keyIdentifiers == nil)
    }

    @Test
    func v1WithZeroKIDs() async throws {
        let widevineUUID = try #require(UUID(uuidString: Self.widevineUUIDString))
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [],
            data: Data()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.keyIdentifiers?.isEmpty == true)
    }

    @Test
    func v1ClearKeyRoundTrip() async throws {
        let clearKeyUUID = try #require(UUID(uuidString: Self.clearKeyUUIDString))
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: clearKeyUUID,
            keyIdentifiers: [KeyIdentifier(rawBytes: Data(repeating: 0x77, count: 16))],
            data: Data()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.systemID == clearKeyUUID)
    }

    @Test
    func v1MarlinRoundTrip() async throws {
        let marlinUUID = try #require(UUID(uuidString: Self.marlinUUIDString))
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: marlinUUID,
            keyIdentifiers: [],
            data: Data([0xFE, 0xED, 0xFA, 0xCE])
        )
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func unsupportedVersionRejected() async {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "pssh", version: 2, flags: 0) { body in
            body.writeData(Data(repeating: 0x00, count: 16))
            body.writeUInt32(0)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func boxType() {
        #expect(ProtectionSystemSpecificHeaderBox.boxType == "pssh")
    }

    @Test
    func registryParserIsRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "pssh")
        #expect(parser != nil)
    }

    @Test
    func dataPayloadByteForBytePreserved() async throws {
        let widevineUUID = try #require(UUID(uuidString: Self.widevineUUIDString))
        let payload = Data((0..<32).map { UInt8($0 ^ 0xA5) })
        let box = ProtectionSystemSpecificHeaderBox(
            version: 0,
            systemID: widevineUUID,
            keyIdentifiers: nil,
            data: payload
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.data == payload)
    }

    @Test
    func multipleKIDsInOrder() async throws {
        let widevineUUID = try #require(UUID(uuidString: Self.widevineUUIDString))
        let kids = (0..<5).map { i in
            KeyIdentifier(rawBytes: Data(repeating: UInt8(i + 1), count: 16))
        }
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: kids,
            data: Data()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.keyIdentifiers == kids)
    }

    @Test
    func duplicateKIDsPreservedVerbatim() async throws {
        let widevineUUID = try #require(UUID(uuidString: Self.widevineUUIDString))
        let kid = KeyIdentifier(rawBytes: Data(repeating: 0x42, count: 16))
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [kid, kid, kid],
            data: Data()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.keyIdentifiers?.count == 3)
    }

    @Test
    func emptyDataAccepted() async throws {
        let fairPlayUUID = try #require(UUID(uuidString: Self.fairPlayUUIDString))
        let box = ProtectionSystemSpecificHeaderBox(
            version: 0,
            systemID: fairPlayUUID,
            keyIdentifiers: nil,
            data: Data()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.data == Data())
    }

    @Test
    func systemIDPreservedExactly() async throws {
        let uuid = try #require(UUID(uuidString: "01020304-0506-0708-090A-0B0C0D0E0F10"))
        let box = ProtectionSystemSpecificHeaderBox(
            version: 0,
            systemID: uuid,
            keyIdentifiers: nil,
            data: Data()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.systemID == uuid)
    }

    @Test
    func byteForByteRoundTrip() async throws {
        let widevineUUID = try #require(UUID(uuidString: Self.widevineUUIDString))
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [KeyIdentifier(rawBytes: Data(repeating: 0xAA, count: 16))],
            data: Data([0xDE, 0xAD, 0xBE, 0xEF])
        )
        var w1 = BinaryWriter()
        box.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? ProtectionSystemSpecificHeaderBox)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func largeKIDList() async throws {
        let widevineUUID = try #require(UUID(uuidString: Self.widevineUUIDString))
        let kids = (0..<32).map { i in
            KeyIdentifier(rawBytes: Data(repeating: UInt8(i % 256), count: 16))
        }
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: kids,
            data: Data()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.keyIdentifiers?.count == 32)
    }

    @Test
    func largeDataPayload() async throws {
        let widevineUUID = try #require(UUID(uuidString: Self.widevineUUIDString))
        let payload = Data((0..<1024).map { UInt8($0 % 256) })
        let box = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [],
            data: payload
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.data.count == 1024)
    }

    @Test
    func equalityComparesAllFields() throws {
        let widevineUUID = try #require(UUID(uuidString: Self.widevineUUIDString))
        let box1 = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [],
            data: Data([0x01])
        )
        let box2 = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [],
            data: Data([0x01])
        )
        let box3 = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [],
            data: Data([0x02])
        )
        #expect(box1 == box2)
        #expect(box1 != box3)
    }
}
