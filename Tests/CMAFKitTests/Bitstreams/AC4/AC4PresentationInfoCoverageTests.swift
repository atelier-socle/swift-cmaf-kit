// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AC4PresentationInfo coverage")
struct AC4PresentationInfoCoverageTests {

    private static func makeSubstream(
        codec: AC4SubstreamCodec = .ac4Audio,
        channelMode: AC4ChannelMode? = .stereo,
        dialogEnhancement: Bool = false
    ) -> AC4SubstreamGroup.Substream {
        AC4SubstreamGroup.Substream(
            codec: codec,
            channelMode: channelMode,
            dialogEnhancementEnabled: dialogEnhancement
        )
    }

    private static func makeGroup(
        index: UInt8 = 0,
        substreams: [AC4SubstreamGroup.Substream] = [makeSubstream()],
        contentInfo: AC4SubstreamGroup.ContentInfo? = nil,
        presentationNonDot: UInt8? = nil,
        hsfExt: Bool = false
    ) -> AC4SubstreamGroup {
        AC4SubstreamGroup(
            substreamGroupIndex: index,
            substreamsPresent: true,
            hsfExtension: hsfExt,
            channelCoded: true,
            numSubstreams: UInt8(substreams.count),
            substreams: substreams,
            contentInfo: contentInfo,
            presentationNonDot: presentationNonDot
        )
    }

    private static func makePresentation(
        groups: [AC4SubstreamGroup] = []
    ) -> AC4PresentationInfo {
        AC4PresentationInfo(
            presentationConfig: 0,
            presentationVersion: 1,
            addEmdfSubstreamsFlag: false,
            mdcompat: 0,
            presentationGroupIndex: 0,
            substreamGroups: groups
        )
    }

