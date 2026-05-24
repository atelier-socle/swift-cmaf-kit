// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MultiLayerHEVCConfiguration
//
// Reference: ISO/IEC 14496-15 §I.7 (Multi-Layer HEVC Configuration
// Record), §8.4 (Multi-layer HEVC sample entry storage). ITU-T H.265 §F
// (Multi-Layer Extensions), §I (3D Main Profile).
//
// Carries the per-layer decoder configuration records, layer dependency
// graph, view / aux identifiers, and output layer sets needed by an
// `MVHEVCSampleEntry` (`hvc2`).
//
// CMAFKit-canonical subset of ISO/IEC 14496-15 §I.7 — ships the fields
// required for Apple HEVC Stereo Video Profile (Apple Vision Pro spatial
// video) and standard multi-view scenarios. Unknown trailing bytes are
// preserved in `multiLayerExtensionData` for forward compatibility.

import Foundation

/// Multi-Layer HEVC Configuration Record per ISO/IEC 14496-15 §I.7.
///
/// Carried inside an ``MVHEVCSampleEntry`` (`hvc2`) when the `hvcC`
/// extension box does not fully describe the multi-layer structure of
/// the stream. The record declares:
/// - per-layer decoder configuration records (base + optional extension),
/// - the layer identifier / temporal-identifier vectors,
/// - the layer dependency graph (reuses ``LayerDependency``),
/// - per-view / per-aux scalability identifiers,
/// - the output layer sets referenced by the multi-layer stream.
///
/// References:
/// - ISO/IEC 14496-15 §I.7 — Multi-Layer HEVC Configuration Record
/// - ISO/IEC 14496-15 §8.4 — Multi-layer HEVC sample entry storage
/// - ITU-T H.265 §F — Multi-Layer Extensions
/// - ITU-T H.265 §I — 3D Main Profile
public struct MultiLayerHEVCConfiguration: Sendable, Equatable, Hashable {

    /// The base-layer decoder configuration record (existing 0.1.0 type — reused).
    public let baseLayer: HEVCDecoderConfigurationRecord

    /// Optional enhancement-layer decoder configuration record.
    ///
    /// `nil` for streams that carry the extension layer's parameter sets
    /// inside the base layer's `hvcC` (rare) or that use a single multi-layer
    /// ID throughout (Apple Vision Pro Spatial Video stereo-layered shape).
    public let extensionLayer: HEVCDecoderConfigurationRecord?

    /// `nuh_layer_id` values for each layer in this configuration.
    /// Length is the configuration's layer count; layer 0 is the base.
    public let layerIDs: [UInt8]

    /// `nuh_temporal_id_plus1 - 1` values per layer. Length matches
    /// ``layerIDs``.
    public let temporalIDs: [UInt8]

    /// Layer dependencies per ITU-T H.265 §F.7.4.3.1 — reuses the
    /// ``LayerDependency`` value type.
    public let layerDependencies: [LayerDependency]

    /// `view_id_val[]` per ITU-T H.265 §I.7.3.2.1.
    /// Empty when the stream is not multi-view.
    public let viewIDs: [UInt16]

    /// `aux_id[]` per ITU-T H.265 §F.7.4.3.1 — auxiliary layer identifiers
    /// (alpha plane, depth, etc.). Empty when no auxiliary layers are
    /// present.
    public let auxIDs: [UInt8]

    /// `output_layer_set_idx[]` references per ITU-T H.265 §F.7.4.3.1.
    /// Empty for single-OLS streams.
    public let outputLayerSetIDs: [UInt8]

    /// Opaque preservation of any unknown / future-defined trailing bytes
    /// per ISO/IEC 14496-15 §I.7. Empty for canonical CMAFKit-generated
    /// records; non-empty when the parser encountered bytes beyond the
    /// fields modelled by this struct.
    public let multiLayerExtensionData: Data

