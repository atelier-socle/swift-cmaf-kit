// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AudioSampleEntryFields
//
// Reference: ISO/IEC 14496-12 §8.5.2 (AudioSampleEntry).
//
// Common prefix shared by every audio codec sample entry (mp4a, ac-3,
// ec-3, ac-4, Opus, fLaC, mhm1, mhm2, enca). After the 16-byte
// SampleEntry preamble (6 reserved + UInt16 dataReferenceIndex), V0
// adds 20 bytes carrying channel count, sample size, sample rate.
//
// V1 extends the V0 layout with `entryVersion`, `outChannelCount`,
// `outSampleSize`, `outSampleRate`, `constBytesPerAudioSample` and
// `samplesPerFrame`. Modern codecs typically rely on `chnl` and `srat`
// extension boxes rather than V1; CMAFKit supports both.

import Foundation

/// Audio sample entry version per ISO/IEC 14496-12 §8.5.2.
public enum AudioSampleEntryVersion: UInt16, Sendable, Hashable, CaseIterable, Codable {
    case v0 = 0
    case v1 = 1
}

/// The common prefix shared by every audio sample entry.
///
/// Reference: ISO/IEC 14496-12 §8.5.2.
public struct AudioSampleEntryFields: Sendable, Equatable, Hashable {

    /// V1-only fields. Present iff ``version`` is `.v1`.
    public struct V1Fields: Sendable, Equatable, Hashable {
        public let outChannelCount: UInt16
        public let outSampleSize: UInt16
        public let outSampleRate: UInt32
        public let constBytesPerAudioSample: UInt32
        public let samplesPerFrame: UInt32

        public init(
            outChannelCount: UInt16,
            outSampleSize: UInt16,
            outSampleRate: UInt32,
            constBytesPerAudioSample: UInt32,
            samplesPerFrame: UInt32
        ) {
            self.outChannelCount = outChannelCount
            self.outSampleSize = outSampleSize
            self.outSampleRate = outSampleRate
            self.constBytesPerAudioSample = constBytesPerAudioSample
            self.samplesPerFrame = samplesPerFrame
        }
    }

    public let dataReferenceIndex: UInt16
    public let version: AudioSampleEntryVersion
    /// Legacy channel count carried by V0. When a ``ChannelLayoutBox``
    /// is present on the parent sample entry it overrides this value.
    public let channelCount: UInt16
    /// Legacy bits-per-sample. Modern entries override via dedicated
    /// boxes (out of scope for this module).
    public let sampleSize: UInt16
    /// Legacy sample rate stored as 16.16 fixed-point. The high 16 bits
    /// hold the integer Hz; the low 16 bits are 0 in practice. When a
    /// ``SamplingRateBox`` is present it overrides this value.
    public let sampleRate: UInt32
    /// V1-only extension fields. Present iff ``version`` is `.v1`.
    public let v1Fields: V1Fields?

    public init(
        dataReferenceIndex: UInt16 = 1,
        version: AudioSampleEntryVersion = .v0,
        channelCount: UInt16 = 2,
        sampleSize: UInt16 = 16,
        sampleRate: UInt32 = 0xBB80_0000,  // 48000 Hz in 16.16 fixed-point
        v1Fields: V1Fields? = nil
    ) {
        precondition(
            (version == .v1) == (v1Fields != nil),
            "AudioSampleEntryFields: v1Fields presence must match version"
        )
        self.dataReferenceIndex = dataReferenceIndex
        self.version = version
        self.channelCount = channelCount
        self.sampleSize = sampleSize
        self.sampleRate = sampleRate
        self.v1Fields = v1Fields
    }

    public static func parse(reader: inout BinaryReader) throws -> AudioSampleEntryFields {
        // SampleEntry preamble: 6 reserved bytes + UInt16 dataReferenceIndex.
        for _ in 0..<6 {
            let byte = try reader.readUInt8()
            guard byte == 0 else {
                throw ISOBoxError.malformedFullBox(
                    type: "asmp",
                    reason: "AudioSampleEntry SampleEntry reserved field must be zero"
                )
            }
        }
        let dataReferenceIndex = try reader.readUInt16()

        // The first UInt16 after the preamble is the SoundBox-level
        // `entry_version` (V0 = 0, V1 = 1).
        let versionRaw = try reader.readUInt16()
        guard let version = AudioSampleEntryVersion(rawValue: versionRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "asmp",
                reason: "AudioSampleEntry version must be 0 or 1, got \(versionRaw)"
            )
        }
        // 6 bytes reserved (UInt16 + UInt32) per spec.
        let reserved16 = try reader.readUInt16()
        let reserved32 = try reader.readUInt32()
        guard reserved16 == 0, reserved32 == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "asmp",
                reason: "AudioSampleEntry reserved fields must be zero"
            )
        }

        let channelCount = try reader.readUInt16()
        let sampleSize = try reader.readUInt16()
        let preDefined = try reader.readUInt16()
        guard preDefined == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "asmp",
                reason: "AudioSampleEntry preDefined must be zero"
            )
        }
        let reserved2 = try reader.readUInt16()
        guard reserved2 == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: "asmp",
                reason: "AudioSampleEntry reserved2 must be zero"
            )
        }
        let sampleRate = try reader.readUInt32()

        var v1Fields: V1Fields?
        if version == .v1 {
            let outChannelCount = try reader.readUInt16()
            let outSampleSize = try reader.readUInt16()
            let outSampleRate = try reader.readUInt32()
            let constBytesPerAudioSample = try reader.readUInt32()
            let samplesPerFrame = try reader.readUInt32()
            v1Fields = V1Fields(
                outChannelCount: outChannelCount,
                outSampleSize: outSampleSize,
                outSampleRate: outSampleRate,
                constBytesPerAudioSample: constBytesPerAudioSample,
                samplesPerFrame: samplesPerFrame
            )
        }

        return AudioSampleEntryFields(
            dataReferenceIndex: dataReferenceIndex,
            version: version,
            channelCount: channelCount,
            sampleSize: sampleSize,
            sampleRate: sampleRate,
            v1Fields: v1Fields
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeZeros(6)
        writer.writeUInt16(dataReferenceIndex)
        writer.writeUInt16(version.rawValue)
        writer.writeUInt16(0)
        writer.writeUInt32(0)
        writer.writeUInt16(channelCount)
        writer.writeUInt16(sampleSize)
        writer.writeUInt16(0)  // preDefined
        writer.writeUInt16(0)  // reserved2
        writer.writeUInt32(sampleRate)
        if let v1 = v1Fields {
            writer.writeUInt16(v1.outChannelCount)
            writer.writeUInt16(v1.outSampleSize)
            writer.writeUInt32(v1.outSampleRate)
            writer.writeUInt32(v1.constBytesPerAudioSample)
            writer.writeUInt32(v1.samplesPerFrame)
        }
    }
}
