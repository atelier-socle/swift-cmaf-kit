// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("FLACStreamInfo")
struct FLACStreamInfoTests {

    private static func makeMD5() -> Data {
        Data(repeating: 0xAB, count: 16)
    }

    @Test
    func encodeIs34Bytes() {
        let info = FLACStreamInfo(
            minBlockSize: 4096,
            maxBlockSize: 4096,
            minFrameSize: 14,
            maxFrameSize: 4096,
            sampleRate: 48000,
            channels: 2,
            bitsPerSample: 16,
            totalSamples: 480000,
            md5: Self.makeMD5()
        )
        let encoded = info.encode()
        #expect(encoded.count == 34)
    }

    @Test
    func roundTripCDQuality() throws {
        let info = FLACStreamInfo(
            minBlockSize: 4096,
            maxBlockSize: 4096,
            minFrameSize: 14,
            maxFrameSize: 4096,
            sampleRate: 44100,
            channels: 2,
            bitsPerSample: 16,
            totalSamples: 441_000,
            md5: Self.makeMD5()
        )
        let parsed = try FLACStreamInfo.parse(blockData: info.encode())
        #expect(parsed == info)
    }

    @Test
    func roundTripHiRes24bit96k() throws {
        let info = FLACStreamInfo(
            minBlockSize: 4096,
            maxBlockSize: 4096,
            minFrameSize: 100,
            maxFrameSize: 16384,
            sampleRate: 96000,
            channels: 2,
            bitsPerSample: 24,
            totalSamples: 9_600_000,
            md5: Self.makeMD5()
        )
        let parsed = try FLACStreamInfo.parse(blockData: info.encode())
        #expect(parsed == info)
    }

    @Test
    func roundTripFiveOne24bit() throws {
        let info = FLACStreamInfo(
            minBlockSize: 4096,
            maxBlockSize: 4096,
            minFrameSize: 14,
            maxFrameSize: 32000,
            sampleRate: 48000,
            channels: 6,
            bitsPerSample: 24,
            totalSamples: 1_000_000,
            md5: Self.makeMD5()
        )
        let parsed = try FLACStreamInfo.parse(blockData: info.encode())
        #expect(parsed == info)
    }

    @Test
    func roundTripMaxSampleRate() throws {
        let info = FLACStreamInfo(
            minBlockSize: 16,
            maxBlockSize: 65535,
            minFrameSize: 0,
            maxFrameSize: 0x00FF_FFFF,
            sampleRate: 0x000F_FFFF,
            channels: 8,
            bitsPerSample: 32,
            totalSamples: 0x0000_000F_FFFF_FFFF,
            md5: Self.makeMD5()
        )
        let parsed = try FLACStreamInfo.parse(blockData: info.encode())
        #expect(parsed == info)
    }

    @Test
    func rejectsWrongLength() {
        let bad = Data(repeating: 0, count: 33)
        #expect(throws: ISOBoxError.self) {
            _ = try FLACStreamInfo.parse(blockData: bad)
        }
    }

    @Test
    func channelsBitsPackedCorrectly() throws {
        // channels=8 (raw=7 = 0b111), bps=32 (raw=31 = 0b11111).
        let info = FLACStreamInfo(
            minBlockSize: 1,
            maxBlockSize: 2,
            minFrameSize: 3,
            maxFrameSize: 4,
            sampleRate: 1,
            channels: 8,
            bitsPerSample: 32,
            totalSamples: 0,
            md5: Self.makeMD5()
        )
        let parsed = try FLACStreamInfo.parse(blockData: info.encode())
        #expect(parsed.channels == 8)
        #expect(parsed.bitsPerSample == 32)
    }

    @Test
    func md5Preserved() throws {
        let md5 = Data((0..<16).map { UInt8($0 * 16) })
        let info = FLACStreamInfo(
            minBlockSize: 4096,
            maxBlockSize: 4096,
            minFrameSize: 14,
            maxFrameSize: 4096,
            sampleRate: 48000,
            channels: 2,
            bitsPerSample: 16,
            totalSamples: 0,
            md5: md5
        )
        let parsed = try FLACStreamInfo.parse(blockData: info.encode())
        #expect(parsed.md5 == md5)
    }
}