    public init(
        baseLayer: HEVCDecoderConfigurationRecord,
        extensionLayer: HEVCDecoderConfigurationRecord? = nil,
        layerIDs: [UInt8],
        temporalIDs: [UInt8],
        layerDependencies: [LayerDependency],
        viewIDs: [UInt16] = [],
        auxIDs: [UInt8] = [],
        outputLayerSetIDs: [UInt8] = [],
        multiLayerExtensionData: Data = .init()
    ) {
        precondition(
            !layerIDs.isEmpty,
            "MultiLayerHEVCConfiguration requires at least one layer"
        )
        precondition(
            layerIDs.count == temporalIDs.count,
            "MultiLayerHEVCConfiguration.temporalIDs.count must equal layerIDs.count"
        )
        self.baseLayer = baseLayer
        self.extensionLayer = extensionLayer
        self.layerIDs = layerIDs
        self.temporalIDs = temporalIDs
        self.layerDependencies = layerDependencies
        self.viewIDs = viewIDs
        self.auxIDs = auxIDs
        self.outputLayerSetIDs = outputLayerSetIDs
        self.multiLayerExtensionData = multiLayerExtensionData
    }

    /// Parse a Multi-Layer HEVC Configuration Record from a binary reader
    /// positioned at the start of the record body (i.e., just inside the
    /// `mhcC` or similar wrapper box for the multi-layer config).
    ///
    /// Layout (CMAFKit-canonical):
    ///
    /// ```text
    /// configurationSize       : UInt32 (total record size, including this field)
    /// layerCount              : UInt8
    /// presenceFlags           : UInt8
    ///   bit 0 = extensionLayer present
    ///   bit 1 = viewIDs present
    ///   bit 2 = auxIDs present
    ///   bit 3 = outputLayerSetIDs present
    /// baseLayer                                 (HEVCDecoderConfigurationRecord)
    /// [extensionLayer if flag 0]                (HEVCDecoderConfigurationRecord)
    /// layerIDs[layerCount]    : UInt8 each
    /// temporalIDs[layerCount] : UInt8 each
    /// dependencyCount         : UInt8
    /// for each dependency:
    ///   layerID               : UInt8
    ///   depCount              : UInt8
    ///   depIDs[depCount]      : UInt8 each
    /// [viewIDs if flag 1]
    ///   viewCount             : UInt8
    ///   viewIDs[viewCount]    : UInt16 each
    /// [auxIDs if flag 2]
    ///   auxCount              : UInt8
    ///   auxIDs[auxCount]      : UInt8 each
    /// [outputLayerSetIDs if flag 3]
    ///   olsCount              : UInt8
    ///   olsIDs[olsCount]      : UInt8 each
    /// remaining bytes → multiLayerExtensionData
    /// ```
    public static func parse(
        from reader: inout BinaryReader
    ) async throws -> MultiLayerHEVCConfiguration {
        let recordStart = reader.offset
        let recordSize = try reader.readUInt32()
        guard recordSize >= 6 else {
            throw MultiLayerHEVCConfigurationError.malformedRecord(
                reason: "record size \(recordSize) smaller than minimum header"
            )
        }
        let layerCount = try reader.readUInt8()
        guard layerCount >= 1 else {
            throw MultiLayerHEVCConfigurationError.missingBaseLayerConfiguration
        }
        let flags = try reader.readUInt8()

        let baseConfig = try await Self.parseEmbeddedRecord(from: &reader)
        var extensionConfig: HEVCDecoderConfigurationRecord?
        if flags & Self.flagExtensionLayer != 0 {
            extensionConfig = try await Self.parseEmbeddedRecord(from: &reader)
        }

        var layerIDs: [UInt8] = []
        layerIDs.reserveCapacity(Int(layerCount))
        for _ in 0..<Int(layerCount) {
            layerIDs.append(try reader.readUInt8())
        }
        var temporalIDs: [UInt8] = []
        temporalIDs.reserveCapacity(Int(layerCount))
        for _ in 0..<Int(layerCount) {
            temporalIDs.append(try reader.readUInt8())
        }

        let depCount = try reader.readUInt8()
        var dependencies: [LayerDependency] = []
        dependencies.reserveCapacity(Int(depCount))
        for _ in 0..<Int(depCount) {
            let depLayerID = try reader.readUInt8()
            let depRefCount = try reader.readUInt8()
            var refs: [UInt8] = []
            refs.reserveCapacity(Int(depRefCount))
            for _ in 0..<Int(depRefCount) {
                refs.append(try reader.readUInt8())
            }
            dependencies.append(
                LayerDependency(layerID: depLayerID, dependsOnLayerIDs: refs)
            )
        }

        var viewIDs: [UInt16] = []
        if flags & Self.flagViewIDs != 0 {
            let viewCount = try reader.readUInt8()
            viewIDs.reserveCapacity(Int(viewCount))
            for _ in 0..<Int(viewCount) {
                viewIDs.append(try reader.readUInt16())
            }
        }

        var auxIDs: [UInt8] = []
        if flags & Self.flagAuxIDs != 0 {
            let auxCount = try reader.readUInt8()
            auxIDs.reserveCapacity(Int(auxCount))
            for _ in 0..<Int(auxCount) {
                auxIDs.append(try reader.readUInt8())
            }
        }

        var outputLayerSetIDs: [UInt8] = []
        if flags & Self.flagOutputLayerSetIDs != 0 {
            let olsCount = try reader.readUInt8()
            outputLayerSetIDs.reserveCapacity(Int(olsCount))
            for _ in 0..<Int(olsCount) {
                outputLayerSetIDs.append(try reader.readUInt8())
            }
        }

        let consumed = reader.offset - recordStart
        let remaining = Int(recordSize) - consumed
        var tail = Data()
        if remaining > 0 {
            tail = try reader.readData(count: remaining)
        } else if remaining < 0 {
            throw MultiLayerHEVCConfigurationError.malformedRecord(
                reason: "record body overran declared size by \(-remaining) bytes"
            )
        }

        if layerIDs.count != Int(layerCount) {
            throw MultiLayerHEVCConfigurationError.inconsistentLayerCount(
                declared: Int(layerCount), parsed: layerIDs.count
            )
        }

        return MultiLayerHEVCConfiguration(
            baseLayer: baseConfig,
            extensionLayer: extensionConfig,
            layerIDs: layerIDs,
            temporalIDs: temporalIDs,
            layerDependencies: dependencies,
            viewIDs: viewIDs,
            auxIDs: auxIDs,
            outputLayerSetIDs: outputLayerSetIDs,
            multiLayerExtensionData: tail
        )
    }

