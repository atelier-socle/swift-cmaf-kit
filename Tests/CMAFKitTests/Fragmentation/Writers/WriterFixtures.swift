// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Shared test fixtures for the high-level writer tests.

import Foundation

@testable import CMAFKit

internal enum WriterFixtures {

    static func makeAVCConfig() -> AVCDecoderConfigurationRecord {
        AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))],
            pictureParameterSets: [AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))]
        )
    }

    static func makeESDS() -> ElementaryStreamDescriptor {
        ElementaryStreamDescriptor(
            esID: 1,
            decoderConfig: ElementaryStreamDescriptor.DecoderConfigDescriptor(
                objectTypeIndication: .audioISO14496_3,
                streamType: .audioStream,
                upStream: false,
                bufferSizeDB: 1536,
                maxBitrate: 128_000,
                avgBitrate: 96_000,
                decoderSpecificInfo: Data([0x12, 0x10])
            )
        )
    }

    static func makeKID() -> KeyIdentifier {
        KeyIdentifier(rawBytes: Data(repeating: 0x77, count: 16))
    }

    static func videoConfig(
        trackID: UInt32 = 1,
        profile: CMAFProfile = .basic,
        encrypted: CMAFEncryptionParameters? = nil,
        priming: AudioPriming? = nil
    ) -> CMAFTrackConfiguration {
        _ = priming
        return CMAFTrackConfiguration(
            trackID: trackID,
            kind: .video,
            profile: profile,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920,
                height: 1080,
                codec: .avc1,
                codecConfiguration: .avc(makeAVCConfig()),
                frameRate: CMAFTrackConfiguration.VideoFields.FrameRate(
                    numerator: 30,
                    denominator: 1
                )
            ),
            encryptionParameters: encrypted
        )
    }

    static func audioConfig(
        trackID: UInt32 = 2,
        profile: CMAFProfile = .basic,
        encrypted: CMAFEncryptionParameters? = nil,
        priming: AudioPriming? = nil
    ) -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: trackID,
            kind: .audio,
            profile: profile,
            timescale: 48_000,
            language: "eng",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: .mp4a,
                codecConfiguration: .mp4Audio(makeESDS()),
                channelCount: 2,
                sampleRate: 48_000,
                priming: priming
            ),
            encryptionParameters: encrypted
        )
    }

    static func cencParameters() -> CMAFEncryptionParameters {
        CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: makeKID(),
            defaultPerSampleIVSize: .eight
        )
    }

    static func cbcsParameters() throws -> CMAFEncryptionParameters {
        CMAFEncryptionParameters(
            scheme: .cbcs,
            defaultKID: makeKID(),
            defaultPerSampleIVSize: .zero,
            defaultConstantIV: try ConstantIV(rawBytes: Data(repeating: 0x42, count: 16)),
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9
        )
    }

    static func videoSample(
        size: Int = 1024,
        durationInTimescale: UInt32 = 3000,
        isSync: Bool = true,
        encryption: CMAFSampleInput.EncryptionMetadata? = nil
    ) -> CMAFSampleInput {
        CMAFSampleInput(
            bytes: Data(repeating: 0xAB, count: size),
            durationInTimescale: durationInTimescale,
            flags: isSync ? .syncSample : .nonSyncSample,
            encryption: encryption
        )
    }

    static func encryptedVideoSample(
        size: Int = 1024,
        durationInTimescale: UInt32 = 3000,
        isSync: Bool = true,
        ivSize: Int = 8
    ) -> CMAFSampleInput {
        CMAFSampleInput(
            bytes: Data(repeating: 0xAB, count: size),
            durationInTimescale: durationInTimescale,
            flags: isSync ? .syncSample : .nonSyncSample,
            encryption: CMAFSampleInput.EncryptionMetadata(
                initializationVector: Data(repeating: 0x11, count: ivSize)
            )
        )
    }
}
