// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Cross-session end-to-end showcase tests exercising the 0.1.1
// surface as it will be consumed by HLSKit 0.7.0, DASHKit 0.1.0,
// CMAFKitDRM, and the AudioStreamingEngine. Each test demonstrates
// one or more 0.1.1 primitives working in concert with the v0.1.0
// surface.
//
// Every API call here resolves to a real symbol shipped in Sessions
// 1-7 — zero invented citation.

import Foundation
import Testing

@testable import CMAFKit

@Suite("0.1.1 Showcase — RFC 6381 codec strings (Session 4)")
struct ShowcaseCodecStringsTests {

    @Test func ec3WithoutAtmosEmitsBareEc3String() throws {
        let substream = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: false,
            bsmod: .completeMain, acmod: .threeTwo,
            lfeon: true, dependentSubstreamCount: 0)
        let ec3 = EC3SpecificBox(
            dataRate: 384, independentSubstreams: [substream])
        #expect(!ec3.carriesDolbyAtmos)
        let config = CMAFTrackConfiguration(
            trackID: 1, kind: .audio, profile: .hls,
            timescale: 48_000, language: "und",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: .ec3, codecConfiguration: .ec3(ec3),
                channelCount: 6,
                sampleRate: UInt32(48_000 << 16),
                sampleSize: 16))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString == "ec-3")
    }

    @Test func ec3WithAtmosCarriesJOCFlag() throws {
        // Apple canonical: ec3_extension_type_a = 0x10 → complexity 16.
        let substream = EC3SpecificBox.IndependentSubstream(
            fscod: .freq48000, bsid: 16, asvc: false,
            bsmod: .completeMain, acmod: .threeTwo,
            lfeon: true, dependentSubstreamCount: 0)
        let ec3 = EC3SpecificBox(
            dataRate: 768,
            independentSubstreams: [substream],
            ec3ExtensionTypeA: 0x10)
        #expect(ec3.carriesDolbyAtmos)
        #expect(ec3.jocExtension == .bedAndObjects(complexityIndex: 16))
    }

    @Test func alacConfigYieldsAlacCodecString() throws {
        let alac = ALACSpecificBox(
            bitDepth: 16, numChannels: 2,
            maxFrameBytes: 4096, avgBitRate: 0, sampleRate: 44_100)
        let config = CMAFTrackConfiguration(
            trackID: 1, kind: .audio, profile: .hls,
            timescale: 44_100, language: "und",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: .alac, codecConfiguration: .alac(alac),
                channelCount: 2,
                sampleRate: UInt32(44_100 << 16),
                sampleSize: 16))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString == "alac")
    }

    @Test func integerPCMYieldsIpcmCodecString() throws {
        let pcm = PCMConfigurationBox(
            endianness: .littleEndian, pcmSampleSize: 24)
        let config = CMAFTrackConfiguration(
            trackID: 1, kind: .audio, profile: .hls,
            timescale: 48_000, language: "und",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: .ipcm, codecConfiguration: .integerPCM(pcm),
                channelCount: 2,
                sampleRate: UInt32(48_000 << 16),
                sampleSize: 24))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString == "ipcm")
    }

    @Test func floatingPointPCMYieldsFpcmCodecString() throws {
        let pcm = PCMConfigurationBox(
            endianness: .littleEndian, pcmSampleSize: 32)
        let config = CMAFTrackConfiguration(
            trackID: 1, kind: .audio, profile: .hls,
            timescale: 48_000, language: "und",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: .fpcm,
                codecConfiguration: .floatingPointPCM(pcm),
                channelCount: 2,
                sampleRate: UInt32(48_000 << 16),
                sampleSize: 32))
        let codecString = try RFC6381CodecStringBuilder().codecString(for: config)
        #expect(codecString == "fpcm")
    }
}

@Suite("0.1.1 Showcase — BCP 47 language tags (Session 5)")
struct ShowcaseBCP47Tests {

    @Test func parseCanonicalRFC5646Tag() throws {
        let tag = try BCP47LanguageTag("zh-Hant-TW")
        #expect(tag.canonicalForm == "zh-Hant-TW")
        #expect(tag.primaryLanguage == .iso639_1("zh"))
        #expect(tag.script?.code == "Hant")
        #expect(tag.region == .iso3166_1("TW"))
    }

    @Test func bibliographicCodeBridgesToTerminologicAndShortens() throws {
        // mdhd may carry the bibliographic form `fre` — the bridge
        // normalises to terminologic `fra` and prefers the shorter
        // ISO 639-1 alpha-2 (`fr`) per RFC 5646 §4.5.
        let tag = try BCP47LanguageTag.fromISO6392T("fre")
        #expect(tag.primaryLanguage == .iso639_1("fr"))
    }