    /// Encode the record back to bytes per the CMAFKit-canonical layout
    /// described in ``parse(from:)``. Round-trip with ``parse(from:)`` is
    /// byte-identical for canonical inputs.
    ///
    /// Non-throwing — the record's structural invariants are enforced at
    /// construction time by the designated initializer.
    public func encode(to writer: inout BinaryWriter) {
        // Build the body first so we can prepend the total record size.
        var body = BinaryWriter()
        body.writeUInt8(UInt8(layerIDs.count))

        var flags: UInt8 = 0
        if extensionLayer != nil { flags |= Self.flagExtensionLayer }
        if !viewIDs.isEmpty { flags |= Self.flagViewIDs }
        if !auxIDs.isEmpty { flags |= Self.flagAuxIDs }
        if !outputLayerSetIDs.isEmpty { flags |= Self.flagOutputLayerSetIDs }
        body.writeUInt8(flags)

        Self.encodeEmbeddedRecord(baseLayer, into: &body)
        if let extensionLayer {
            Self.encodeEmbeddedRecord(extensionLayer, into: &body)
        }
        for id in layerIDs { body.writeUInt8(id) }
        for id in temporalIDs { body.writeUInt8(id) }

        body.writeUInt8(UInt8(layerDependencies.count))
        for dep in layerDependencies {
            body.writeUInt8(dep.layerID)
            body.writeUInt8(UInt8(dep.dependsOnLayerIDs.count))
            for refID in dep.dependsOnLayerIDs {
                body.writeUInt8(refID)
            }
        }

        if !viewIDs.isEmpty {
            body.writeUInt8(UInt8(viewIDs.count))
            for value in viewIDs { body.writeUInt16(value) }
        }
        if !auxIDs.isEmpty {
            body.writeUInt8(UInt8(auxIDs.count))
            for value in auxIDs { body.writeUInt8(value) }
        }
        if !outputLayerSetIDs.isEmpty {
            body.writeUInt8(UInt8(outputLayerSetIDs.count))
            for value in outputLayerSetIDs { body.writeUInt8(value) }
        }
        body.writeData(multiLayerExtensionData)

        let totalRecordSize = 4 + body.data.count  // 4 = size of UInt32 size field
        writer.writeUInt32(UInt32(totalRecordSize))
        writer.writeData(body.data)
    }

