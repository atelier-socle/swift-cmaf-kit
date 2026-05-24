// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BoxRegistry audio sample-entry builtins
//
// Registers parsers for:
//   • 13 audio sample entries: mp4a, ac-3, ec-3, ac-4, Opus, fLaC,
//                              mhm1, mhm2, enca, alac, ipcm, fpcm, lpcm
//   • 8 configuration / metadata boxes: dac3, dec3, dac4, dOps, dfLa,
//                                       mhaC, mhaP, pcmC
//   • 2 audio extension boxes: chnl, srat
//
// Note: `ALACSpecificBox` (fourCC `alac`, child of `ALACSampleEntry`)
// is intentionally NOT registered here — it collides with the parent
// `ALACSampleEntry` fourCC. `ALACSampleEntry.parse` reads the inner
// magic-cookie box manually (mirroring the FLACSampleEntry pattern
// adapted for same-fourCC ALAC).

import Foundation

extension BoxRegistry {
    /// Register the audio sample-entry, configuration-record, and
    /// audio-extension box parsers.
    ///
    /// Called from ``registerBuiltinBoxes`` alongside the other built-in
    /// registration methods.
    internal func registerAudioSampleEntryBuiltinBoxes() {
        registerAudioSampleEntryBoxes()
        registerAudioConfigurationBoxes()
        registerAudioExtensionBoxes()
    }

    private func registerAudioSampleEntryBoxes() {
        register(MP4AudioSampleEntry.self) { reader, header, registry in
            try await MP4AudioSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(AC3SampleEntry.self) { reader, header, registry in
            try await AC3SampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(EC3SampleEntry.self) { reader, header, registry in
            try await EC3SampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(AC4SampleEntry.self) { reader, header, registry in
            try await AC4SampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(OpusSampleEntry.self) { reader, header, registry in
            try await OpusSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(FLACSampleEntry.self) { reader, header, registry in
            try await FLACSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(MPEGHAudioSampleEntry.self) { reader, header, registry in
            try await MPEGHAudioSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(MPEGHAudioSampleEntryMultiStream.self) { reader, header, registry in
            try await MPEGHAudioSampleEntryMultiStream.parse(reader: &reader, header: header, registry: registry)
        }
        register(EncryptedAudioSampleEntry.self) { reader, header, registry in
            try await EncryptedAudioSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(ALACSampleEntry.self) { reader, header, registry in
            try await ALACSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(IntegerPCMSampleEntry.self) { reader, header, registry in
            try await IntegerPCMSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(FloatingPointPCMSampleEntry.self) { reader, header, registry in
            try await FloatingPointPCMSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(LegacyPCMSampleEntry.self) { reader, header, registry in
            try await LegacyPCMSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
    }

    private func registerAudioConfigurationBoxes() {
        register(AC3SpecificBox.self) { reader, header, registry in
            try await AC3SpecificBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(EC3SpecificBox.self) { reader, header, registry in
            try await EC3SpecificBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(AC4SpecificBox.self) { reader, header, registry in
            try await AC4SpecificBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(OpusSpecificBox.self) { reader, header, registry in
            try await OpusSpecificBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(FLACSpecificBox.self) { reader, header, registry in
            try await FLACSpecificBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MPEGHConfigurationBox.self) { reader, header, registry in
            try await MPEGHConfigurationBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MPEGHProfileLevelCompatibilitySetBox.self) { reader, header, registry in
            try await MPEGHProfileLevelCompatibilitySetBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(PCMConfigurationBox.self) { reader, header, registry in
            try await PCMConfigurationBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    private func registerAudioExtensionBoxes() {
        register(ChannelLayoutBox.self) { reader, header, registry in
            try await ChannelLayoutBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SamplingRateBox.self) { reader, header, registry in
            try await SamplingRateBox.parse(reader: &reader, header: header, registry: registry)
        }
    }
}
