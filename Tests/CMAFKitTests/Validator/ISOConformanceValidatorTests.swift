// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// ISOConformanceValidator — 8-rule coverage per ISO/IEC 14496-12 §4-§8.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ISOConformanceValidator — rule I1 (FileTypePresent)")
struct ISOConformanceValidatorRuleI1Tests {

    @Test func conformantWithFTYP() {
        let ftyp = FileTypeBox(
            majorBrand: "cmfc", minorVersion: 0, compatibleBrands: ["iso6", "cmfc"])
        let validator = ISOConformanceValidator()
        let report = validator.validate(rootBoxes: [ftyp])
        #expect(report.issues(for: .I1_FileTypePresent).isEmpty)
    }

    @Test func nonConformantWithoutFTYP() {
        let validator = ISOConformanceValidator()
        let report = validator.validate(rootBoxes: [])
        #expect(report.issues(for: .I1_FileTypePresent).contains { $0.severity == .error })
        #expect(!report.isConformant)
    }

    @Test func nonConformantWhenFtypAbsentEntirely() {
        let mvhd = ISOFixtures.makeMVHD()
        let moov = ISOFixtures.makeMoov(children: [mvhd])
        let validator = ISOConformanceValidator()
        let report = validator.validate(rootBoxes: [moov])
        #expect(report.issues(for: .I1_FileTypePresent).contains { $0.severity == .error })
    }

    @Test func warnsWhenFtypFollowsUnexpectedBox() {
        let moov = ISOFixtures.makeMoov(
            children: [ISOFixtures.makeMVHD()])
        let ftyp = FileTypeBox(
            majorBrand: "cmfc", minorVersion: 0, compatibleBrands: ["iso6", "cmfc"])
        let validator = ISOConformanceValidator()
        let report = validator.validate(rootBoxes: [moov, ftyp])
        #expect(report.issues(for: .I1_FileTypePresent).contains { $0.severity == .warning })
    }
}

@Suite("ISOConformanceValidator — rule I2 (MovieBoxUnique)")
struct ISOConformanceValidatorRuleI2Tests {

    @Test func conformantWithSingleMOOV() {
        let validator = ISOConformanceValidator()
        let report = validator.validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [ISOFixtures.makeMVHD()])
        ])
        #expect(report.issues(for: .I2_MovieBoxUnique).isEmpty)
    }

    @Test func nonConformantWithTwoMOOVs() {
        let validator = ISOConformanceValidator()
        let mvhd = ISOFixtures.makeMVHD()
        let report = validator.validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [mvhd]),
            ISOFixtures.makeMoov(children: [mvhd])
        ])
        let i2Errors = report.issues(for: .I2_MovieBoxUnique)
        #expect(i2Errors.contains { $0.severity == .error })
    }

    @Test func conformantWithZeroMOOVs() {
        // Fragmented file (sidx / styp only, no moov) — allowed.
        let validator = ISOConformanceValidator()
        let report = validator.validate(rootBoxes: [ISOFixtures.makeFtyp()])
        #expect(report.issues(for: .I2_MovieBoxUnique).isEmpty)
    }
}

@Suite("ISOConformanceValidator — rule I3 (TrackIDsUnique)")
struct ISOConformanceValidatorRuleI3Tests {

    @Test func conformantWithUniqueTrackIDs() {
        let moov = ISOFixtures.makeMoov(children: [
            ISOFixtures.makeMVHD(),
            ISOFixtures.makeTrak(trackID: 1),
            ISOFixtures.makeTrak(trackID: 2)
        ])
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(), moov
        ])
        #expect(report.issues(for: .I3_TrackIDsUnique).isEmpty)
    }

    @Test func nonConformantWithDuplicateTrackIDs() {
        let moov = ISOFixtures.makeMoov(children: [
            ISOFixtures.makeMVHD(),
            ISOFixtures.makeTrak(trackID: 1),
            ISOFixtures.makeTrak(trackID: 1)
        ])
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(), moov
        ])
        let i3 = report.issues(for: .I3_TrackIDsUnique)
        #expect(i3.contains { $0.severity == .error })
        #expect(i3.contains { $0.context?.contains("trackID: 1") ?? false })
    }
}