    // MARK: - Internal helpers

    private static let flagExtensionLayer: UInt8 = 0x01
    private static let flagViewIDs: UInt8 = 0x02
    private static let flagAuxIDs: UInt8 = 0x04
    private static let flagOutputLayerSetIDs: UInt8 = 0x08

    /// Embed an `HEVCDecoderConfigurationRecord` inside the multi-layer
    /// record as a `(size: UInt32, bytes: [UInt8])` length-prefixed blob.
    /// The existing 0.1.0 record encoder targets the full `hvcC` box
    /// layout (with an 8-byte header) — we strip the header here.
    private static func encodeEmbeddedRecord(
        _ record: HEVCDecoderConfigurationRecord,
        into writer: inout BinaryWriter
    ) {
        var inner = BinaryWriter()
        record.encode(to: &inner)
        // The encoded bytes are the full hvcC box (8-byte header + body).
        // For embedded carriage we keep them verbatim — the parse path
        // mirrors this by treating the embedded blob as a single hvcC box.
        writer.writeUInt32(UInt32(inner.data.count))
        writer.writeData(inner.data)
    }

    private static func parseEmbeddedRecord(
        from reader: inout BinaryReader
    ) async throws -> HEVCDecoderConfigurationRecord {
        let blobSize = try reader.readUInt32()
        guard blobSize >= 8 else {
            throw MultiLayerHEVCConfigurationError.malformedRecord(
                reason: "embedded hvcC blob size \(blobSize) smaller than box header"
            )
        }
        let blobBytes = try reader.readData(count: Int(blobSize))
        var inner = BinaryReader(blobBytes)
        let isoBoxReader = ISOBoxReader()
        let header = try isoBoxReader.parseBoxHeader(&inner)
        guard header.type == HEVCDecoderConfigurationRecord.boxType else {
            throw MultiLayerHEVCConfigurationError.malformedRecord(
                reason: "embedded record FourCC \(header.type) is not hvcC"
            )
        }
        let registry = await BoxRegistry.defaultRegistry()
        return try await HEVCDecoderConfigurationRecord.parse(
            reader: &inner, header: header, registry: registry
        )
    }
}

/// Typed errors thrown by
/// ``MultiLayerHEVCConfiguration/parse(from:)`` and
/// ``MultiLayerHEVCConfiguration/encode(to:)``.
public enum MultiLayerHEVCConfigurationError: Error, Equatable {
    /// The record is truncated or violates a structural invariant.
    case malformedRecord(reason: String)

    /// The `layerCount` field disagrees with the actual number of layer
    /// identifiers parsed from the record body.
    case inconsistentLayerCount(declared: Int, parsed: Int)

    /// The base-layer decoder configuration is missing — at least one
    /// layer is required per ISO/IEC 14496-15 §I.7.
    case missingBaseLayerConfiguration
}
