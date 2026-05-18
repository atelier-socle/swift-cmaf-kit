// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - VideoSampleEntryExtensions
//
// Reference: ISO/IEC 14496-12 §8.5.2 + §12.1.4–§12.1.7 (visual sample
// entry extensions) + Dolby Vision public specification.
//
// The optional set of child boxes that every video sample entry may
// carry after its codec-specific configuration record: colour info,
// HDR mastering, content light level, Dolby Vision configuration,
// pixel aspect ratio, clean aperture, and bit-rate hints.

import Foundation

/// Optional extension boxes attached to a video sample entry.
public struct VideoSampleEntryExtensions: Sendable, Equatable, Hashable {
    public let colorInformation: ColorInformationBox?
    public let masteringDisplay: MasteringDisplayColourVolumeBox?
    public let contentLightLevel: ContentLightLevelBox?
    public let dolbyVisionConfiguration: DolbyVisionConfigurationBox?
    public let dolbyVisionELConfiguration: DolbyVisionELConfigurationBox?
    public let pixelAspectRatio: PixelAspectRatioBox?
    public let cleanAperture: CleanApertureBox?
    public let bitRate: BitRateBox?

    public init(
        colorInformation: ColorInformationBox? = nil,
        masteringDisplay: MasteringDisplayColourVolumeBox? = nil,
        contentLightLevel: ContentLightLevelBox? = nil,
        dolbyVisionConfiguration: DolbyVisionConfigurationBox? = nil,
        dolbyVisionELConfiguration: DolbyVisionELConfigurationBox? = nil,
        pixelAspectRatio: PixelAspectRatioBox? = nil,
        cleanAperture: CleanApertureBox? = nil,
        bitRate: BitRateBox? = nil
    ) {
        self.colorInformation = colorInformation
        self.masteringDisplay = masteringDisplay
        self.contentLightLevel = contentLightLevel
        self.dolbyVisionConfiguration = dolbyVisionConfiguration
        self.dolbyVisionELConfiguration = dolbyVisionELConfiguration
        self.pixelAspectRatio = pixelAspectRatio
        self.cleanAperture = cleanAperture
        self.bitRate = bitRate
    }

    /// Parse zero or more extension boxes from the remainder of a video
    /// sample entry's body. Unknown FourCCs are silently ignored
    /// (preserving forward compatibility); the canonical extension set
    /// is recognised explicitly. Returns the parsed extensions plus the
    /// list of any unknown child boxes that should round-trip verbatim.
    public static func parse(
        reader: inout BinaryReader,
        registry: BoxRegistry
    ) async throws -> (VideoSampleEntryExtensions, [ISOBoxOpaque]) {
        var color: ColorInformationBox?
        var mdcv: MasteringDisplayColourVolumeBox?
        var clli: ContentLightLevelBox?
        var dvcC: DolbyVisionConfigurationBox?
        var dvvC: DolbyVisionELConfigurationBox?
        var pasp: PixelAspectRatioBox?
        var clap: CleanApertureBox?
        var btrt: BitRateBox?
        var unknown: [ISOBoxOpaque] = []

        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            var peekReader = reader
            let header = try isoBoxReader.parseBoxHeader(&peekReader)
            let bodyByteCount = Int(header.size) - header.headerSize
            switch header.type {
            case ColorInformationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                color = try await ColorInformationBox.parse(
                    reader: &reader, header: header, registry: registry
                )
                _ = bodyByteCount
            case MasteringDisplayColourVolumeBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                mdcv = try await MasteringDisplayColourVolumeBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            case ContentLightLevelBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                clli = try await ContentLightLevelBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            case DolbyVisionConfigurationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                dvcC = try await DolbyVisionConfigurationBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            case DolbyVisionELConfigurationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                dvvC = try await DolbyVisionELConfigurationBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            case PixelAspectRatioBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                pasp = try await PixelAspectRatioBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            case CleanApertureBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                clap = try await CleanApertureBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            case BitRateBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                btrt = try await BitRateBox.parse(
                    reader: &reader, header: header, registry: registry
                )
            default:
                unknown.append(try ISOBoxOpaque.parse(reader: &reader))
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
        return (exts, unknown)
    }

    /// Emit every present extension box, in a canonical order.
    public func encode(to writer: inout BinaryWriter) {
        colorInformation?.encode(to: &writer)
        masteringDisplay?.encode(to: &writer)
        contentLightLevel?.encode(to: &writer)
        dolbyVisionConfiguration?.encode(to: &writer)
        dolbyVisionELConfiguration?.encode(to: &writer)
        pixelAspectRatio?.encode(to: &writer)
        cleanAperture?.encode(to: &writer)
        bitRate?.encode(to: &writer)
    }
}
