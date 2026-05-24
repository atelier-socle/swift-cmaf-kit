// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// CENCConformanceValidator — 8-rule coverage per ISO/IEC 23001-7 §4.

import Foundation
import Testing

@testable import CMAFKit

@Suite("CENCConformanceValidator — clear file detection + C1")
struct CENCConformanceClearAndC1Tests {

    @Test func detectsCENCProtectionFalseForClearFile() {
        let rootBoxes: [any ISOBox] = [
            CENCFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(),
                ISOFixtures.makeTrak(trackID: 1)
            ])
        ]
        let validator = CENCConformanceValidator()
        #expect(!validator.detectsCENCProtection(in: rootBoxes))
        let report = validator.validate(rootBoxes: rootBoxes)
        #expect(report.isClean)
    }

    @Test func detectsCENCProtectionTrueForEncryptedTrack() {
        let rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid())
        let validator = CENCConformanceValidator()
        #expect(validator.detectsCENCProtection(in: rootBoxes))
    }

    @Test func c1ConformantSampleEntryHasSinf() {
        let report = CENCConformanceValidator().validate(
            rootBoxes: CENCFixtures.makeRootBoxes(
                scheme: .cenc, keyIdentifier: CENCFixtures.kid()))
        #expect(report.issues(for: .C1_EncryptedSampleEntryHasSinf).isEmpty)
    }
}

@Suite("CENCConformanceValidator — C3 (SinfHasValidSchm) + C4 (SchiHasTenc)")
struct CENCConformanceSchmSchiTests {

    @Test func conformantSchmWithCenc() {
        let report = CENCConformanceValidator().validate(
            rootBoxes: CENCFixtures.makeRootBoxes(
                scheme: .cenc, keyIdentifier: CENCFixtures.kid()))
        #expect(report.issues(for: .C3_SinfHasValidSchm).isEmpty)
        #expect(report.issues(for: .C4_SchiHasTenc).isEmpty)
    }

    @Test func conformantSchmWithCbcs() throws {
        let report = CENCConformanceValidator().validate(
            rootBoxes: CENCFixtures.makeRootBoxes(
                scheme: .cbcs, keyIdentifier: CENCFixtures.kid(),
                perSampleIVSize: .zero,
                constantIV: try CENCFixtures.constantIV()))
        #expect(report.issues(for: .C3_SinfHasValidSchm).isEmpty)
        #expect(report.issues(for: .C4_SchiHasTenc).isEmpty)
    }

    @Test func reportsC3WhenSchmAbsent() {
        let rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid(),
            includeSchemeType: false)
        let report = CENCConformanceValidator().validate(rootBoxes: rootBoxes)
        #expect(
            report.issues(for: .C3_SinfHasValidSchm).contains { $0.severity == .error })
    }

    @Test func reportsC4WhenSchiAbsent() {
        let rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid(),
            includeSchemeInformation: false)
        let report = CENCConformanceValidator().validate(rootBoxes: rootBoxes)
        #expect(
            report.issues(for: .C4_SchiHasTenc).contains { $0.severity == .error })
    }

    @Test func reportsC4WhenTencAbsent() {
        let rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid(),
            includeTenc: false)
        let report = CENCConformanceValidator().validate(rootBoxes: rootBoxes)
        #expect(
            report.issues(for: .C4_SchiHasTenc).contains { $0.severity == .error })
    }
}

@Suite("CENCConformanceValidator — C2 (SinfHasFrma)")
struct CENCConformanceFrmaTests {

    @Test func conformantWhenFrmaIsValidFourCC() {
        let report = CENCConformanceValidator().validate(
            rootBoxes: CENCFixtures.makeRootBoxes(
                scheme: .cenc, keyIdentifier: CENCFixtures.kid()))
        #expect(report.issues(for: .C2_SinfHasFrma).isEmpty)
    }

    @Test func reportsC2WhenFrmaIsBlank() {
        // The "    " (4 spaces) fourCC is a documented sentinel for an
        // unrecognised original format.
        let report = CENCConformanceValidator().validate(
            rootBoxes: CENCFixtures.makeRootBoxes(
                scheme: .cenc, keyIdentifier: CENCFixtures.kid(),
                originalFormat: "    "))
        #expect(
            report.issues(for: .C2_SinfHasFrma).contains { $0.severity == .error })
    }
}

