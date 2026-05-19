// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AC4PresentationInfo")
struct AC4PresentationInfoTests {

    @Test
    func minimalConstruction() {
        let info = AC4PresentationInfo(
            presentationConfig: 0,
            presentationVersion: 1,
            addEmdfSubstreamsFlag: false,
            mdcompat: 0,
            presentationGroupIndex: 0
        )
        #expect(info.presentationConfig == 0)
        #expect(info.presentationVersion == 1)
        #expect(info.substreamGroups.isEmpty)
    }

    @Test
    func withSubstreamGroupsConstruction() {
        let group = AC4SubstreamGroup(
            substreamGroupIndex: 0,
            substreamsPresent: true,
            channelCoded: true,
            numSubstreams: 1,
            substreams: [
                AC4SubstreamGroup.Substream(
                    codec: .ac4Audio,
                    channelMode: .five1,
                    dialogEnhancementEnabled: false
                )
            ],
            contentInfo: AC4SubstreamGroup.ContentInfo(
                contentType: .completeMain,
                languageTag: "eng"
            )
        )
        let info = AC4PresentationInfo(
            presentationConfig: 0,
            presentationVersion: 1,
            addEmdfSubstreamsFlag: false,
            mdcompat: 0,
            presentationGroupIndex: 0,
            substreamGroups: [group]
        )
        #expect(info.substreamGroups.count == 1)
        #expect(info.substreamGroups[0].substreams[0].channelMode == .five1)
        #expect(info.substreamGroups[0].contentInfo?.contentType == .completeMain)
        #expect(info.substreamGroups[0].contentInfo?.languageTag == "eng")
    }

    @Test
    func dialogEnhancementFlag() {
        let substream = AC4SubstreamGroup.Substream(
            codec: .ac4Audio,
            channelMode: .stereo,
            dialogEnhancementEnabled: true
        )
        #expect(substream.dialogEnhancementEnabled == true)
    }

    @Test
    func presNDotFieldFitsSevenBits() {
        let group = AC4SubstreamGroup(
            substreamGroupIndex: 0,
            substreamsPresent: false,
            presentationNonDot: 0x7F
        )
        #expect(group.presentationNonDot == 0x7F)
    }

    @Test
    func metadataSubstreamConstruction() {
        let substream = AC4SubstreamGroup.Substream(
            codec: .ac4Metadata,
            channelMode: nil,
            dialogEnhancementEnabled: false
        )
        #expect(substream.codec == .ac4Metadata)
        #expect(substream.channelMode == nil)
    }

    @Test
    func contentTypeAllCases() {
        #expect(AC4ContentType.allCases.count == 8)
        #expect(AC4ContentType.dialog.rawValue == 2)
        #expect(AC4ContentType.hearingImpaired.rawValue == 5)
    }

    @Test
    func channelModeAllCases() {
        #expect(AC4ChannelMode.allCases.count == 16)
        #expect(AC4ChannelMode.five1.rawValue == 4)
        #expect(AC4ChannelMode.twentyTwoPointTwo.rawValue == 15)
    }

    @Test
    func substreamCodecAllCases() {
        #expect(AC4SubstreamCodec.allCases.count == 8)
        #expect(AC4SubstreamCodec.ac4Audio.rawValue == 0)
        #expect(AC4SubstreamCodec.ac4Metadata.rawValue == 1)
    }

    @Test
    func equalityAndHashing() {
        let a = AC4PresentationInfo(
            presentationConfig: 0,
            presentationVersion: 1,
            addEmdfSubstreamsFlag: false,
            mdcompat: 0,
            presentationGroupIndex: 0
        )
        let b = AC4PresentationInfo(
            presentationConfig: 0,
            presentationVersion: 1,
            addEmdfSubstreamsFlag: false,
            mdcompat: 0,
            presentationGroupIndex: 0
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func substreamGroupEqualityAndHashing() {
        let g1 = AC4SubstreamGroup(substreamGroupIndex: 0)
        let g2 = AC4SubstreamGroup(substreamGroupIndex: 0)
        #expect(g1 == g2)
        #expect(g1.hashValue == g2.hashValue)
    }
}
