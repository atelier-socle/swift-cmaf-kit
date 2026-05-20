// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BoxRegistry subtitle + metadata builtins
//
// Registers the typed parsers for the subtitle and metadata sample-
// entry boxes plus their config children:
//
//   - `wvtt` + `vttC` + `vlab` (ISO/IEC 14496-30 §7.5)
//   - `stpp` (ISO/IEC 14496-30 §7.4)
//   - `mett` (ISO/IEC 14496-12 §8.5.2.1)
//   - `urim` + `uri ` + `uriI` (ISO/IEC 14496-12 §8.5.2.4)
//   - `id3 ` (HLS-adopted convention)

import Foundation

extension BoxRegistry {
    internal func registerSubtitleMetadataBuiltinBoxes() {
        register(WebVTTSampleEntry.self) { reader, header, registry in
            try await WebVTTSampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
        register(WebVTTConfigurationBox.self) { reader, header, registry in
            try await WebVTTConfigurationBox.parse(
                reader: &reader, header: header, registry: registry
            )
        }
        register(WebVTTSourceLabelBox.self) { reader, header, registry in
            try await WebVTTSourceLabelBox.parse(
                reader: &reader, header: header, registry: registry
            )
        }
        register(XMLSubtitleSampleEntry.self) { reader, header, registry in
            try await XMLSubtitleSampleEntry.parse(
                reader: &reader, header: header, registry: registry
            )
        }
        register(TextMetadataSampleEntry.self) { reader, header, registry in
            try await TextMetadataSampleEntry.parse(
                reader: &reader, header: header, registry: registry
            )
        }
        register(URIMetadataSampleEntry.self) { reader, header, registry in
            try await URIMetadataSampleEntry.parse(
                reader: &reader, header: header, registry: registry
            )
        }
        register(URIBox.self) { reader, header, registry in
            try await URIBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(URIInitBox.self) { reader, header, registry in
            try await URIInitBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(ID3SampleEntry.self) { reader, header, registry in
            try await ID3SampleEntry.parse(reader: &reader, header: header, registry: registry)
        }
    }
}