    @Test func rfc4647LookupDropsTrailingSubtagsForBestMatch() throws {
        let tag = try BCP47LanguageTag("en")
        #expect(tag.matches("en-US-x-twain", scheme: .lookup))
    }

    @Test func mediaHeaderBoxExposesTypedAccessor() throws {
        let mdhd = MediaHeaderBox(
            version: 1, flags: 0,
            creationTime: 0, modificationTime: 0,
            timescale: 48_000, duration: 0,
            language: "fra")
        let tag = try mdhd.languageAsBCP47()
        #expect(tag.primaryLanguage == .iso639_1("fr"))
    }
}

@Suite("0.1.1 Showcase — Accessibility primitives (Session 5.5)")
struct ShowcaseAccessibilityTests {

    @Test func netflixStyleAudioDescription() throws {
        let metadata = AccessibilityMetadata(
            role: .description,
            features: [.audioDescription],
            characteristics: [.describesVideo],
            audioPurpose: .audioDescription,
            isAutoSelect: true,
            associatedLanguage: try BCP47LanguageTag("en-US"))
        #expect(metadata.canonicalDASHRoleValue == "description")
        #expect(metadata.audioPurpose?.dashSchemeValue == "1")
        #expect(
            metadata.allHLSCharacteristicURIs
                == ["public.accessibility.describes-video"])
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func bbcIPlayerClosedCaptions() throws {
        let metadata = AccessibilityMetadata(
            role: .captions,
            features: [.closedCaptions],
            characteristics: [
                .transcribesSpokenDialog, .describesMusicAndSound
            ],
            isAutoSelect: true,
            associatedLanguage: try BCP47LanguageTag("en-GB"))
        #expect(metadata.canonicalDASHRoleValue == "caption")
        #expect(
            metadata.allHLSCharacteristicURIs.contains(
                "public.accessibility.transcribes-spoken-dialog"))
        #expect(
            metadata.allHLSCharacteristicURIs.contains(
                "public.accessibility.describes-music-and-sound"))
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func ardZdfSignLanguageWithRegionalTag() throws {
        let metadata = AccessibilityMetadata(
            role: .sign,
            features: [.signLanguageInterpretation],
            signLanguage: try BCP47LanguageTag("gsg"))  // Deutsche Gebärdensprache
        #expect(metadata.canonicalDASHRoleValue == "sign")
        #expect(metadata.signLanguage?.primaryLanguage == .iso639_3("gsg"))
        #expect(metadata.carriesEUAccessibilityActFeature)
    }

    @Test func disneyPlusForcedSubtitlesNotAccessibilityFeature() throws {
        let metadata = AccessibilityMetadata(
            role: .forcedSubtitle,
            features: [.forcedSubtitles],
            isForced: true,
            associatedLanguage: try BCP47LanguageTag("en"))
        #expect(metadata.canonicalDASHRoleValue == "forced-subtitle")
        #expect(metadata.isForced)
        // Forced subtitles are not an EU AA-relevant accessibility feature.
        #expect(!metadata.carriesEUAccessibilityActFeature)
    }

    @Test func mediaSelectionRoleRoundTripsDASHValue() {
        // urn:mpeg:dash:role:2011 round-trip for the canonical cases.
        for (role, value) in [
            (MediaSelectionRole.main, "main"),
            (.description, "description"),
            (.captions, "caption"),
            (.forcedSubtitle, "forced-subtitle"),
            (.sign, "sign"),
            (.enhancedAudioIntelligibility, "enhanced-audio-intelligibility")
        ] {
            #expect(role.dashRoleValue == value)
            #expect(MediaSelectionRole.fromDASHRoleValue(value) == role)
        }
    }

    @Test func tvaAudioPurposeRoundTrip() throws {
        for purpose in AudioPurpose.allCases {
            let back = try #require(
                AudioPurpose.fromDASHSchemeValue(purpose.dashSchemeValue))
            #expect(back == purpose)
        }
    }
}

@Suite("0.1.1 Showcase — Sample-entry round-trips (Session 6)")
struct ShowcaseSampleEntryTests {