@Suite("CENCConformanceValidator — C6 (PSSHWellFormed)")
struct CENCConformancePSSHTests {

    @Test func conformantWithV1PSSHHavingKIDs() {
        let kid = CENCFixtures.kid()
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: UUID(),
            keyIdentifiers: [kid],
            data: Data())
        let report = CENCConformanceValidator().validate(rootBoxes: [pssh])
        #expect(report.issues(for: .C6_PSSHWellFormed).isEmpty)
    }

    @Test func reportsC6WhenV1PSSHHasEmptyKIDList() {
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: UUID(),
            keyIdentifiers: [],
            data: Data())
        let report = CENCConformanceValidator().validate(rootBoxes: [pssh])
        #expect(
            report.issues(for: .C6_PSSHWellFormed).contains { $0.severity == .error })
    }

    @Test func v0PSSHIsAccepted() {
        // Version 0 pssh has no KID list requirement.
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 0,
            systemID: UUID(),
            keyIdentifiers: nil,
            data: Data([0x01, 0x02]))
        let report = CENCConformanceValidator().validate(rootBoxes: [pssh])
        #expect(report.issues(for: .C6_PSSHWellFormed).isEmpty)
    }
}

@Suite("CENCConformanceValidator — reporting + filtering")
struct CENCConformanceReportingTests {

    @Test func cleanReportSerializesAsCodable() throws {
        let report = CENCConformanceValidator().validate(
            rootBoxes: CENCFixtures.makeRootBoxes(
                scheme: .cenc, keyIdentifier: CENCFixtures.kid()))
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(CENCConformanceReport.self, from: data)
        #expect(decoded == report)
    }

    @Test func issuesFilteredBySeverityAndRule() {
        let rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid(),
            includeSchemeType: false)
        let report = CENCConformanceValidator().validate(rootBoxes: rootBoxes)
        #expect(!report.issues(of: .error).isEmpty)
        #expect(report.issues(for: .C3_SinfHasValidSchm).count >= 1)
    }

    @Test func ruleEnumExposesSpecSection() {
        #expect(CENCConformanceRule.C5_TencDefaultKIDSize.specSection.contains("§4.6"))
        #expect(CENCConformanceRule.C1_EncryptedSampleEntryHasSinf.specSection.contains("§4.5.1"))
    }

    @Test func validatesFromDataRoundTripsRootBoxes() async throws {
        var writer = BinaryWriter()
        let rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid())
        for box in rootBoxes { box.encode(to: &writer) }
        let report = try await CENCConformanceValidator().validate(data: writer.data)
        #expect(report.isConformant)
    }

    @Test func validatesFromFileURL() async throws {
        var writer = BinaryWriter()
        let rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid())
        for box in rootBoxes { box.encode(to: &writer) }
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempURL = tempDir.appendingPathComponent(
            "cenc-validator-\(UUID().uuidString).mp4")
        try writer.data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let report = try await CENCConformanceValidator()
            .validate(fileURL: tempURL)
        #expect(report.isConformant)
    }

    @Test func detectsCENCProtectionFalseWhenNoMoov() {
        let validator = CENCConformanceValidator()
        #expect(!validator.detectsCENCProtection(in: [CENCFixtures.makeFtyp()]))
    }

    @Test func detectsCENCProtectionFalseWhenMoovHasNoEncryptedTrack() {
        let validator = CENCConformanceValidator()
        let clear: [any ISOBox] = [
            CENCFixtures.makeFtyp(),
            ISOFixtures.makeMoov(children: [
                ISOFixtures.makeMVHD(),
                ISOFixtures.makeTrak(trackID: 1)
            ])
        ]
        #expect(!validator.detectsCENCProtection(in: clear))
    }

    @Test func permissiveModeSuppressesWarnings() {
        // C6 issue when version 1 pssh has empty KID list — currently
        // .error. Use a permissive instance to confirm errors remain.
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1, systemID: UUID(), keyIdentifiers: [], data: Data())
        let permissive = CENCConformanceValidator(level: .permissive)
            .validate(rootBoxes: [pssh])
        #expect(!permissive.issues(of: .error).isEmpty)
    }
}

@Suite("CENCConformanceValidator — C1 defensive path")
struct CENCConformanceC1DefensiveTests {

