// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AC4TOC
//
// Reference: ETSI TS 103 190-1 §6.2.1 (Table of Contents — top level).
//
// The AC-4 TOC is a deeply structured bitfield. CMAFKit parses the
// top-level TOC fields that container-layer consumers need (bitstream
// version, sequence counter, sampling-rate index, frame-rate index,
// per-presentation entries) and surfaces the per-presentation
// descriptor envelope. Internal-only bits beyond the public-facing
// TOC are out of the container-library scope.

import Foundation

/// AC-4 top-level Table of Contents per ETSI TS 103 190-1 §6.2.1.
public struct AC4TOC: Sendable, Hashable, Equatable {
    /// 2-bit `bitstream_version` for versions 0/1; version 2 escapes
    /// to a wider encoding handled by `bitstreamVersionExtended`.
    public let bitstreamVersion: UInt8
    /// 10-bit `sequence_counter`.
    public let sequenceCounter: UInt16
    /// `b_wait_frames` flag.
    public let bWaitFrames: Bool
    /// 3-bit `wait_frames` — present iff `bWaitFrames`.
    public let waitFrames: UInt8?
    /// 1-bit `fs_index` (0 → 44.1 kHz family, 1 → 48 kHz family).
    public let fsIndex: UInt8
    /// 4-bit `frame_rate_index`.
    public let frameRateIndex: UInt8
    /// `b_iframe_global` flag.
    public let bIframeGlobal: Bool
    /// `b_single_presentation` flag.
    public let bSinglePresentation: Bool
    /// `b_more_presentations` flag — present iff `!bSinglePresentation`.
    public let bMorePresentations: Bool?
    /// `n_presentations` — present iff `bMorePresentations`. Range
    /// `0...511` (9 bits + offset).
    public let nPresentations: UInt16
    /// Per-presentation descriptors.
    public let presentations: [AC4PresentationInfo]
    /// Total payload size declared on the wire, in bits. CMAFKit
    /// uses this to bound presentation parsing.
    public let payloadBaseFieldsBits: Int

    public init(
        bitstreamVersion: UInt8,
        sequenceCounter: UInt16,
        bWaitFrames: Bool,
        waitFrames: UInt8? = nil,
        fsIndex: UInt8,
        frameRateIndex: UInt8,
        bIframeGlobal: Bool,
        bSinglePresentation: Bool,
        bMorePresentations: Bool? = nil,
        nPresentations: UInt16,
        presentations: [AC4PresentationInfo],
        payloadBaseFieldsBits: Int = 0
    ) {
        precondition(bitstreamVersion <= 2, "bitstreamVersion must be 0..2")
        precondition(sequenceCounter <= 0x03FF, "sequenceCounter must fit 10 bits")
        precondition(fsIndex <= 1, "fsIndex must fit 1 bit")
        precondition(frameRateIndex <= 0x0F, "frameRateIndex must fit 4 bits")
        precondition(
            bWaitFrames == (waitFrames != nil),
            "waitFrames presence must match bWaitFrames"
        )
        precondition(
            bSinglePresentation || bMorePresentations != nil,
            "bMorePresentations must be set when not bSinglePresentation"
        )
        self.bitstreamVersion = bitstreamVersion
        self.sequenceCounter = sequenceCounter
        self.bWaitFrames = bWaitFrames
        self.waitFrames = waitFrames
        self.fsIndex = fsIndex
        self.frameRateIndex = frameRateIndex
        self.bIframeGlobal = bIframeGlobal
        self.bSinglePresentation = bSinglePresentation
        self.bMorePresentations = bMorePresentations
        self.nPresentations = nPresentations
        self.presentations = presentations
        self.payloadBaseFieldsBits = payloadBaseFieldsBits
    }

    public static func parse(bitstream: Data) throws -> AC4TOC {
        var reader = BitReader(bitstream)
        let version = UInt8(try reader.readBits(2))
        guard version <= 2 else {
            throw BitstreamError.unsupportedValue(
                codec: "AC4", field: "bitstream_version", value: UInt64(version)
            )
        }
        let seq = UInt16(try reader.readBits(10))
        let waitF = try reader.readBool()
        var wf: UInt8?
        if waitF { wf = UInt8(try reader.readBits(3)) }
        // 2 bits br_index_for_coded — skip
        _ = try reader.readBits(2)
        let fs = UInt8(try reader.readBits(1))
        let fr = UInt8(try reader.readBits(4))
        let iframeGlobal = try reader.readBool()
        let singlePresentation = try reader.readBool()
        var morePresentations: Bool?
        var n: UInt16 = 1
        var presentations: [AC4PresentationInfo] = []
        if singlePresentation {
            n = 1
            presentations.append(try parsePresentation(reader: &reader))
        } else {
            let more = try reader.readBool()
            morePresentations = more
            if more {
                let raw = UInt16(try reader.readBits(9))
                n = raw + 2  // 0 → 2 presentations
            } else {
                n = 2
            }
            for _ in 0..<n {
                presentations.append(try parsePresentation(reader: &reader))
            }
        }
        return AC4TOC(
            bitstreamVersion: version,
            sequenceCounter: seq,
            bWaitFrames: waitF,
            waitFrames: wf,
            fsIndex: fs,
            frameRateIndex: fr,
            bIframeGlobal: iframeGlobal,
            bSinglePresentation: singlePresentation,
            bMorePresentations: morePresentations,
            nPresentations: n,
            presentations: presentations
        )
    }

    public func encode() -> Data {
        var writer = BitWriter()
        writer.writeBits(UInt64(bitstreamVersion & 0x03), count: 2)
        writer.writeBits(UInt64(sequenceCounter & 0x03FF), count: 10)
        writer.writeBool(bWaitFrames)
        if let wf = waitFrames { writer.writeBits(UInt64(wf & 0x07), count: 3) }
        writer.writeBits(0, count: 2)  // br_index_for_coded
        writer.writeBits(UInt64(fsIndex & 0x01), count: 1)
        writer.writeBits(UInt64(frameRateIndex & 0x0F), count: 4)
        writer.writeBool(bIframeGlobal)
        writer.writeBool(bSinglePresentation)
        if !bSinglePresentation {
            let more = bMorePresentations ?? false
            writer.writeBool(more)
            if more {
                let raw = nPresentations >= 2 ? nPresentations - 2 : 0
                writer.writeBits(UInt64(raw & 0x01FF), count: 9)
            }
        }
        for p in presentations {
            encodePresentation(p, to: &writer)
        }
        writer.byteAlign()
        return writer.data
    }

    private static func parsePresentation(reader: inout BitReader) throws -> AC4PresentationInfo {
        let version = UInt8(try reader.readBits(5))
        let config = UInt8(try reader.readBits(5))
        let addEmdf = try reader.readBool()
        let mdcompat = UInt8(try reader.readBits(3))
        let groupIdx = UInt8(try reader.readBits(5))
        return AC4PresentationInfo(
            presentationConfig: config,
            presentationVersion: version,
            addEmdfSubstreamsFlag: addEmdf,
            mdcompat: mdcompat,
            presentationGroupIndex: groupIdx
        )
    }

    private func encodePresentation(_ p: AC4PresentationInfo, to writer: inout BitWriter) {
        writer.writeBits(UInt64(p.presentationVersion & 0x1F), count: 5)
        writer.writeBits(UInt64(p.presentationConfig & 0x1F), count: 5)
        writer.writeBool(p.addEmdfSubstreamsFlag)
        writer.writeBits(UInt64(p.mdcompat & 0x07), count: 3)
        writer.writeBits(UInt64(p.presentationGroupIndex & 0x1F), count: 5)
    }
}
