// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EncryptedVideoSampleEntry (encv)
//
// Reference: ISO/IEC 23001-7 §4 (Common Encryption original sample-entry
// preservation pattern).
//
// `encv` replaces the original codec FourCC for protected content. The
// original codec's configuration record and a `sinf` (ProtectionSchemeInfo)
// child describe both the original codec and the encryption scheme. In
// this release the `sinf` family of boxes is preserved opaquely via
// ``ISOBoxOpaque`` and round-trips byte-perfectly; the typed
// implementation lands once the encryption-box checkpoint is delivered.

import Foundation

/// Encrypted video sample entry (`encv`).
public struct EncryptedVideoSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "encv"

    public let visualFields: VisualSampleEntryFields
    /// Children (`sinf`, the original codec configuration record, etc.)
    /// preserved opaquely. Typed wrappers land in a later checkpoint.
    public let opaqueChildren: [ISOBoxOpaque]
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        opaqueChildren: [ISOBoxOpaque],
        extensions: VideoSampleEntryExtensions = VideoSampleEntryExtensions()
    ) {
        self.visualFields = visualFields
        self.opaqueChildren = opaqueChildren
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> EncryptedVideoSampleEntry {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        // Drain the remainder of the body. Recognised extension FourCCs
        // (colour info, HDR metadata, pasp, clap, btrt, dvcC, dvvC) are
        // routed to the typed extensions container; anything else (most
        // notably the `sinf` subtree carrying the encryption metadata)
        // is captured opaquely.
        var opaqueChildren: [ISOBoxOpaque] = []
        var color: ColorInformationBox?
        var mdcv: MasteringDisplayColourVolumeBox?
        var clli: ContentLightLevelBox?
        var dvcC: DolbyVisionConfigurationBox?
        var dvvC: DolbyVisionELConfigurationBox?
        var pasp: PixelAspectRatioBox?
        var clap: CleanApertureBox?
        var btrt: BitRateBox?

        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            var peekReader = reader
            let childHeader = try isoBoxReader.parseBoxHeader(&peekReader)
            switch childHeader.type {
            case ColorInformationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                color = try await ColorInformationBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case MasteringDisplayColourVolumeBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                mdcv = try await MasteringDisplayColourVolumeBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case ContentLightLevelBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                clli = try await ContentLightLevelBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case DolbyVisionConfigurationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                dvcC = try await DolbyVisionConfigurationBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case DolbyVisionELConfigurationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                dvvC = try await DolbyVisionELConfigurationBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case PixelAspectRatioBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                pasp = try await PixelAspectRatioBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case CleanApertureBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                clap = try await CleanApertureBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case BitRateBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                btrt = try await BitRateBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            default:
                opaqueChildren.append(try ISOBoxOpaque.parse(reader: &reader))
            }
        }

        let exts = VideoSampleEntryExtensions(
            colorInformation: color,
            masteringDisplay: mdcv,
            contentLightLevel: clli,
            dolbyVisionConfiguration: dvcC,
            dolbyVisionELConfiguration: dvvC,
            pixelAspectRatio: pasp,
            cleanAperture: clap,
            bitRate: btrt
        )
        return EncryptedVideoSampleEntry(
            visualFields: fields,
            opaqueChildren: opaqueChildren,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            visualFields.encode(to: &body)
            for child in opaqueChildren {
                child.writeRaw(to: &body)
            }
            extensions.encode(to: &body)
        }
    }
}
