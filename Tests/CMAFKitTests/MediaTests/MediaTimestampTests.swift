// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for MediaTimestamp + rescale — ISO/IEC 14496-12 §8.4.2 timescale.
// Per addendum F.9, arithmetic discipline is integer-only; rescale throws on
// overflow rather than wrapping.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MediaTimestamp")
struct MediaTimestampTests {

    @Test
    func memberwiseConstruction() {
        let ts = MediaTimestamp(value: 12345, timescale: 90_000)
        #expect(ts.value == 12345)
        #expect(ts.timescale == 90_000)
    }

    @Test
    func secondsToValueRounding() {
        let ts = MediaTimestamp(seconds: 6.0, timescale: 90_000)
        #expect(ts.value == 540_000)
        #expect(ts.timescale == 90_000)
    }

    @Test
    func secondsAccessor() {
        let ts = MediaTimestamp(value: 90_000, timescale: 90_000)
        #expect(ts.seconds == 1.0)
    }

    @Test
    func additionWithMatchingTimescales() {
        let a = MediaTimestamp(value: 1000, timescale: 90_000)
        let b = MediaTimestamp(value: 2000, timescale: 90_000)
        let sum = a + b
        #expect(sum.value == 3000)
        #expect(sum.timescale == 90_000)
    }

    @Test
    func subtractionWithMatchingTimescales() {
        let a = MediaTimestamp(value: 5000, timescale: 1_000)
        let b = MediaTimestamp(value: 2000, timescale: 1_000)
        let diff = a - b
        #expect(diff.value == 3000)
        #expect(diff.timescale == 1_000)
    }

    @Test
    func rescaleSameTimescaleIsNoOp() throws {
        let ts = MediaTimestamp(value: 12345, timescale: 1000)
        let rescaled = try rescale(ts, to: 1000)
        #expect(rescaled == ts)
    }

    @Test
    func rescaleDownIntegerExact() throws {
        // 90_000 ticks at 90 kHz → 1000 ticks at 1 kHz (exactly 1 second)
        let ts = MediaTimestamp(value: 90_000, timescale: 90_000)
        let rescaled = try rescale(ts, to: 1000)
        #expect(rescaled.value == 1000)
        #expect(rescaled.timescale == 1000)
    }

    @Test
    func rescale90kHzTo1MHzZeroDrift() throws {
        // 1 second at 90 kHz → 1_000_000 ticks at 1 MHz (exactly)
        let ts = MediaTimestamp(value: 90_000, timescale: 90_000)
        let rescaled = try rescale(ts, to: 1_000_000)
        #expect(rescaled.value == 1_000_000)
        #expect(rescaled.timescale == 1_000_000)
    }

    @Test
    func rescaleLargeNonOverflowing() throws {
        // 1 billion at 1 kHz → 1 trillion at 1 MHz (fits in Int64)
        let ts = MediaTimestamp(value: 1_000_000_000, timescale: 1_000)
        let rescaled = try rescale(ts, to: 1_000_000)
        #expect(rescaled.value == 1_000_000_000_000)
        #expect(rescaled.timescale == 1_000_000)
    }

    @Test
    func rescaleOverflowThrowsCleanly() {
        // Int64.max / 2 * 1_000_000 overflows Int64.
        let ts = MediaTimestamp(value: Int64.max / 2, timescale: 90_000)
        do {
            _ = try rescale(ts, to: 1_000_000)
            Issue.record("expected overflow throw")
        } catch let err as MediaTimestampRescaleError {
            if case let .overflow(value, newTimescale, oldTimescale) = err {
                #expect(value == Int64.max / 2)
                #expect(newTimescale == 1_000_000)
                #expect(oldTimescale == 90_000)
            } else {
                Issue.record("wrong rescale error case: \(err)")
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func hashableEquality() {
        let a = MediaTimestamp(value: 100, timescale: 1000)
        let b = MediaTimestamp(value: 100, timescale: 1000)
        let c = MediaTimestamp(value: 100, timescale: 2000)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
        let set: Set<MediaTimestamp> = [a, b, c]
        #expect(set.count == 2)
    }

    @Test
    func sendableAcrossActorHop() async {
        actor Box {
            var ts: MediaTimestamp?
            func store(_ value: MediaTimestamp) { ts = value }
        }
        let box = Box()
        let original = MediaTimestamp(value: 540_000, timescale: 90_000)
        await box.store(original)
        let echoed = await box.ts
        #expect(echoed == original)
    }

    @Test
    func zeroValueIsLegal() {
        let ts = MediaTimestamp(value: 0, timescale: 90_000)
        #expect(ts.value == 0)
        #expect(ts.seconds == 0.0)
    }

    @Test
    func negativeValueIsLegal() {
        // Composition offsets can be negative under CTTS v1.
        let ts = MediaTimestamp(value: -3000, timescale: 1000)
        #expect(ts.value == -3000)
        #expect(ts.seconds == -3.0)
    }

    @Test
    func rescaleDifferentTimescalesNoLoss() throws {
        // 100 ticks at 1000 → 200 ticks at 2000.
        let ts = MediaTimestamp(value: 100, timescale: 1000)
        let rescaled = try rescale(ts, to: 2000)
        #expect(rescaled.value == 200)
        #expect(rescaled.timescale == 2000)
    }
}
