// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("MPEG4AudioObjectType")
struct MPEG4AudioObjectTypeTests {

    @Test
    func aacLCIsTwo() {
        #expect(MPEG4AudioObjectType.aacLC.rawValue == 2)
    }

    @Test
    func aacMainIsOne() {
        #expect(MPEG4AudioObjectType.aacMain.rawValue == 1)
    }

    @Test
    func sbrIsFive() {
        #expect(MPEG4AudioObjectType.sbr.rawValue == 5)
    }

    @Test
    func psIsTwentyNine() {
        #expect(MPEG4AudioObjectType.ps.rawValue == 29)
    }

    @Test
    func escapeIsThirtyOne() {
        #expect(MPEG4AudioObjectType.escape.rawValue == 31)
    }

    @Test
    func erAACELDIsThirtyNine() {
        #expect(MPEG4AudioObjectType.erAACELD.rawValue == 39)
    }

    @Test
    func usacIs45() {
        #expect(MPEG4AudioObjectType.usac.rawValue == 45)
    }

    @Test
    func unknownRejected() {
        #expect(MPEG4AudioObjectType(rawValue: 200) == nil)
    }

    @Test
    func reservedTenRejected() {
        #expect(MPEG4AudioObjectType(rawValue: 10) == nil)
    }

    @Test
    func atLeastFortyDocumentedCases() {
        #expect(MPEG4AudioObjectType.allCases.count >= 40)
    }
}

@Suite("MPEG4AudioSamplingFrequencyIndex")
struct MPEG4AudioSamplingFrequencyIndexTests {

    @Test
    func index96000IsZero() {
        #expect(MPEG4AudioSamplingFrequencyIndex.freq96000.rawValue == 0)
    }

    @Test
    func index48000IsThree() {
        #expect(MPEG4AudioSamplingFrequencyIndex.freq48000.rawValue == 3)
    }

    @Test
    func index44100IsFour() {
        #expect(MPEG4AudioSamplingFrequencyIndex.freq44100.rawValue == 4)
    }

    @Test
    func index8000IsEleven() {
        #expect(MPEG4AudioSamplingFrequencyIndex.freq8000.rawValue == 11)
    }

    @Test
    func escapeIsFifteen() {
        #expect(MPEG4AudioSamplingFrequencyIndex.escape.rawValue == 15)
    }

    @Test
    func sixteenCases() {
        #expect(MPEG4AudioSamplingFrequencyIndex.allCases.count == 16)
    }

    @Test
    func hzValueForFreq48000() {
        #expect(MPEG4AudioSamplingFrequencyIndex.freq48000.hzValue == 48000)
    }

    @Test
    func hzValueForEscapeIsNil() {
        #expect(MPEG4AudioSamplingFrequencyIndex.escape.hzValue == nil)
    }
}

@Suite("MPEG4ChannelConfiguration")
struct MPEG4ChannelConfigurationTests {

    @Test
    func monoIsOne() {
        #expect(MPEG4ChannelConfiguration.mono.rawValue == 1)
    }

    @Test
    func fiveOneIsSix() {
        #expect(MPEG4ChannelConfiguration.fiveOne.rawValue == 6)
    }

    @Test
    func eightCases() {
        #expect(MPEG4ChannelConfiguration.allCases.count == 8)
    }

    @Test
    func unknownRejected() {
        #expect(MPEG4ChannelConfiguration(rawValue: 8) == nil)
    }

    @Test
    func definedInAOTConfigIsZero() {
        #expect(MPEG4ChannelConfiguration.definedInAOTConfig.rawValue == 0)
    }
}

@Suite("AC3FrameSizeCode")
struct AC3FrameSizeCodeTests {

    @Test
    func freq48000IsZero() {
        #expect(AC3FrameSizeCode.freq48000.rawValue == 0)
    }

    @Test
    func freq32000IsTwo() {
        #expect(AC3FrameSizeCode.freq32000.rawValue == 2)
    }

    @Test
    func reservedIsThree() {
        #expect(AC3FrameSizeCode.reserved.rawValue == 3)
    }

    @Test
    func fourCases() {
        #expect(AC3FrameSizeCode.allCases.count == 4)
    }
}

@Suite("AC3BitStreamMode")
struct AC3BitStreamModeTests {

    @Test
    func completeMainIsZero() {
        #expect(AC3BitStreamMode.completeMain.rawValue == 0)
    }

    @Test
    func dialogueIsFour() {
        #expect(AC3BitStreamMode.dialogue.rawValue == 4)
    }

    @Test
    func voiceOverIsSeven() {
        #expect(AC3BitStreamMode.voiceOverOrKaraoke.rawValue == 7)
    }

    @Test
    func eightCases() {
        #expect(AC3BitStreamMode.allCases.count == 8)
    }

    @Test
    func unknownRejected() {
        #expect(AC3BitStreamMode(rawValue: 8) == nil)
    }
}

@Suite("AC3AudioCodingMode")
struct AC3AudioCodingModeTests {

    @Test
    func monoIsOne() {
        #expect(AC3AudioCodingMode.mono.rawValue == 1)
    }

    @Test
    func stereoIsTwo() {
        #expect(AC3AudioCodingMode.stereo.rawValue == 2)
    }

    @Test
    func threeTwoIsSeven() {
        #expect(AC3AudioCodingMode.threeTwo.rawValue == 7)
    }

    @Test
    func dualMonoIsZero() {
        #expect(AC3AudioCodingMode.dualMono.rawValue == 0)
    }