    @Test func alacMagicCookieRoundTripsByteIdentically() async throws {
        let original = ALACSpecificBox(
            bitDepth: 24, numChannels: 6,
            maxFrameBytes: 16_384,
            avgBitRate: 4_608_000,
            sampleRate: 48_000)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = BoxRegistry()
        await registry.register(ALACSpecificBox.self) { reader, header, registry in
            try await ALACSpecificBox.parse(
                reader: &reader, header: header, registry: registry)
        }
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ALACSpecificBox)
        #expect(parsed == original)
    }

    @Test func ipcmSampleEntryDispatchesViaRegistry() async throws {
        let entry = IntegerPCMSampleEntry(
            audioFields: AudioSampleEntryFields(
                channelCount: 2, sampleSize: 16,
                sampleRate: UInt32(48_000 << 16)),
            pcmConfiguration: PCMConfigurationBox(
                endianness: .littleEndian, pcmSampleSize: 16))
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is IntegerPCMSampleEntry)
    }

    @Test func alacSampleEntryDispatchesAndManuallyParsesInnerBox() async throws {
        // The `alac` fourCC collision is resolved by ALACSampleEntry
        // reading the inner magic cookie manually.
        let entry = ALACSampleEntry(
            audioFields: AudioSampleEntryFields(
                channelCount: 2, sampleSize: 16,
                sampleRate: UInt32(44_100 << 16)),
            specificBox: ALACSpecificBox(
                bitDepth: 16, numChannels: 2,
                maxFrameBytes: 4096, avgBitRate: 0,
                sampleRate: 44_100))
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ALACSampleEntry)
        #expect(parsed == entry)
    }
}

@Suite("0.1.1 Showcase — Validators (Session 7)")
struct ShowcaseValidatorTests {

    @Test func standaloneISOValidatorAcceptsWellFormedInitSegment() {
        let ftyp = FileTypeBox(
            majorBrand: "cmfc", minorVersion: 0,
            compatibleBrands: ["iso6", "cmfc"])
        let mvhd = MovieHeaderBox(
            creationTime: 0, modificationTime: 0,
            timescale: 1000, duration: 0, nextTrackID: 2)
        let tkhd = TrackHeaderBox(
            creationTime: 0, modificationTime: 0,
            trackID: 1, duration: 0)
        let mdhd = MediaHeaderBox(
            version: 1, flags: 0,
            creationTime: 0, modificationTime: 0,
            timescale: 1000, duration: 0, language: "und")
        let mdia = MediaBox(
            header: ISOBoxHeader(type: "mdia", size: 0, headerSize: 8),
            children: [mdhd])
        let trak = TrackBox(
            header: ISOBoxHeader(type: "trak", size: 0, headerSize: 8),
            children: [tkhd, mdia])
        let moov = MovieBox(
            header: ISOBoxHeader(type: "moov", size: 0, headerSize: 8),
            children: [mvhd, trak])

        let report = ISOConformanceValidator(level: .strict)
            .validate(rootBoxes: [ftyp, moov])
        #expect(report.isConformant)
    }

    @Test func cencValidatorDetectsClearFile() {
        let ftyp = FileTypeBox(
            majorBrand: "cmfc", minorVersion: 0,
            compatibleBrands: ["iso6", "cmfc"])
        let validator = CENCConformanceValidator()
        #expect(!validator.detectsCENCProtection(in: [ftyp]))
    }

    @Test func cmafValidatorExposesCompositionAccessors() {
        let validator = CMAFConformanceValidator()
        #expect(validator.isoValidator.level == .strict)
        #expect(validator.cencValidator.level == .strict)
    }
}

@Suite("0.1.1 Showcase — Cross-session integration")
struct ShowcaseCrossSessionTests {

    @Test func trackConfigurationCarriesBothBCP47AndAccessibility() throws {
        // Session 5 (BCP 47) + Session 5.5 (Accessibility) wired
        // together on a single CMAFTrackConfiguration.
        let metadata = AccessibilityMetadata(
            role: .captions,
            features: [.closedCaptions],
            characteristics: [
                .transcribesSpokenDialog, .describesMusicAndSound
            ],
            isAutoSelect: true)
        let config = CMAFTrackConfiguration(
            trackID: 1, kind: .subtitle, profile: .hls,
            timescale: 1000, language: "fra",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: .webVTT, language: "eng",
                accessibility: metadata),
            accessibility: metadata)
        // Session 5 — typed BCP 47 view via additive extension.
        #expect(config.bcp47Language?.primaryLanguage == .iso639_1("fr"))
        #expect(config.subtitleFields?.bcp47Language?.primaryLanguage == .iso639_1("en"))
        // Session 5.5 — accessibility wired on both levels.
        #expect(config.accessibility?.role == .captions)
        #expect(config.subtitleFields?.accessibility?.role == .captions)
        #expect(config.accessibility?.carriesEUAccessibilityActFeature == true)
    }

    @Test func appleSpatialVideoStereoAudioCarriesEmptyAccessibility() {
        let metadata = AccessibilityMetadata.empty
        #expect(metadata.canonicalDASHRoleValue == nil)
        #expect(metadata.allHLSCharacteristicURIs.isEmpty)
        #expect(!metadata.carriesEUAccessibilityActFeature)
    }
}
