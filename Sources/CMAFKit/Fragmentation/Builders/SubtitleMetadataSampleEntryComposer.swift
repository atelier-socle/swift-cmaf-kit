// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SubtitleMetadataSampleEntryComposer
//
// Reference: ISO/IEC 14496-30 §7.4 / §7.5 (subtitle sample entries)
// and ISO/IEC 14496-12 §8.5.2 (text + URI metadata sample entries).
//
// Companion to ``SampleEntryComposer`` covering the subtitle and
// timed-metadata kinds.

import Foundation

internal enum SubtitleMetadataSampleEntryComposer {

    /// Compose the sample-entry for a subtitle track.
    static func makeSubtitleSampleEntry(
        configuration: CMAFTrackConfiguration
    ) throws -> any ISOBox {
        guard let subtitle = configuration.subtitleFields else {
            throw CMAFWriterError.configurationInvalid(
                reason: "subtitle track \(configuration.trackID) missing subtitleFields"
            )
        }
        switch subtitle.codec {
        case .webVTT:
            return WebVTTSampleEntry(
                configuration: WebVTTConfigurationBox(headerText: "WEBVTT\n")
            )
        case .imsc1Text:
            return XMLSubtitleSampleEntry(
                namespace: "http://www.w3.org/ns/ttml",
                schemaLocation: "",
                auxiliaryMIMETypes: "application/ttml+xml;codecs=\"im1t\""
            )
        case .imsc1Image:
            return XMLSubtitleSampleEntry(
                namespace: "http://www.w3.org/ns/ttml",
                schemaLocation: "",
                auxiliaryMIMETypes: "application/ttml+xml;codecs=\"im1i\""
            )
        }
    }

    /// Compose the sample-entry for a timed-metadata track.
    static func makeMetadataSampleEntry(
        configuration: CMAFTrackConfiguration
    ) throws -> any ISOBox {
        guard let metadata = configuration.metadataFields else {
            throw CMAFWriterError.configurationInvalid(
                reason: "metadata track \(configuration.trackID) missing metadataFields"
            )
        }
        switch metadata.metadataType {
        case .id3:
            return ID3SampleEntry()
        case .klv:
            return TextMetadataSampleEntry(
                contentEncoding: "",
                mimeFormat: "application/smpte-336-klv"
            )
        case .timedText:
            return TextMetadataSampleEntry(
                contentEncoding: "",
                mimeFormat: "text/plain;charset=UTF-8"
            )
        case .uri(let schemeURI):
            return URIMetadataSampleEntry(
                uri: URIBox(uri: schemeURI),
                uriInit: nil
            )
        }
    }
}