    @Test
    func eightCases() {
        #expect(AC3AudioCodingMode.allCases.count == 8)
    }
}

@Suite("OpusChannelMappingFamily")
struct OpusChannelMappingFamilyTests {

    @Test
    func rtpMonoStereoIsZero() {
        #expect(OpusChannelMappingFamily.rtpMonoStereo.rawValue == 0)
    }

    @Test
    func vorbisIsOne() {
        #expect(OpusChannelMappingFamily.vorbisMultichannel.rawValue == 1)
    }

    @Test
    func ambisonicsIsTwo() {
        #expect(OpusChannelMappingFamily.ambisonics.rawValue == 2)
    }

    @Test
    func undefinedIs255() {
        #expect(OpusChannelMappingFamily.undefined.rawValue == 255)
    }
}

@Suite("FLACMetadataBlockType")
struct FLACMetadataBlockTypeTests {

    @Test
    func streamInfoIsZero() {
        #expect(FLACMetadataBlockType.streamInfo.rawValue == 0)
    }

    @Test
    func pictureIsSix() {
        #expect(FLACMetadataBlockType.picture.rawValue == 6)
    }

    @Test
    func vorbisCommentIsFour() {
        #expect(FLACMetadataBlockType.vorbisComment.rawValue == 4)
    }

    @Test
    func sevenCases() {
        #expect(FLACMetadataBlockType.allCases.count == 7)
    }
}

@Suite("MPEGHProfileLevelIndication")
struct MPEGHProfileLevelIndicationTests {

    @Test
    func mainProfileLevel1IsOne() {
        #expect(MPEGHProfileLevelIndication.mainProfileLevel1.rawValue == 0x01)
    }

    @Test
    func mainProfileLevel5IsFive() {
        #expect(MPEGHProfileLevelIndication.mainProfileLevel5.rawValue == 0x05)
    }

    @Test
    func highProfileLevel1IsSix() {
        #expect(MPEGHProfileLevelIndication.highProfileLevel1.rawValue == 0x06)
    }

    @Test
    func lcProfileLevel1IsEleven() {
        #expect(MPEGHProfileLevelIndication.lcProfileLevel1.rawValue == 0x0B)
    }

    @Test
    func baselineProfileLevel5Is20() {
        #expect(MPEGHProfileLevelIndication.baselineProfileLevel5.rawValue == 0x14)
    }

    @Test
    func twentyOneCases() {
        #expect(MPEGHProfileLevelIndication.allCases.count == 21)
    }

    @Test
    func unknownRejected() {
        #expect(MPEGHProfileLevelIndication(rawValue: 0xFF) == nil)
    }

    @Test
    func reserved0IsZero() {
        #expect(MPEGHProfileLevelIndication.reserved0.rawValue == 0x00)
    }
}

@Suite("PredefinedChannelLayout")
struct PredefinedChannelLayoutTests {

    @Test
    func monoIsOne() {
        #expect(PredefinedChannelLayout.mono.rawValue == 1)
    }

    @Test
    func stereoIsTwo() {
        #expect(PredefinedChannelLayout.stereo.rawValue == 2)
    }

    @Test
    func fiveOneIsSix() {
        #expect(PredefinedChannelLayout.fiveOne.rawValue == 6)
    }

    @Test
    func twentyTwoPointTwoIs17() {
        #expect(PredefinedChannelLayout.twentyTwoPointTwo.rawValue == 17)
    }

    @Test
    func sevenOneFourTopHeightIsNine() {
        #expect(PredefinedChannelLayout.sevenOneFourTopHeight.rawValue == 9)
    }

    @Test
    func twentyOneCases() {
        #expect(PredefinedChannelLayout.allCases.count == 21)
    }

    @Test
    func explicitlySignaledIsZero() {
        #expect(PredefinedChannelLayout.explicitlySignaled.rawValue == 0)
    }

    @Test
    func unknownRejected() {
        #expect(PredefinedChannelLayout(rawValue: 22) == nil)
    }
}

@Suite("SpeakerPosition")
struct SpeakerPositionTests {

    @Test
    func leftFrontIsZero() {
        #expect(SpeakerPosition.leftFront.rawValue == 0)
    }

    @Test
    func rightFrontIsOne() {
        #expect(SpeakerPosition.rightFront.rawValue == 1)
    }

    @Test
    func centerFrontIsTwo() {
        #expect(SpeakerPosition.centerFront.rawValue == 2)
    }

    @Test
    func lfeIsThree() {
        #expect(SpeakerPosition.lfe.rawValue == 3)
    }

    @Test
    func topCenterIs13() {
        #expect(SpeakerPosition.topCenter.rawValue == 13)
    }

    @Test
    func lfe2Is22() {
        #expect(SpeakerPosition.lfe2.rawValue == 22)
    }

    @Test
    func explicitIs126() {
        #expect(SpeakerPosition.explicit.rawValue == 126)
    }

    @Test
    func unknownRejected() {
        #expect(SpeakerPosition(rawValue: 200) == nil)
    }

    @Test
    func reserved127Rejected() {
        #expect(SpeakerPosition(rawValue: 127) == nil)
    }

    @Test
    func atLeastThirtyDocumentedCases() {
        #expect(SpeakerPosition.allCases.count >= 30)
    }

    @Test
    func rightSurroundDirectIs32() {
        #expect(SpeakerPosition.rightSurroundDirect.rawValue == 32)
    }

    @Test
    func leftWideFrontIs26() {
        #expect(SpeakerPosition.leftWideFront.rawValue == 26)
    }
}
