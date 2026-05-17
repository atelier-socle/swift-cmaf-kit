// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleDescriptionBox (stsd)
//
// Reference: ISO/IEC 14496-12 §8.5.2 (sample description box).
//
// Container of sample-entry boxes describing the codec and configuration
// of each set of samples in the track. Each entry's FourCC encodes the
// codec (`avc1`, `hvc1`, `mp4a`, `stpp`, `vp09`, `av01`, …). CMAFKit
// surfaces every entry through the `SampleEntry` protocol: codec-
// specific conformers when CMAFKit ships a typed parser for the FourCC,
// or `RawSampleEntry` as the byte-perfect fallback otherwise.

import Foundation

/// Sample description box.
///
/// `stsd` differs from ordinary container boxes in that it stores an
/// explicit `entry_count` before the children. Each child is a sample
/// entry box (an ``ISOBox`` whose body starts with the 8-byte sample-
/// entry preamble: 6 reserved bytes plus a 2-byte data_reference_index).
public struct SampleDescriptionBox: ISOFullBox, Sendable {
    public static let boxType: FourCC = "stsd"

    public let version: UInt8
    public let flags: UInt32

    /// The sample entries, in the order they appear on the wire.
    public let entries: [any SampleEntry]

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        entries: [any SampleEntry]
    ) {
        self.version = version
        self.flags = flags
        self.entries = entries
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SampleDescriptionBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let entryCount = try reader.readUInt32()

        var entries: [any SampleEntry] = []
        entries.reserveCapacity(Int(entryCount))
        for _ in 0..<entryCount {
            let entry = try await parseSampleEntry(reader: &reader, registry: registry)
            entries.append(entry)
        }

        return SampleDescriptionBox(version: version, flags: flags, entries: entries)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(UInt32(entries.count))
            for entry in entries {
                entry.encode(to: &body)
            }
        }
    }

    /// Parse one sample entry from the reader.
    ///
    /// Reads the sample entry's box header, then dispatches to a typed
    /// sample-entry parser via the registry. Falls back to
    /// ``RawSampleEntry`` for any FourCC not yet registered with a typed
    /// sample-entry parser, or when the registered parser returns a box
    /// that does not conform to ``SampleEntry``.
    private static func parseSampleEntry(
        reader: inout BinaryReader,
        registry: BoxRegistry
    ) async throws -> any SampleEntry {
        let isoBoxReader = ISOBoxReader()
        let entryHeader = try isoBoxReader.parseBoxHeader(&reader)
        let bodySize = Int(entryHeader.size) - entryHeader.headerSize
        guard bodySize >= 0 else {
            throw ISOBoxError.sizeSmallerThanHeader(
                declared: entryHeader.size,
                headerSize: entryHeader.headerSize,
                type: entryHeader.type
            )
        }
        let bodyData = try reader.readData(count: bodySize)
        var bodyReader = BinaryReader(bodyData)

        // Typed sample-entry parsers live alongside codec-specific boxes
        // and register themselves through the registry. When a FourCC has
        // no typed parser, the RawSampleEntry fallback preserves the
        // entry's bytes verbatim. When a registered parser returns a box
        // that does not conform to SampleEntry, the fallback also kicks
        // in to avoid silent type mismatches.
        if let parser = await registry.parser(for: entryHeader.type) {
            let box = try await parser(&bodyReader, entryHeader, registry)
            if let sampleEntry = box as? any SampleEntry {
                return sampleEntry
            }
        }
        // Reset bodyReader before falling back — the typed parser path
        // may have consumed bytes already. Build a fresh reader over the
        // same bodyData slice.
        var fallbackReader = BinaryReader(bodyData)
        return try RawSampleEntry.parse(format: entryHeader.type, reader: &fallbackReader)
    }
}