@Suite("ISOConformanceValidator — rule I4 (MediaHeaderTimescalePositive)")
struct ISOConformanceValidatorRuleI4Tests {

    @Test func conformantWithPositiveTimescale() {
        let moov = ISOFixtures.makeMoov(children: [
            ISOFixtures.makeMVHD(),
            ISOFixtures.makeTrak(trackID: 1, timescale: 1000)
        ])
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(), moov
        ])
        #expect(report.issues(for: .I4_MediaHeaderTimescalePositive).isEmpty)
    }

    @Test func nonConformantWithZeroTimescale() {
        let moov = ISOFixtures.makeMoov(children: [
            ISOFixtures.makeMVHD(),
            ISOFixtures.makeTrak(trackID: 1, timescale: 0)
        ])
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(), moov
        ])
        #expect(
            report.issues(for: .I4_MediaHeaderTimescalePositive)
                .contains { $0.severity == .error })
    }
}

@Suite("ISOConformanceValidator — rule I5 (TrackHeaderIDCoherent)")
struct ISOConformanceValidatorRuleI5Tests {

    @Test func conformantWithNonZeroTrackID() {
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(),
                ISOFixtures.makeTrak(trackID: 5)
            ])
        ])
        #expect(report.issues(for: .I5_TrackHeaderIDCoherent).isEmpty)
    }

    @Test func nonConformantWithZeroTrackID() {
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(),
                ISOFixtures.makeTrak(trackID: 0)
            ])
        ])
        #expect(
            report.issues(for: .I5_TrackHeaderIDCoherent)
                .contains { $0.severity == .error })
    }
}

@Suite("ISOConformanceValidator — rule I8 (BoxStructureCoherent)")
struct ISOConformanceValidatorRuleI8Tests {

    @Test func conformantWhenMoovCarriesMvhd() {
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [ISOFixtures.makeMVHD()])
        ])
        #expect(report.issues(for: .I8_BoxStructureCoherent).isEmpty)
    }

    @Test func nonConformantWhenMoovMissingMvhd() {
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [])
        ])
        #expect(
            report.issues(for: .I8_BoxStructureCoherent)
                .contains { $0.severity == .error })
    }

    @Test func nonConformantWhenTrakMissingMdia() {
        let trakWithoutMdia = TrackBox(
            header: ISOBoxHeader(type: "trak", size: 0, headerSize: 8),
            children: [
                TrackHeaderBox(
                    creationTime: 0, modificationTime: 0,
                    trackID: 1, duration: 0)
            ])
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(), trakWithoutMdia
            ])
        ])
        #expect(
            report.issues(for: .I8_BoxStructureCoherent)
                .contains { $0.severity == .error })
    }
}

@Suite("ISOConformanceValidator — composition + reporting")
struct ISOConformanceValidatorCompositionTests {

