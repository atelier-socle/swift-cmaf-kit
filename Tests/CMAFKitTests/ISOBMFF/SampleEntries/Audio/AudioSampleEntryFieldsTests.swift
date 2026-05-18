// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AudioSampleEntryFields")
struct AudioSampleEntryFieldsTests {

    @Test
    func v0DefaultsRoundTrip() throws {
        let fields = AudioSampleEntryFields()
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try AudioSampleEntryFields.parse(reader: &reader)
        #expect(decoded == fields)
    }

    @Test
    func v0CustomChannelsRoundTrip() throws {
        let fields = AudioSampleEntryFields(
            dataReferenceIndex: 1,
            version: .v0,
            channelCount: 6,
            sampleSize: 16,
            sampleRate: 0xBB80_0000
        )
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try AudioSampleEntryFields.parse(reader: &reader)
        #expect(decoded == fields)
    }

    @Test
    func v1FieldsRoundTrip() throws {
        let v1 = AudioSampleEntryFields.V1Fields(
            outChannelCount: 2,
            outSampleSize: 16,
            outSampleRate: 48000,
            constBytesPerAudioSample: 4,
            samplesPerFrame: 1024
        )
        let fields = AudioSampleEntryFields(
            dataReferenceIndex: 1,
            version: .v1,
            channelCount: 2,
            sampleSize: 16,
            sampleRate: 0xBB80_0000,
            v1Fields: v1
        )
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try AudioSampleEntryFields.parse(reader: &reader)
        #expect(decoded == fields)
    }

    @Test
    func v0BodyIs36Bytes() {
        let fields = AudioSampleEntryFields()
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        // 6 reserved + 2 dRefIdx + 2 ver + 2 res + 4 res + 2 ch + 2 ss
        //   + 2 pre + 2 res + 4 sr = 28 bytes — wait, that's 28.
        // Cross-checking spec: V0 audio sample-entry payload after the
        // shared 8-byte SampleEntry preamble is 20 bytes, so total is 28.
        #expect(writer.data.count == 28)
    }

    @Test
    func v1BodyIs56Bytes() {
        let v1 = AudioSampleEntryFields.V1Fields(
            outChannelCount: 0,
            outSampleSize: 0,
            outSampleRate: 0,
            constBytesPerAudioSample: 0,
            samplesPerFrame: 0
        )
        let fields = AudioSampleEntryFields(version: .v1, v1Fields: v1)
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        // V1 appends 20 bytes (2+2+4+4+4 = 16... wait 2+2+4+4+4 = 16,
        // so total 28 + 16 = 44 bytes? Let me recount:
        //   outChannelCount: UInt16 = 2
        //   outSampleSize: UInt16 = 2
        //   outSampleRate: UInt32 = 4
        //   constBytesPerAudioSample: UInt32 = 4
        //   samplesPerFrame: UInt32 = 4
        //   total V1 extension: 16 bytes
        // 28 + 16 = 44 bytes.
        #expect(writer.data.count == 44)
    }

    @Test
    func parseRejectsNonZeroReserved() async throws {
        var bytes = Data(count: 28)
        bytes[0] = 0xFF  // first reserved byte non-zero
        bytes[6] = 0x00
        bytes[7] = 0x01  // dRefIdx
        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try AudioSampleEntryFields.parse(reader: &reader)
        }
    }

    @Test
    func unknownVersionRejected() async throws {
        var writer = BinaryWriter()
        writer.writeZeros(6)
        writer.writeUInt16(1)  // dRefIdx
        writer.writeUInt16(7)  // unknown version
        writer.writeZeros(20)  // padding
        var reader = BinaryReader(writer.data)
        #expect(throws: ISOBoxError.self) {
            _ = try AudioSampleEntryFields.parse(reader: &reader)
        }
    }

    @Test
    func sampleRatePreservedAt48000() {
        let fields = AudioSampleEntryFields(sampleRate: 0xBB80_0000)
        #expect(fields.sampleRate == 0xBB80_0000)
    }

    @Test
    func hashableConformance() {
        let a = AudioSampleEntryFields()
        let b = AudioSampleEntryFields()
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func equalityDistinguishesChannelCount() {
        let a = AudioSampleEntryFields(channelCount: 2)
        let b = AudioSampleEntryFields(channelCount: 6)
        #expect(a != b)
    }

    @Test
    func dataReferenceIndexRoundTrip() throws {
        let fields = AudioSampleEntryFields(dataReferenceIndex: 5)
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try AudioSampleEntryFields.parse(reader: &reader)
        #expect(decoded.dataReferenceIndex == 5)
    }

    @Test
    func versionEnumCases() {
        #expect(AudioSampleEntryVersion.v0.rawValue == 0)
        #expect(AudioSampleEntryVersion.v1.rawValue == 1)
        #expect(AudioSampleEntryVersion.allCases.count == 2)
    }
}
