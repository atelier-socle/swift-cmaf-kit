// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("DolbyVisionProfile")
struct DolbyVisionProfileTests {

    @Test
    func profile4WireNumber() {
        #expect(DolbyVisionProfile.profile4.wireProfileNumber == 4)
    }

    @Test
    func profile5WireNumber() {
        #expect(DolbyVisionProfile.profile5.wireProfileNumber == 5)
    }

    @Test
    func profile7WireNumber() {
        #expect(DolbyVisionProfile.profile7.wireProfileNumber == 7)
    }

    @Test
    func profile8_1WireNumber() {
        #expect(DolbyVisionProfile.profile8(subProfile: .hdr10Compatible).wireProfileNumber == 8)
    }

    @Test
    func profile9WireNumber() {
        #expect(DolbyVisionProfile.profile9.wireProfileNumber == 9)
    }

    @Test
    func profile10_0WireNumber() {
        #expect(DolbyVisionProfile.profile10(subProfile: .nonCompatible).wireProfileNumber == 10)
    }

    @Test
    func makeProfile8_1FromWire() throws {
        let p = try DolbyVisionProfile.make(wireProfileNumber: 8, compatibilityID: .hdr10Compatible)
        if case .profile8(let sub) = p {
            #expect(sub == .hdr10Compatible)
        } else {
            Issue.record("Expected profile8")
        }
    }

    @Test
    func makeProfile8_2FromWire() throws {
        let p = try DolbyVisionProfile.make(wireProfileNumber: 8, compatibilityID: .sdrCompatible)
        if case .profile8(let sub) = p {
            #expect(sub == .sdrCompatible)
        } else {
            Issue.record("Expected profile8")
        }
    }

    @Test
    func makeProfile10_4FromWire() throws {
        let p = try DolbyVisionProfile.make(wireProfileNumber: 10, compatibilityID: .hlgCompatible)
        if case .profile10(let sub) = p {
            #expect(sub == .hlgCompatible)
        } else {
            Issue.record("Expected profile10")
        }
    }

    @Test
    func makeUnknownProfileThrows() async throws {
        #expect(throws: ISOBoxError.self) {
            _ = try DolbyVisionProfile.make(wireProfileNumber: 11, compatibilityID: .nonCompatible)
        }
    }

    @Test
    func profile8WithReserved3Throws() async throws {
        #expect(throws: ISOBoxError.self) {
            _ = try DolbyVisionProfile.make(wireProfileNumber: 8, compatibilityID: .reserved3)
        }
    }

    @Test
    func profile10WithReserved3Throws() async throws {
        #expect(throws: ISOBoxError.self) {
            _ = try DolbyVisionProfile.make(wireProfileNumber: 10, compatibilityID: .reserved3)
        }
    }
}

@Suite("DolbyVisionLevel")
struct DolbyVisionLevelTests {

    @Test
    func level01IsOne() {
        #expect(DolbyVisionLevel.level01.rawValue == 1)
    }

    @Test
    func level13IsThirteen() {
        #expect(DolbyVisionLevel.level13.rawValue == 13)
    }

    @Test
    func thirteenLevelsTotal() {
        #expect(DolbyVisionLevel.allCases.count == 13)
    }

    @Test
    func unknownLevelRejected() {
        #expect(DolbyVisionLevel(rawValue: 14) == nil)
    }
}

@Suite("DolbyVisionBLSignalCompatibilityID")
struct DolbyVisionBLSignalCompatibilityIDTests {

    @Test
    func nonCompatibleIsZero() {
        #expect(DolbyVisionBLSignalCompatibilityID.nonCompatible.rawValue == 0)
    }

    @Test
    func hdr10CompatibleIsOne() {
        #expect(DolbyVisionBLSignalCompatibilityID.hdr10Compatible.rawValue == 1)
    }

    @Test
    func hlgCompatibleIsFour() {
        #expect(DolbyVisionBLSignalCompatibilityID.hlgCompatible.rawValue == 4)
    }

    @Test
    func allSixteenValuesPresent() {
        #expect(DolbyVisionBLSignalCompatibilityID.allCases.count == 16)
    }
}

@Suite("DolbyVisionConfiguration")
struct DolbyVisionConfigurationTests {