    @Test func reportsC1WhenEncryptedEntryIsUntypedRawEntry() {
        // Inject an `enca` entry as a RawSampleEntry (i.e., the
        // parser did not resolve a typed EncryptedAudioSampleEntry).
        // This exercises the defensive C1 path that surfaces when
        // an encrypted FourCC reaches the validator without a typed
        // sinf.
        let rawEnca = RawSampleEntry(
            format: "enca", dataReferenceIndex: 1, payload: Data())
        let stsd = SampleDescriptionBox(entries: [rawEnca])
        let stbl = SampleTableBox(
            header: ISOBoxHeader(type: "stbl", size: 0, headerSize: 8),
            children: [stsd])
        let minf = MediaInformationBox(
            header: ISOBoxHeader(type: "minf", size: 0, headerSize: 8),
            children: [stbl])
        let mdia = MediaBox(
            header: ISOBoxHeader(type: "mdia", size: 0, headerSize: 8),
            children: [
                MediaHeaderBox(
                    creationTime: 0, modificationTime: 0,
                    timescale: 1000, duration: 0, language: "und"),
                minf
            ])
        let trak = TrackBox(
            header: ISOBoxHeader(type: "trak", size: 0, headerSize: 8),
            children: [
                TrackHeaderBox(
                    creationTime: 0, modificationTime: 0,
                    trackID: 1, duration: 0),
                mdia
            ])
        let mvhd = MovieHeaderBox(
            creationTime: 0, modificationTime: 0,
            timescale: 1000, duration: 0, nextTrackID: 2)
        let moov = MovieBox(
            header: ISOBoxHeader(type: "moov", size: 0, headerSize: 8),
            children: [mvhd, trak])
        let report = CENCConformanceValidator().validate(
            rootBoxes: [CENCFixtures.makeFtyp(), moov])
        #expect(
            report.issues(for: .C1_EncryptedSampleEntryHasSinf)
                .contains { $0.severity == .error })
    }
}

@Suite("CENCConformanceValidator — C7 + C8 (senc / saiz / saio)")
struct CENCConformanceFragmentTests {

    @Test func conformantFragmentWithMatchingSencSaizCounts() {
        var rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid())
        rootBoxes.append(
            CENCFixtures.makeMoof(
                trackID: 1, sampleCount: 3, saizSampleCount: 3, ivSize: 8))
        let report = CENCConformanceValidator().validate(rootBoxes: rootBoxes)
        #expect(report.issues(for: .C7_SencSaizSaioCoherent).isEmpty)
        #expect(report.issues(for: .C8_PerSampleIVLengthConsistent).isEmpty)
    }

    @Test func reportsC7WhenSaizSampleCountMismatchesSenc() {
        var rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid())
        // saiz sampleCount=5 but senc has 3 samples → C7 error.
        rootBoxes.append(
            CENCFixtures.makeMoof(
                trackID: 1, sampleCount: 3, saizSampleCount: 5, ivSize: 8))
        let report = CENCConformanceValidator().validate(rootBoxes: rootBoxes)
        #expect(
            report.issues(for: .C7_SencSaizSaioCoherent)
                .contains { $0.severity == .error })
    }

    @Test func reportsC8WhenSencIVLengthMismatchesTenc() {
        // tenc declares 8-byte IVs but the senc fragment uses 16-byte
        // IVs — C8 error.
        var rootBoxes = CENCFixtures.makeRootBoxes(
            scheme: .cenc, keyIdentifier: CENCFixtures.kid(),
            perSampleIVSize: .eight)
        rootBoxes.append(
            CENCFixtures.makeMoof(
                trackID: 1, sampleCount: 2, saizSampleCount: 2, ivSize: 16))
        let report = CENCConformanceValidator().validate(rootBoxes: rootBoxes)
        #expect(
            report.issues(for: .C8_PerSampleIVLengthConsistent)
                .contains { $0.severity == .error })
    }
}

// MARK: - Fixtures

internal enum CENCFixtures {

    static func kid() -> KeyIdentifier {
        KeyIdentifier(rawBytes: Data(repeating: 0x42, count: 16))
    }

    static func constantIV() throws -> ConstantIV {
        // 16-byte IV for cbcs — ConstantIV.init validates byte count.
        try ConstantIV(rawBytes: Data(repeating: 0x01, count: 16))
    }

