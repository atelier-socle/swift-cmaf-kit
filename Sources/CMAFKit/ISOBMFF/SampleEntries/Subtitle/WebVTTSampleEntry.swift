// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - WebVTTSampleEntry (wvtt) + WebVTTConfigurationBox (vttC)
//
// Reference: ISO/IEC 14496-30 §7.5 (WebVTT in ISO Base Media File).
// Reference: W3C WebVTT (https://www.w3.org/TR/webvtt1/).
//
// `wvtt` is a plain sample entry: 6 reserved bytes + 2-byte
// data_reference_index + a mandatory ``WebVTTConfigurationBox`` (`vttC`)
// carrying the WebVTT file's header text (the "WEBVTT" line plus any
// `STYLE` / `REGION` blocks preceding the first cue).

import Foundation

/// WebVTT configuration box (`vttC`) per ISO/IEC 14496-30 §7.5.
public struct WebVTTConfigurationBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "vttC"

    /// The WebVTT file header text as a single UTF-8 string. Typically
    /// begins with `"WEBVTT"` and ends just before the first cue.
    public let headerText: String

    public init(headerText: String) {
        self.headerText = headerText
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> WebVTTConfigurationBox {
        let bodySize = Int(header.size) - header.headerSize
        let bytes = try reader.readData(count: bodySize)
        let text = String(data: bytes, encoding: .utf8) ?? ""
        return WebVTTConfigurationBox(headerText: text)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            if let data = headerText.data(using: .utf8) {
                body.writeData(data)
            }
        }
    }
}

/// Optional WebVTT empty-cue presentation box (`vlab`) per
/// ISO/IEC 14496-30 §7.5.2. Used to label the track on
/// presentation layers.
public struct WebVTTSourceLabelBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "vlab"

    public let sourceLabel: String

    public init(sourceLabel: String) {
        self.sourceLabel = sourceLabel
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> WebVTTSourceLabelBox {
        let bodySize = Int(header.size) - header.headerSize
        let bytes = try reader.readData(count: bodySize)
        let text = String(data: bytes, encoding: .utf8) ?? ""
        return WebVTTSourceLabelBox(sourceLabel: text)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            if let data = sourceLabel.data(using: .utf8) {
                body.writeData(data)
            }
        }
    }
}

/// WebVTT sample entry (`wvtt`) per ISO/IEC 14496-30 §7.5.
public struct WebVTTSampleEntry: SampleEntry, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "wvtt"

    /// 1-based index into the track's data reference table. Always 1
    /// for self-contained CMAF tracks.
    public let dataReferenceIndex: UInt16
    /// Mandatory WebVTT header carried inside `vttC`.
    public let configuration: WebVTTConfigurationBox
    /// Optional source label carried inside `vlab`.
    public let sourceLabel: WebVTTSourceLabelBox?

    public init(
        dataReferenceIndex: UInt16 = 1,
        configuration: WebVTTConfigurationBox,
        sourceLabel: WebVTTSourceLabelBox? = nil
    ) {
        self.dataReferenceIndex = dataReferenceIndex
        self.configuration = configuration
        self.sourceLabel = sourceLabel
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> WebVTTSampleEntry {
        try reader.skip(6)  // reserved
        let dataRefIdx = try reader.readUInt16()

        var configuration: WebVTTConfigurationBox?
        var sourceLabel: WebVTTSourceLabelBox?
        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            let childHeader = try isoBoxReader.parseBoxHeader(&reader)
            switch childHeader.type {
            case WebVTTConfigurationBox.boxType:
                configuration = try await WebVTTConfigurationBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case WebVTTSourceLabelBox.boxType:
                sourceLabel = try await WebVTTSourceLabelBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            default:
                _ = try ISOBoxOpaque.parse(reader: &reader)
            }
        }

        guard let resolvedConfig = configuration else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "wvtt missing mandatory vttC child"
            )
        }
        return WebVTTSampleEntry(
            dataReferenceIndex: dataRefIdx,
            configuration: resolvedConfig,
            sourceLabel: sourceLabel
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeZeros(6)  // reserved
            body.writeUInt16(dataReferenceIndex)
            configuration.encode(to: &body)
            sourceLabel?.encode(to: &body)
        }
    }
}
