// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for EncodedCodec — discriminated union over every codec CMAFKit handles.

import Foundation
import Testing

@testable import CMAFKit

@Suite("EncodedCodec")
struct EncodedCodecTests {

    @Test
    func caseEqualityAcrossAllCases() {
        let cases: [EncodedCodec] = [
            .h264, .h265, .h265MultiLayer, .av1,
            .proRes(.standard), .motionJPEG,
            .aac(.lc), .ac3, .eac3,
            .opus, .flac, .alac, .mp3,
            .pcm(.int16LE), .vvc
        ]
        // Each case equals itself.
        for codec in cases {
            #expect(codec == codec)
        }
        // No two distinct cases are equal.
        for index in 0..<cases.count {
            for other in (index + 1)..<cases.count {
                #expect(cases[index] != cases[other])
            }
        }
    }

    @Test
    func aacProfilePayloadDiscriminates() {
        #expect(EncodedCodec.aac(.lc) != .aac(.sbr))
        #expect(EncodedCodec.aac(.psSBR) != .aac(.xHE))
        #expect(EncodedCodec.aac(.lc) == .aac(.lc))
    }

    @Test
    func proResFlavorPayloadDiscriminates() {
        #expect(EncodedCodec.proRes(.proxy) != .proRes(.standard))
        #expect(EncodedCodec.proRes(.ap4h) != .proRes(.ap4x))
        #expect(EncodedCodec.proRes(.hq) == .proRes(.hq))
    }

    @Test
    func setMembershipDeduplicates() {
        let set: Set<EncodedCodec> = [
            .h264, .h264,
            .aac(.lc), .aac(.lc), .aac(.sbr),
            .pcm(.int16LE)
        ]
        #expect(set.count == 4)  // h264, aac(.lc), aac(.sbr), pcm(.int16LE)
        #expect(set.contains(.h264))
        #expect(set.contains(.aac(.lc)))
        #expect(set.contains(.aac(.sbr)))
        #expect(set.contains(.pcm(.int16LE)))
    }

    @Test
    func hashableConsistency() {
        let a: EncodedCodec = .aac(.lc)
        let b: EncodedCodec = .aac(.lc)
        #expect(a.hashValue == b.hashValue)
    }
}