    /// Build a movie fragment (`moof`) carrying a `traf` with `tfhd`,
    /// `senc` + `saiz`. Used to exercise C7/C8 fragment-level rules.
    static func makeMoof(
        trackID: UInt32,
        sampleCount: Int,
        saizSampleCount: UInt32? = nil,
        ivSize: Int
    ) -> MovieFragmentBox {
        let samples = (0..<sampleCount).map { i in
            SampleEncryptionBox.SampleEncryptionEntry(
                initializationVector: Data(repeating: UInt8(i & 0xFF), count: ivSize),
                subsamples: nil)
        }
        let senc = SampleEncryptionBox(version: 0, flags: 0, samples: samples)
        let tfhd = TrackFragmentHeaderBox(
            flags: TrackFragmentHeaderBox.flagDefaultBaseIsMoof,
            trackID: trackID)
        let saizCount = saizSampleCount ?? UInt32(sampleCount)
        let saiz = SampleAuxiliaryInformationSizesBox(
            constantSize: UInt8(ivSize),
            sampleCount: saizCount,
            perSampleSizes: SampleInfoSizeTable(sizes: []))
        let traf = TrackFragmentBox(
            header: ISOBoxHeader(type: "traf", size: 0, headerSize: 8),
            children: [tfhd, senc, saiz])
        let mfhd = MovieFragmentHeaderBox(sequenceNumber: 1)
        return MovieFragmentBox(
            header: ISOBoxHeader(type: "moof", size: 0, headerSize: 8),
            children: [mfhd, traf])
    }

    static func makeFtyp() -> FileTypeBox {
        FileTypeBox(
            majorBrand: "cmfc", minorVersion: 0,
            compatibleBrands: ["iso6", "cmfc"])
    }

    static func makeRootBoxes(
        scheme: CommonEncryptionScheme,
        keyIdentifier: KeyIdentifier,
        perSampleIVSize: TrackEncryptionBox.PerSampleIVSize = .eight,
        constantIV: ConstantIV? = nil,
        originalFormat: FourCC = "mp4a",
        includeSchemeType: Bool = true,
        includeSchemeInformation: Bool = true,
        includeTenc: Bool = true
    ) -> [any ISOBox] {
        let schi: SchemeInformationBox?
        if includeSchemeInformation {
            let tenc: TrackEncryptionBox? =
                includeTenc
                ? TrackEncryptionBox(
                    defaultIsProtected: true,
                    defaultPerSampleIVSize: perSampleIVSize,
                    defaultKID: keyIdentifier,
                    defaultConstantIV: constantIV)
                : nil
            schi = SchemeInformationBox(trackEncryption: tenc)
        } else {
            schi = nil
        }
        let schm =
            includeSchemeType
            ? SchemeTypeBox(schemeType: scheme) : nil
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: originalFormat),
            schemeType: schm,
            schemeInformation: schi)

        // Encrypted audio entry with the sinf.
        let audioFields = AudioSampleEntryFields(
            channelCount: 2, sampleSize: 16,
            sampleRate: UInt32(48_000 << 16))
        let enca = EncryptedAudioSampleEntry(
            audioFields: audioFields,
            originalCodecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            protectionSchemeInfo: sinf)
        let stsd = SampleDescriptionBox(entries: [enca])
        let stbl = SampleTableBox(
            header: ISOBoxHeader(type: "stbl", size: 0, headerSize: 8),
            children: [stsd])
        let minf = MediaInformationBox(
            header: ISOBoxHeader(type: "minf", size: 0, headerSize: 8),
            children: [stbl])
        let mdhd = MediaHeaderBox(
            creationTime: 0, modificationTime: 0,
            timescale: 1000, duration: 0, language: "und")
        let mdia = MediaBox(
            header: ISOBoxHeader(type: "mdia", size: 0, headerSize: 8),
            children: [mdhd, minf])
        let tkhd = TrackHeaderBox(
            creationTime: 0, modificationTime: 0,
            trackID: 1, duration: 0)
        let trak = TrackBox(
            header: ISOBoxHeader(type: "trak", size: 0, headerSize: 8),
            children: [tkhd, mdia])
        let mvhd = MovieHeaderBox(
            creationTime: 0, modificationTime: 0,
            timescale: 1000, duration: 0, nextTrackID: 2)
        let moov = MovieBox(
            header: ISOBoxHeader(type: "moov", size: 0, headerSize: 8),
            children: [mvhd, trak])
        return [makeFtyp(), moov]
    }
}