    @Test
    func profile5BitPacking() throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile5,
            level: .level06,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .nonCompatible
        )
        var writer = BinaryWriter()
        config.encode(to: &writer)
        #expect(writer.data.count == 24)

        var reader = BinaryReader(writer.data)
        let decoded = try DolbyVisionConfiguration.parse(reader: &reader)
        #expect(decoded == config)
    }

    @Test
    func profile8_1RoundTrip() throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile8(subProfile: .hdr10Compatible),
            level: .level09,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .hdr10Compatible
        )
        var writer = BinaryWriter()
        config.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try DolbyVisionConfiguration.parse(reader: &reader)
        #expect(decoded == config)
    }

    @Test
    func profile8_2RoundTrip() throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile8(subProfile: .sdrCompatible),
            level: .level07,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .sdrCompatible
        )
        var writer = BinaryWriter()
        config.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try DolbyVisionConfiguration.parse(reader: &reader)
        #expect(decoded == config)
    }

    @Test
    func profile8_4RoundTrip() throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile8(subProfile: .hlgCompatible),
            level: .level08,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .hlgCompatible
        )
        var writer = BinaryWriter()
        config.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try DolbyVisionConfiguration.parse(reader: &reader)
        #expect(decoded == config)
    }

    @Test
    func profile10_0RoundTrip() throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile10(subProfile: .nonCompatible),
            level: .level09,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .nonCompatible
        )
        var writer = BinaryWriter()
        config.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try DolbyVisionConfiguration.parse(reader: &reader)
        #expect(decoded == config)
    }

    @Test
    func profile10_1RoundTrip() throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile10(subProfile: .hdr10Compatible),
            level: .level10,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .hdr10Compatible
        )
        var writer = BinaryWriter()
        config.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try DolbyVisionConfiguration.parse(reader: &reader)
        #expect(decoded == config)
    }

    @Test
    func reservedCompatibility3Throws() async throws {
        var writer = BinaryWriter()
        writer.writeUInt8(1)  // versionMajor
        writer.writeUInt8(0)  // versionMinor
        writer.writeUInt8(16)  // profile=8 (8<<1)|0
        writer.writeUInt8(53)  // level=6 (6<<3)|5
        writer.writeUInt8(48)  // compat=3 (3<<4)
        writer.writeZeros(19)

        var reader = BinaryReader(writer.data)
        #expect(throws: ISOBoxError.self) {
            _ = try DolbyVisionConfiguration.parse(reader: &reader)
        }
    }

    @Test
    func unknownProfileThrows() async throws {
        var writer = BinaryWriter()
        writer.writeUInt8(1)
        writer.writeUInt8(0)
        writer.writeUInt8(11 << 1)  // profile=11 (unknown)
        writer.writeUInt8(0)
        writer.writeUInt8(0)
        writer.writeZeros(19)

        var reader = BinaryReader(writer.data)
        #expect(throws: ISOBoxError.self) {
            _ = try DolbyVisionConfiguration.parse(reader: &reader)
        }
    }

    @Test
    func twentyFourByteSize() {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile5,
            level: .level01,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .nonCompatible
        )
        var writer = BinaryWriter()
        config.encode(to: &writer)
        #expect(writer.data.count == 24)
    }
}

@Suite("DolbyVisionELConfiguration")
struct DolbyVisionELConfigurationTests {

    @Test
    func profile7ELRoundTrip() throws {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile7,
            level: .level09,
            rpuPresent: true, elPresent: true, blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let original = DolbyVisionELConfiguration(configuration: config)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try DolbyVisionELConfiguration.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func twentyFourByteSize() {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile7,
            level: .level01,
            rpuPresent: true, elPresent: true, blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let el = DolbyVisionELConfiguration(configuration: config)
        var writer = BinaryWriter()
        el.encode(to: &writer)
        #expect(writer.data.count == 24)
    }

    @Test
    func wrappedConfigurationAccessible() {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile7,
            level: .level01,
            rpuPresent: true, elPresent: true, blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let el = DolbyVisionELConfiguration(configuration: config)
        #expect(el.configuration == config)
    }

    @Test
    func equatableConformance() {
        let config = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile7,
            level: .level01,
            rpuPresent: true, elPresent: true, blPresent: false,
            blSignalCompatibilityID: .nonCompatible
        )
        let a = DolbyVisionELConfiguration(configuration: config)
        let b = DolbyVisionELConfiguration(configuration: config)
        #expect(a == b)
    }
}
