// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MVHEVCSampleEntry (hvc2)
//
// Reference: ISO/IEC 14496-15 §8.4 (Multi-layer HEVC sample entry), §I
// (multi-view storage), Apple HEVC Stereo Video Profile (visionOS Spatial
// Video — vexu / stri / hero composition), ISO/IEC 14496-12 §8.5.2 (base
// visual sample entry).
//
// Wire layout (after the standard 8-byte box header):
//
//   ┌───────────────────────────────────────────────────────────────────┐
//   │ VisualSampleEntryFields                                           │
//   │ child boxes (in order on the wire):                               │
//   │   hvcC (base layer)                       — mandatory             │
//   │   hvcC (extension layer)                  — optional, when 2 hvcC │
//   │   vexu (ViewExtendedUsageBox)             — mandatory per Apple   │
//   │   stri (StereoInformationBox)             — optional              │
//   │   hero (HeroEyeInformationBox)            — optional              │
//   │   mhcC (MultiLayerHEVCConfiguration)      — optional              │
//   │   <unknown boxes preserved as optionalBoxes>                      │
//   └───────────────────────────────────────────────────────────────────┘
//
// Equatable / Hashable are synthesized — every field is a typed value
// type or a typed Optional thereof. `optionalBoxes` is `[ISOBoxOpaque]`
// which conforms to Equatable + Hashable, so the synthesis composes
// cleanly.

import Foundation

/// Multi-Layer HEVC sample entry (`hvc2`) per ISO/IEC 14496-15 §8.4.
///
/// Composes the visual sample entry header, the base-layer `hvcC`
/// configuration, an optional extension-layer `hvcC`, Apple HEVC Stereo
/// Video Profile boxes (`vexu` mandatory for visionOS Spatial Video;
/// `stri` and `hero` optional), and an optional `mhcC` Multi-Layer HEVC
/// Configuration Record.
///
/// References:
/// - ISO/IEC 14496-15 §8.4 — Multi-layer HEVC sample entry
/// - ISO/IEC 14496-15 §I — Multi-view storage
/// - Apple HEVC Stereo Video Profile — `vexu` / `stri` / `hero` composition
/// - ISO/IEC 14496-12 §8.5.2 — base visual sample entry
public struct MVHEVCSampleEntry: ISOBox, Sendable, Equatable, Hashable {

    public static let boxType: FourCC = "hvc2"

    /// FourCC under which the multi-layer config record is wrapped inside
    /// the `hvc2` sample entry. CMAFKit-canonical (`mhcC` mirrors `hvcC`
    /// naming for the multi-layer record).
    public static let multiLayerConfigBoxType: FourCC = "mhcC"

    /// The shared visual sample entry header (width, height, depth,
    /// compressor name, etc.). Reuses the existing 0.1.0 type.
    public let visualFields: VisualSampleEntryFields

    /// The base-layer HEVC configuration record (`hvcC`). Reuses the
    /// existing 0.1.0 type — both the record and the box are the same
    /// Swift value here.
    public let hvcCBase: HEVCDecoderConfigurationRecord

    /// Optional extension-layer HEVC configuration record (a second
    /// `hvcC`). `nil` when the multi-layer carriage uses a single `hvcC`
    /// + ``multiLayerConfiguration`` for the extension-layer info.
    public let hvcCExtension: HEVCDecoderConfigurationRecord?

    /// View Extended Usage Box — **mandatory** for Apple Vision Pro
    /// Spatial Video per the Apple HEVC Stereo Video Profile.
    public let vexu: ViewExtendedUsageBox

    /// Optional Stereo Information Box.
    public let stri: StereoInformationBox?

    /// Optional Hero Eye Information Box.
    public let hero: HeroEyeInformationBox?

    /// Optional Multi-Layer HEVC Configuration Record (ISO/IEC 14496-15
    /// §I.7). Carried as the `mhcC` child box when the `hvcC` extension
    /// does not fully describe the layer structure.
    public let multiLayerConfiguration: MultiLayerHEVCConfiguration?

    /// Shared visual-sample-entry extension boxes (color info, mastering
    /// display, content light level, Dolby Vision configurations, pixel
    /// aspect ratio, clean aperture, bit-rate hint). Reuses the existing
    /// 0.1.0 type — parity with ``HEVCSampleEntry``.
    public let extensions: VideoSampleEntryExtensions

    /// Extensibility hook — any additional unknown / future-defined
    /// child boxes encountered during parsing that are not consumed by
    /// ``extensions``, preserved verbatim for byte-identical round-trip.
    public let optionalBoxes: [ISOBoxOpaque]

    public init(
        visualFields: VisualSampleEntryFields,
        hvcCBase: HEVCDecoderConfigurationRecord,
        hvcCExtension: HEVCDecoderConfigurationRecord? = nil,
        vexu: ViewExtendedUsageBox,
        stri: StereoInformationBox? = nil,
        hero: HeroEyeInformationBox? = nil,
        multiLayerConfiguration: MultiLayerHEVCConfiguration? = nil,
        extensions: VideoSampleEntryExtensions = VideoSampleEntryExtensions(),
        optionalBoxes: [ISOBoxOpaque] = []
    ) {
        self.visualFields = visualFields
        self.hvcCBase = hvcCBase
        self.hvcCExtension = hvcCExtension
        self.vexu = vexu
        self.stri = stri
        self.hero = hero
        self.multiLayerConfiguration = multiLayerConfiguration
        self.extensions = extensions
        self.optionalBoxes = optionalBoxes
    }

