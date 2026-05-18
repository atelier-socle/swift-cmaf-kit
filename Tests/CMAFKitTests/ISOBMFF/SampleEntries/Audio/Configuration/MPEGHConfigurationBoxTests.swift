// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("MPEGHConfigurationBox")
struct MPEGHConfigurationBoxTests {

    @Test
    func minimalRoundTrip() async throws {
        let box = MPEGHConfigurationBox(
            profileLevelIndication: .lcProfileLevel3,
            referenceChannelLayout: 6,
            mpegh3daConfig: Data([0x01, 0x02, 0x03, 0x04])
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MPEGHConfigurationBox)
        #expect(parsed == box)
    }

    @Test
    func emptyConfigBytesRoundTrip() async throws {
        let box = MPEGHConfigurationBox(
            profileLevelIndication: .lcProfileLevel1,
            referenceChannelLayout: 2,
            mpegh3daConfig: Data()
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MPEGHConfigurationBox)
        #expect(parsed == box)
        #expect(parsed.mpegh3daConfig.isEmpty)
    }

    @Test
    func largeConfigBytesRoundTrip() async throws {
        let payload = Data((0..<1024).map { UInt8($0 % 256) })
        let box = MPEGHConfigurationBox(
            profileLevelIndication: .baselineProfileLevel3,
            referenceChannelLayout: 19,
            mpegh3daConfig: payload
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MPEGHConfigurationBox)
        #expect(parsed.mpegh3daConfig.count == 1024)
        #expect(parsed == box)
    }

    @Test
    func rejectsConfigurationVersionNotOne() async throws {
        var box = BinaryWriter()
        box.writeBox(type: "mhaC") { body in
            body.writeUInt8(2)  // bad configurationVersion
            body.writeUInt8(MPEGHProfileLevelIndication.lcProfileLevel3.rawValue)
            body.writeUInt8(6)
            body.writeUInt16(0)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: box.data, using: registry)
        }
    }

    @Test
    func rejectsUnknownProfileLevel() async throws {
        var box = BinaryWriter()
        box.writeBox(type: "mhaC") { body in
            body.writeUInt8(1)
            body.writeUInt8(0xFF)  // not in our enum
            body.writeUInt8(6)
            body.writeUInt16(0)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: box.data, using: registry)
        }
    }

    @Test
    func boxTypeIsMhaC() {
        #expect(MPEGHConfigurationBox.boxType == "mhaC")
    }
}

@Suite("MPEGHProfileLevelCompatibilitySetBox")
struct MPEGHProfileLevelCompatibilitySetBoxTests {

    @Test
    func emptyListRoundTrip() async throws {
        let box = MPEGHProfileLevelCompatibilitySetBox(compatibleProfileLevels: [])
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MPEGHProfileLevelCompatibilitySetBox)
        #expect(parsed == box)
    }

    @Test
    func singleEntryRoundTrip() async throws {
        let box = MPEGHProfileLevelCompatibilitySetBox(
            compatibleProfileLevels: [.lcProfileLevel3]
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MPEGHProfileLevelCompatibilitySetBox)
        #expect(parsed == box)
    }

    @Test
    func multipleEntriesRoundTrip() async throws {
        let entries: [MPEGHProfileLevelIndication] = [
            .lcProfileLevel1, .lcProfileLevel2, .lcProfileLevel3,
            .baselineProfileLevel3
        ]
        let box = MPEGHProfileLevelCompatibilitySetBox(
            compatibleProfileLevels: entries
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MPEGHProfileLevelCompatibilitySetBox)
        #expect(parsed.compatibleProfileLevels.count == 4)
        #expect(parsed == box)
    }

    @Test
    func rejectsUnknownProfileLevel() async throws {
        var box = BinaryWriter()
        box.writeBox(type: "mhaP") { body in
            body.writeUInt8(1)
            body.writeUInt8(0xFF)  // not in our enum
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: box.data, using: registry)
        }
    }

    @Test
    func boxTypeIsMhaP() {
        #expect(MPEGHProfileLevelCompatibilitySetBox.boxType == "mhaP")
    }
}
