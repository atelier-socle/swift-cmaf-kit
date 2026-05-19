// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCShortTermRefPicSet")
struct HEVCShortTermRefPicSetTests {

    private static func roundTrip(
        _ rps: HEVCShortTermRefPicSet,
        indexInSPS: UInt32,
        previousRefPicSets: [HEVCShortTermRefPicSet]
    ) throws -> HEVCShortTermRefPicSet {
        var writer = BitWriter()
        rps.encode(
            to: &writer,
            indexInSPS: indexInSPS,
            previousRefPicSets: previousRefPicSets
        )
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        return try HEVCShortTermRefPicSet.parse(
            reader: &reader,
            indexInSPS: indexInSPS,
            previousRefPicSets: previousRefPicSets
        )
    }

    @Test
    func emptyExplicitRoundTrip() throws {
        let rps = HEVCShortTermRefPicSet(form: .explicit(negativePics: [], positivePics: []))
        let decoded = try Self.roundTrip(rps, indexInSPS: 0, previousRefPicSets: [])
        #expect(decoded == rps)
        #expect(decoded.numDeltaPocs == 0)
    }

    @Test
    func explicitNegativePositiveRoundTrip() throws {
        let rps = HEVCShortTermRefPicSet(
            form: .explicit(
                negativePics: [
                    HEVCShortTermRefPicSet.DeltaPOCEntry(
                        deltaPocMinus1: 0, usedByCurrPicFlag: true
                    ),
                    HEVCShortTermRefPicSet.DeltaPOCEntry(
                        deltaPocMinus1: 1, usedByCurrPicFlag: false
                    )
                ],
                positivePics: [
                    HEVCShortTermRefPicSet.DeltaPOCEntry(
                        deltaPocMinus1: 0, usedByCurrPicFlag: true
                    )
                ]
            )
        )
        let decoded = try Self.roundTrip(rps, indexInSPS: 0, previousRefPicSets: [])
        #expect(decoded == rps)
        #expect(decoded.numDeltaPocs == 3)
    }

    @Test
    func interRPSPredictionRoundTrip() throws {
        // First RPS with 2 negative + 0 positive = 2 delta POCs.
        let first = HEVCShortTermRefPicSet(
            form: .explicit(
                negativePics: [
                    HEVCShortTermRefPicSet.DeltaPOCEntry(
                        deltaPocMinus1: 0, usedByCurrPicFlag: true
                    ),
                    HEVCShortTermRefPicSet.DeltaPOCEntry(
                        deltaPocMinus1: 1, usedByCurrPicFlag: true
                    )
                ],
                positivePics: []
            )
        )
        // Inter-RPS prediction must produce numDeltaPocs+1 = 3 flags.
        let interRPS = HEVCShortTermRefPicSet(
            form: .interRPS(
                deltaIdxMinus1: 0,
                deltaRPSSign: false,
                absDeltaRPSMinus1: 0,
                usedByCurrPicFlags: [true, false, true],
                useDeltaFlags: [nil, true, nil]
            )
        )
        let decoded = try Self.roundTrip(
            interRPS, indexInSPS: 1, previousRefPicSets: [first]
        )
        #expect(decoded == interRPS)
        #expect(decoded.numDeltaPocs == 3)
    }

    @Test
    func chainedExplicitRPSes() throws {
        // 3 explicit RPSes in sequence.
        let r0 = HEVCShortTermRefPicSet(
            form: .explicit(
                negativePics: [
                    HEVCShortTermRefPicSet.DeltaPOCEntry(
                        deltaPocMinus1: 0, usedByCurrPicFlag: true
                    )
                ],
                positivePics: []
            )
        )
        let r1 = HEVCShortTermRefPicSet(
            form: .explicit(
                negativePics: [],
                positivePics: [
                    HEVCShortTermRefPicSet.DeltaPOCEntry(
                        deltaPocMinus1: 1, usedByCurrPicFlag: false
                    )
                ]
            )
        )
        let decoded0 = try Self.roundTrip(r0, indexInSPS: 0, previousRefPicSets: [])
        let decoded1 = try Self.roundTrip(r1, indexInSPS: 1, previousRefPicSets: [r0])
        #expect(decoded0 == r0)
        #expect(decoded1 == r1)
    }

    @Test
    func numDeltaPocsForInterRPSMatchesUsedFlags() {
        let rps = HEVCShortTermRefPicSet(
            form: .interRPS(
                deltaIdxMinus1: 0,
                deltaRPSSign: false,
                absDeltaRPSMinus1: 0,
                usedByCurrPicFlags: [true, true, true, false],
                useDeltaFlags: [nil, nil, nil, true]
            )
        )
        #expect(rps.numDeltaPocs == 4)
    }
}
