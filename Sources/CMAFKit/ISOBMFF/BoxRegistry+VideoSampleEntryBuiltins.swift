// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BoxRegistry video sample-entry builtins
//
// Registers parsers for:
//   • 11 video sample entries: avc1, avc3, hvc1, hev1, dvh1, dvhe,
//                              vp08, vp09, av01, mp4v, encv
//   • 5 configuration records: avcC, hvcC, vpcC, av1C, esds
//   • 3 extension boxes:       pasp, clap, btrt

import Foundation

extension BoxRegistry {
    /// Register the video-sample-entry, configuration-record, and
    /// extension box parsers.
    ///
    /// Called from ``registerBuiltinBoxes`` alongside the other built-in
    /// registration methods.
    internal func registerVideoSampleEntryBuiltinBoxes() {
        registerVideoSampleEntryBoxes()
        registerVideoConfigurationRecordBoxes()
        registerVideoExtensionBoxes()
    }

    private func registerVideoSampleEntryBoxes() {
        register(AVCSampleEntry.self) { reader, header, registry in
            try await AVCSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(AVCSampleEntryInband.self) { reader, header, registry in
            try await AVCSampleEntryInband.parse(reader: &reader, header: header, registry: registry)
        }
        register(HEVCSampleEntry.self) { reader, header, registry in
            try await HEVCSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(HEVCSampleEntryInband.self) { reader, header, registry in
            try await HEVCSampleEntryInband.parse(reader: &reader, header: header, registry: registry)
        }
        register(DolbyVisionHEVCSampleEntry.self) { reader, header, registry in
            try await DolbyVisionHEVCSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(DolbyVisionHEVCSampleEntryInband.self) { reader, header, registry in
            try await DolbyVisionHEVCSampleEntryInband.parse(reader: &reader, header: header, registry: registry)
        }
        register(VP8SampleEntry.self) { reader, header, registry in
            try await VP8SampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(VP9SampleEntry.self) { reader, header, registry in
            try await VP9SampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(AV1SampleEntry.self) { reader, header, registry in
            try await AV1SampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(MP4VisualSampleEntry.self) { reader, header, registry in
            try await MP4VisualSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(EncryptedVideoSampleEntry.self) { reader, header, registry in
            try await EncryptedVideoSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
    }

    private func registerVideoConfigurationRecordBoxes() {
        register(AVCDecoderConfigurationRecord.self) { reader, header, registry in
            try await AVCDecoderConfigurationRecord.parse(reader: &reader, header: header, registry: registry)
        }
        register(HEVCDecoderConfigurationRecord.self) { reader, header, registry in
            try await HEVCDecoderConfigurationRecord.parse(reader: &reader, header: header, registry: registry)
        }
        register(VPCodecConfigurationRecord.self) { reader, header, registry in
            try await VPCodecConfigurationRecord.parse(reader: &reader, header: header, registry: registry)
        }
        register(AV1CodecConfigurationRecord.self) { reader, header, registry in
            try await AV1CodecConfigurationRecord.parse(reader: &reader, header: header, registry: registry)
        }
        register(ElementaryStreamDescriptor.self) { reader, header, registry in
            try await ElementaryStreamDescriptor.parse(reader: &reader, header: header, registry: registry)
        }
    }

    private func registerVideoExtensionBoxes() {
        register(PixelAspectRatioBox.self) { reader, header, registry in
            try await PixelAspectRatioBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(CleanApertureBox.self) { reader, header, registry in
            try await CleanApertureBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(BitRateBox.self) { reader, header, registry in
            try await BitRateBox.parse(reader: &reader, header: header, registry: registry)
        }
    }
}
