// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Shared fixtures for the CMAFKitCLI test suites. Each fixture
// produces a minimal CMAF init segment byte sequence by driving
// the writer side of CMAFKit. Tests then feed those bytes to the
// CLI report types directly (the CLI's data model is exposed via
// `*Report` Codable types — the ArgumentParser surface is
// exercised by the IntegrationTests suite).

import Foundation

@testable import CMAFKit
@testable import CMAFKitCLI
@testable import CMAFKitDRM

internal enum CLITestFixtures {

    /// Minimal AVC + AAC two-track init segment.
    static func avcPlusAACInitSegment() throws -> Data {
        let video = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920, height: 1080,
                codec: .avc1,
                codecConfiguration: .avc(makeAVCConfig()),
                frameRate: .init(numerator: 30, denominator: 1)
            )
        )
        let audio = CMAFTrackConfiguration(
            trackID: 2,
            kind: .audio,
            profile: .basic,
            timescale: 48_000,
            language: "eng",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: .mp4a,
                codecConfiguration: .mp4Audio(makeESDS()),
                channelCount: 2,
                sampleRate: 48_000
            )
        )
        return try CMAFInitSegmentWriter(configurations: [video, audio]).emit()
    }

    /// Init segment carrying a Widevine pssh box.
    static func avcWithWidevineInitSegment() throws -> Data {
        let widevineUUID = KnownDRMSystemID.widevine.uuid
        let kid = Data(repeating: 0xAA, count: 16)
        let payload: Data = try {
            var writer = ProtocolBufferWriter()
            writer.writeBytesField(fieldNumber: 2, value: kid)
            writer.writeVarintField(fieldNumber: 1, value: 1)  // algorithm = AESCTR
            return writer.data
        }()
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevineUUID,
            keyIdentifiers: [],
            data: payload
        )
        let enc = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: KeyIdentifier(rawBytes: kid),
            defaultPerSampleIVSize: .eight,
            psshBoxes: [pssh]
        )
        let video = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920, height: 1080,
                codec: .avc1,
                codecConfiguration: .avc(makeAVCConfig()),
                frameRate: .init(numerator: 30, denominator: 1)
            ),
            encryptionParameters: enc
        )
        return try CMAFInitSegmentWriter(configurations: [video]).emit()
    }

    /// Bytes that do not parse as a CMAF init segment.
    static let malformedBytes: Data = Data([0x00, 0x01, 0x02, 0x03])

    // MARK: - Codec factories

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
}
