// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AudioSampleEntryExtensions
//
// Reference: ISO/IEC 14496-12 §8.5.2 + §12.2.4 + §12.2.5.
//
// Optional extension boxes attached to an audio sample entry: channel
// layout, sampling rate override, and bit-rate hints.

import Foundation

/// Optional extension boxes attached to an audio sample entry.
public struct AudioSampleEntryExtensions: Sendable, Equatable, Hashable {
    public let channelLayout: ChannelLayoutBox?
    public let samplingRate: SamplingRateBox?
    public let bitRate: BitRateBox?

    public init(
        channelLayout: ChannelLayoutBox? = nil,
        samplingRate: SamplingRateBox? = nil,
        bitRate: BitRateBox? = nil
    ) {
        self.channelLayout = channelLayout
        self.samplingRate = samplingRate
        self.bitRate = bitRate
    }

    /// Parse zero or more extension boxes from the remainder of an
    /// audio sample entry's body. Unrecognised FourCCs round-trip
    /// verbatim via the second return value.
    public static func parse(
        reader: inout BinaryReader,
        registry: BoxRegistry
    ) async throws -> (AudioSampleEntryExtensions, [ISOBoxOpaque]) {
        var channelLayout: ChannelLayoutBox?
        var samplingRate: SamplingRateBox?
        var bitRate: BitRateBox?
        var unknown: [ISOBoxOpaque] = []

        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            var peek = reader
            let header = try isoBoxReader.parseBoxHeader(&peek)
            switch header.type {
            case ChannelLayoutBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                channelLayout = try await ChannelLayoutBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            case SamplingRateBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                samplingRate = try await SamplingRateBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            case BitRateBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                bitRate = try await BitRateBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            default:
                unknown.append(try ISOBoxOpaque.parse(reader: &reader))
            }
        }

        let exts = AudioSampleEntryExtensions(
            channelLayout: channelLayout,
            samplingRate: samplingRate,
            bitRate: bitRate
        )
        return (exts, unknown)
    }

    /// Emit every present extension box in canonical order.
    public func encode(to writer: inout BinaryWriter) {
        channelLayout?.encode(to: &writer)
        samplingRate?.encode(to: &writer)
        bitRate?.encode(to: &writer)
    }
}
