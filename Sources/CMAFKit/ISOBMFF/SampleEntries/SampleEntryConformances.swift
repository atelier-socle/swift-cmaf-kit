// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleEntry conformances
//
// Reference: ISO/IEC 14496-12 §8.5.2.2 (sample entry preamble).
//
// The typed sample-entry structs declared in this folder all carry a
// 1-based `data_reference_index` inside their `visualFields` or
// `audioFields` preamble. This file routes those preamble values to
// the protocol requirement so the typed entries can be placed in
// ``SampleDescriptionBox/entries``.

import Foundation

// MARK: Video

extension AVCSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension AVCSampleEntryInband: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension HEVCSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension HEVCSampleEntryInband: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension DolbyVisionHEVCSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension DolbyVisionHEVCSampleEntryInband: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension VP8SampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension VP9SampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension AV1SampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension MP4VisualSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

extension EncryptedVideoSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { visualFields.dataReferenceIndex }
}

// MARK: Audio

extension MP4AudioSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension AC3SampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension EC3SampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension AC4SampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension OpusSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension FLACSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension MPEGHAudioSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension MPEGHAudioSampleEntryMultiStream: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension EncryptedAudioSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension ALACSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension IntegerPCMSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension FloatingPointPCMSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}

extension LegacyPCMSampleEntry: SampleEntry {
    public var dataReferenceIndex: UInt16 { audioFields.dataReferenceIndex }
}