    /// Box-registry parse hook.
    ///
    /// Per ISO/IEC 14496-15 §8.4: when the entry carries two `hvcC` child
    /// boxes the first is the base, the second is the extension. Apple's
    /// HEVC Stereo Video Profile additions follow in any order; CMAFKit
    /// walks the child boxes by FourCC and binds each to the typed
    /// property.
    ///
    /// - Throws:
    ///   - ``MVHEVCSampleEntryError/missingBaseHvcC`` — no `hvcC` child found.
    ///   - ``MVHEVCSampleEntryError/missingViewExtendedUsage`` — no `vexu`
    ///     child found (mandatory per Apple HEVC Stereo Video Profile).
    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MVHEVCSampleEntry {
        let visualFields = try VisualSampleEntryFields.parse(reader: &reader)

        var hvcCBase: HEVCDecoderConfigurationRecord?
        var hvcCExtension: HEVCDecoderConfigurationRecord?
        var vexu: ViewExtendedUsageBox?
        var stri: StereoInformationBox?
        var hero: HeroEyeInformationBox?
        var multiLayerConfiguration: MultiLayerHEVCConfiguration?

        let isoBoxReader = ISOBoxReader()
        // Phase 1: consume MV-HEVC-specific child boxes (hvcC base + ext,
        // vexu, stri, hero, mhcC). Stop the loop on the first FourCC that
        // belongs to the shared VideoSampleEntryExtensions surface so
        // that helper can take over.
        let mvhevcChildFourCCs: Set<FourCC> = [
            HEVCDecoderConfigurationRecord.boxType,
            ViewExtendedUsageBox.boxType,
            StereoInformationBox.boxType,
            HeroEyeInformationBox.boxType,
            Self.multiLayerConfigBoxType
        ]
        while reader.remaining >= 8 {
            var peek = reader
            let childHeader = try isoBoxReader.parseBoxHeader(&peek)
            guard mvhevcChildFourCCs.contains(childHeader.type) else { break }
            _ = try isoBoxReader.parseBoxHeader(&reader)
            switch childHeader.type {
            case HEVCDecoderConfigurationRecord.boxType:
                let parsed = try await HEVCDecoderConfigurationRecord.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
                if hvcCBase == nil {
                    hvcCBase = parsed
                } else if hvcCExtension == nil {
                    hvcCExtension = parsed
                } else {
                    throw MVHEVCSampleEntryError.unexpectedExtraHvcC
                }
            case ViewExtendedUsageBox.boxType:
                vexu = try await ViewExtendedUsageBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case StereoInformationBox.boxType:
                stri = try await StereoInformationBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case HeroEyeInformationBox.boxType:
                hero = try await HeroEyeInformationBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case Self.multiLayerConfigBoxType:
                let bodySize = Int(childHeader.size) - childHeader.headerSize
                let bodyBytes = try reader.readData(count: bodySize)
                var inner = BinaryReader(bodyBytes)
                multiLayerConfiguration =
                    try await MultiLayerHEVCConfiguration
                    .parse(from: &inner)
            default:
                break  // unreachable — filtered above
            }
        }

        // Phase 2: standard visual-sample-entry extensions (color, pasp,
        // clap, btrt, Dolby Vision configs). Mirrors HEVCSampleEntry.
        let (extensions, opaqueTail) = try await VideoSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )

        guard let resolvedBase = hvcCBase else {
            throw MVHEVCSampleEntryError.missingBaseHvcC
        }
        guard let resolvedVexu = vexu else {
            throw MVHEVCSampleEntryError.missingViewExtendedUsage
        }

        return MVHEVCSampleEntry(
            visualFields: visualFields,
            hvcCBase: resolvedBase,
            hvcCExtension: hvcCExtension,
            vexu: resolvedVexu,
            stri: stri,
            hero: hero,
            multiLayerConfiguration: multiLayerConfiguration,
            extensions: extensions,
            optionalBoxes: opaqueTail
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            visualFields.encode(to: &body)
            hvcCBase.encode(to: &body)
            if let hvcCExtension {
                hvcCExtension.encode(to: &body)
            }
            vexu.encode(to: &body)
            if let stri {
                stri.encode(to: &body)
            }
            if let hero {
                hero.encode(to: &body)
            }
            if let multiLayerConfiguration {
                var mlBody = BinaryWriter()
                multiLayerConfiguration.encode(to: &mlBody)
                body.writeBox(type: Self.multiLayerConfigBoxType, body: mlBody.data)
            }
            extensions.encode(to: &body)
            for opaque in optionalBoxes {
                opaque.writeRaw(to: &body)
            }
        }
    }
}

/// Typed errors thrown by ``MVHEVCSampleEntry/parse(reader:header:registry:)``.
public enum MVHEVCSampleEntryError: Error, Equatable {
    /// No `hvcC` child box was found — at least the base-layer
    /// configuration is required per ISO/IEC 14496-15 §8.4.
    case missingBaseHvcC

    /// Three or more `hvcC` child boxes encountered — only base + optional
    /// extension are supported per ISO/IEC 14496-15 §8.4.
    case unexpectedExtraHvcC

    /// No `vexu` child box was found — the View Extended Usage Box is
    /// mandatory per Apple HEVC Stereo Video Profile §3.1.
    case missingViewExtendedUsage
}