    @Test
    func minimalPresentationEquality() {
        let a = Self.makePresentation()
        let b = Self.makePresentation()
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func stereoPresentationWithContentInfoEnglish() {
        let group = Self.makeGroup(
            substreams: [Self.makeSubstream(channelMode: .stereo)],
            contentInfo: AC4SubstreamGroup.ContentInfo(
                contentType: .completeMain,
                languageTag: "en"
            )
        )
        let presentation = Self.makePresentation(groups: [group])
        #expect(presentation.substreamGroups[0].contentInfo?.languageTag == "en")
        #expect(presentation.substreamGroups[0].contentInfo?.contentType == .completeMain)
    }

    @Test
    func fivePointOnePresentationWithDialogEnhancement() {
        let group = Self.makeGroup(
            substreams: [Self.makeSubstream(channelMode: .five1, dialogEnhancement: true)]
        )
        let presentation = Self.makePresentation(groups: [group])
        #expect(presentation.substreamGroups[0].substreams[0].channelMode == .five1)
        #expect(presentation.substreamGroups[0].substreams[0].dialogEnhancementEnabled == true)
    }

    @Test
    func sevenOneSurroundWithFrenchLanguageTag() {
        let group = Self.makeGroup(
            substreams: [Self.makeSubstream(channelMode: .sevenOneSurround)],
            contentInfo: AC4SubstreamGroup.ContentInfo(
                contentType: .completeMain,
                languageTag: "fr"
            )
        )
        let presentation = Self.makePresentation(groups: [group])
        #expect(presentation.substreamGroups[0].contentInfo?.languageTag == "fr")
        #expect(presentation.substreamGroups[0].substreams[0].channelMode == .sevenOneSurround)
    }

    @Test
    func twentyTwoPointTwoVoiceoverContent() {
        let group = Self.makeGroup(
            substreams: [Self.makeSubstream(channelMode: .twentyTwoPointTwo)],
            contentInfo: AC4SubstreamGroup.ContentInfo(
                contentType: .voiceover, languageTag: "ja"
            )
        )
        let presentation = Self.makePresentation(groups: [group])
        #expect(presentation.substreamGroups[0].contentInfo?.contentType == .voiceover)
        #expect(presentation.substreamGroups[0].substreams[0].channelMode == .twentyTwoPointTwo)
    }

    @Test
    func dualSubstreamAudioPlusMetadata() {
        let audio = Self.makeSubstream(codec: .ac4Audio, channelMode: .stereo)
        let metadata = Self.makeSubstream(codec: .ac4Metadata, channelMode: nil)
        let group = Self.makeGroup(substreams: [audio, metadata])
        let presentation = Self.makePresentation(groups: [group])
        #expect(presentation.substreamGroups[0].numSubstreams == 2)
        #expect(presentation.substreamGroups[0].substreams[1].codec == .ac4Metadata)
        #expect(presentation.substreamGroups[0].substreams[1].channelMode == nil)
    }

    @Test
    func presentationWithPresNDot() {
        let group = Self.makeGroup(presentationNonDot: 42)
        let presentation = Self.makePresentation(groups: [group])
        #expect(presentation.substreamGroups[0].presentationNonDot == 42)
    }

    @Test
    func presentationWithHSFExtensionSet() {
        let group = Self.makeGroup(hsfExt: true)
        let presentation = Self.makePresentation(groups: [group])
        #expect(presentation.substreamGroups[0].hsfExtension == true)
    }

    @Test
    func presentationWithContentInfoNoLanguage() {
        let group = Self.makeGroup(
            contentInfo: AC4SubstreamGroup.ContentInfo(
                contentType: .music, languageTag: nil
            )
        )
        let presentation = Self.makePresentation(groups: [group])
        #expect(presentation.substreamGroups[0].contentInfo?.languageTag == nil)
        #expect(presentation.substreamGroups[0].contentInfo?.contentType == .music)
    }

    @Test
    func presentationWithLongLanguageTag() {
        let tag = "zh-Hans-CN-x-historical-traditional-supplement-extended"
        let group = Self.makeGroup(
            contentInfo: AC4SubstreamGroup.ContentInfo(
                contentType: .dialog, languageTag: tag
            )
        )
        let presentation = Self.makePresentation(groups: [group])
        #expect(presentation.substreamGroups[0].contentInfo?.languageTag == tag)
    }

    @Test
    func multipleSubstreamGroupsInPresentation() {
        let g1 = Self.makeGroup(index: 0)
        let g2 = Self.makeGroup(index: 1)
        let g3 = Self.makeGroup(index: 2)
        let presentation = Self.makePresentation(groups: [g1, g2, g3])
        #expect(presentation.substreamGroups.count == 3)
        #expect(presentation.substreamGroups[2].substreamGroupIndex == 2)
    }

    @Test
    func allChannelModesAccepted() {
        for mode in AC4ChannelMode.allCases {
            let group = Self.makeGroup(
                substreams: [Self.makeSubstream(channelMode: mode)]
            )
            #expect(group.substreams[0].channelMode == mode)
        }
    }

    @Test
    func allContentTypesAccepted() {
        for contentType in AC4ContentType.allCases {
            let group = Self.makeGroup(
                contentInfo: AC4SubstreamGroup.ContentInfo(
                    contentType: contentType, languageTag: nil
                )
            )
            #expect(group.contentInfo?.contentType == contentType)
        }
    }

    @Test
    func substreamGroupHashableAcrossVariants() {
        let g1 = Self.makeGroup(index: 0)
        let g2 = Self.makeGroup(index: 0)
        let g3 = Self.makeGroup(index: 1)
        #expect(g1 == g2)
        #expect(g1.hashValue == g2.hashValue)
        #expect(g1 != g3)
    }

    @Test
    func presentationEqualityDistinguishesNumSubstreams() {
        let g1 = Self.makeGroup(substreams: [Self.makeSubstream()])
        let g2 = Self.makeGroup(substreams: [Self.makeSubstream(), Self.makeSubstream()])
        let a = Self.makePresentation(groups: [g1])
        let b = Self.makePresentation(groups: [g2])
        #expect(a != b)
    }

    @Test
    func frameRateFieldsRoundTrip() {
        let presentation = AC4PresentationInfo(
            presentationConfig: 0,
            presentationVersion: 1,
            addEmdfSubstreamsFlag: false,
            mdcompat: 0,
            presentationGroupIndex: 0,
            frameRateMultiplyInfo: 1,
            frameRateFractionsInfo: 2
        )
        #expect(presentation.frameRateMultiplyInfo == 1)
        #expect(presentation.frameRateFractionsInfo == 2)
    }

    @Test
    func substreamConstructionAcrossCodecs() {
        for codec in AC4SubstreamCodec.allCases {
            let substream = AC4SubstreamGroup.Substream(
                codec: codec,
                channelMode: codec == .ac4Audio ? .stereo : nil,
                dialogEnhancementEnabled: false
            )
            #expect(substream.codec == codec)
        }
    }
}
