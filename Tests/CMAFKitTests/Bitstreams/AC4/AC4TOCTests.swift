// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AC4TOC")
struct AC4TOCTests {

    @Test
    func singlePresentation48kRoundTrip() throws {
        let toc = AC4TOC(
            bitstreamVersion: 1,
            sequenceCounter: 0,
            bWaitFrames: false,
            fsIndex: 1,
            frameRateIndex: 5,
            bIframeGlobal: false,
            bSinglePresentation: true,
            nPresentations: 1,
            presentations: [
                AC4PresentationInfo(
                    presentationConfig: 0,
                    presentationVersion: 1,
                    addEmdfSubstreamsFlag: false,
                    mdcompat: 0,
                    presentationGroupIndex: 0
                )
            ]
        )
        let encoded = toc.encode()
        let decoded = try AC4TOC.parse(bitstream: encoded)
        #expect(decoded == toc)
    }

    @Test
    func multiPresentationRoundTrip() throws {
        let presentations = (0..<3).map { i -> AC4PresentationInfo in
            AC4PresentationInfo(
                presentationConfig: UInt8(i),
                presentationVersion: 1,
                addEmdfSubstreamsFlag: false,
                mdcompat: 0,
                presentationGroupIndex: UInt8(i)
            )
        }
        let toc = AC4TOC(
            bitstreamVersion: 1,
            sequenceCounter: 42,
            bWaitFrames: false,
            fsIndex: 1,
            frameRateIndex: 5,
            bIframeGlobal: true,
            bSinglePresentation: false,
            bMorePresentations: true,
            nPresentations: 3,
            presentations: presentations
        )
        let encoded = toc.encode()
        let decoded = try AC4TOC.parse(bitstream: encoded)
        #expect(decoded.nPresentations == 3)
        #expect(decoded.presentations.count == 3)
    }

    @Test
    func withWaitFrames() throws {
        let toc = AC4TOC(
            bitstreamVersion: 1,
            sequenceCounter: 100,
            bWaitFrames: true,
            waitFrames: 5,
            fsIndex: 1,
            frameRateIndex: 5,
            bIframeGlobal: false,
            bSinglePresentation: true,
            nPresentations: 1,
            presentations: [
                AC4PresentationInfo(
                    presentationConfig: 0,
                    presentationVersion: 1,
                    addEmdfSubstreamsFlag: false,
                    mdcompat: 0,
                    presentationGroupIndex: 0
                )
            ]
        )
        let encoded = toc.encode()
        let decoded = try AC4TOC.parse(bitstream: encoded)
        #expect(decoded.waitFrames == 5)
    }

    @Test
    func fsIndexZeroRoundTrip() throws {
        let toc = AC4TOC(
            bitstreamVersion: 1,
            sequenceCounter: 0,
            bWaitFrames: false,
            fsIndex: 0,
            frameRateIndex: 1,
            bIframeGlobal: false,
            bSinglePresentation: true,
            nPresentations: 1,
            presentations: [
                AC4PresentationInfo(
                    presentationConfig: 0,
                    presentationVersion: 1,
                    addEmdfSubstreamsFlag: false,
                    mdcompat: 0,
                    presentationGroupIndex: 0
                )
            ]
        )
        let encoded = toc.encode()
        let decoded = try AC4TOC.parse(bitstream: encoded)
        #expect(decoded.fsIndex == 0)
    }

    @Test
    func rejectsBitstreamVersion3() {
        var writer = BitWriter()
        writer.writeBits(3, count: 2)  // bitstreamVersion 3 → unsupported
        writer.byteAlign()
        #expect(throws: BitstreamError.self) {
            _ = try AC4TOC.parse(bitstream: writer.data)
        }
    }
}