    @Test func isConformantWhenNoErrors() {
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(),
                ISOFixtures.makeTrak(trackID: 1)
            ])
        ])
        #expect(report.isConformant)
    }

    @Test func issuesFilteredBySeverity() {
        let report = ISOConformanceValidator().validate(rootBoxes: [])
        #expect(!report.issues(of: .error).isEmpty)
        #expect(report.issues(of: .warning).isEmpty)
    }

    @Test func issuesFilteredByRule() {
        let report = ISOConformanceValidator().validate(rootBoxes: [])
        #expect(report.issues(for: .I1_FileTypePresent).count >= 1)
        #expect(report.issues(for: .I3_TrackIDsUnique).isEmpty)
    }

    @Test func permissiveModeSuppressesWarnings() {
        // moov before ftyp → I1 warning in strict, suppressed in permissive.
        let moov = ISOFixtures.makeMoov(children: [ISOFixtures.makeMVHD()])
        let ftyp = ISOFixtures.makeFtyp()
        let strict = ISOConformanceValidator(level: .strict).validate(rootBoxes: [moov, ftyp])
        let permissive = ISOConformanceValidator(level: .permissive).validate(rootBoxes: [moov, ftyp])
        #expect(strict.issues(of: .warning).isEmpty == false)
        #expect(permissive.issues(of: .warning).isEmpty)
    }

    @Test func ruleEnumExposesSpecSection() {
        #expect(ISOConformanceRule.I1_FileTypePresent.specSection.contains("§4.3"))
        #expect(ISOConformanceRule.I8_BoxStructureCoherent.specSection.contains("§8"))
    }

    @Test func cleanReportSerializesAsCodable() throws {
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(),
                ISOFixtures.makeTrak(trackID: 1)
            ])
        ])
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(ISOConformanceReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func validatesArbitraryISOBMFFFile() async throws {
        // Smoke test: validate a real fMP4 init segment built via the
        // existing 0.1.0 writer pipeline. ISO validator must accept it.
        var writer = BinaryWriter()
        ISOFixtures.makeFtyp().encode(to: &writer)
        ISOFixtures.makeMoov(children: [
            ISOFixtures.makeMVHD(), ISOFixtures.makeTrak(trackID: 1)
        ]).encode(to: &writer)
        let report = try await ISOConformanceValidator().validate(data: writer.data)
        #expect(report.isConformant)
    }

    @Test func validatesFromFileURL() async throws {
        var writer = BinaryWriter()
        ISOFixtures.makeFtyp().encode(to: &writer)
        ISOFixtures.makeMoov(children: [
            ISOFixtures.makeMVHD(), ISOFixtures.makeTrak(trackID: 1)
        ]).encode(to: &writer)
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempURL = tempDir.appendingPathComponent(
            "iso-validator-\(UUID().uuidString).mp4")
        try writer.data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let report = try await ISOConformanceValidator()
            .validate(fileURL: tempURL)
        #expect(report.isConformant)
    }

    @Test func reportsI5WhenTrakHasNoTkhd() {
        let trakWithoutTkhd = TrackBox(
            header: ISOBoxHeader(type: "trak", size: 0, headerSize: 8),
            children: [
                MediaBox(
                    header: ISOBoxHeader(type: "mdia", size: 0, headerSize: 8),
                    children: [
                        MediaHeaderBox(
                            creationTime: 0, modificationTime: 0,
                            timescale: 1000, duration: 0, language: "und")
                    ])
            ])
        let report = ISOConformanceValidator().validate(rootBoxes: [
            ISOFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(), trakWithoutTkhd
            ])
        ])
        #expect(
            report.issues(for: .I5_TrackHeaderIDCoherent)
                .contains { $0.severity == .error })
    }
}

// MARK: - Fixtures

internal enum ISOFixtures {

    static func makeFtyp() -> FileTypeBox {
        FileTypeBox(
            majorBrand: "cmfc", minorVersion: 0,
            compatibleBrands: ["iso6", "cmfc"])
    }

    static func makeMVHD() -> MovieHeaderBox {
        MovieHeaderBox(
            creationTime: 0, modificationTime: 0,
            timescale: 1000, duration: 0, nextTrackID: 1)
    }

    static func makeMoov(children: [any ISOBox]) -> MovieBox {
        MovieBox(
            header: ISOBoxHeader(type: "moov", size: 0, headerSize: 8),
            children: children)
    }

    static func makeTrak(trackID: UInt32, timescale: UInt32 = 1000) -> TrackBox {
        let tkhd = TrackHeaderBox(
            creationTime: 0, modificationTime: 0,
            trackID: trackID, duration: 0)
        let mdhd = MediaHeaderBox(
            creationTime: 0, modificationTime: 0,
            timescale: timescale, duration: 0, language: "und")
        let mdia = MediaBox(
            header: ISOBoxHeader(type: "mdia", size: 0, headerSize: 8),
            children: [mdhd])
        return TrackBox(
            header: ISOBoxHeader(type: "trak", size: 0, headerSize: 8),
            children: [tkhd, mdia])
    }
}
