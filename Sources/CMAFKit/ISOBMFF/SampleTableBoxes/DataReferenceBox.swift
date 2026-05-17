// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Data reference container + children
//
// This file defines three related box types per ISO/IEC 14496-12 §8.7.2:
//
//   - dref  (DataReferenceBox)       — container of data entries
//   - url   (DataEntryURLBox)        — URL-style data entry
//   - urn   (DataEntryURNBox)        — URN-style data entry
//
// The FourCCs `"url "` and `"urn "` have a trailing space, preserved on
// encode and recognised on parse. The self-contained flag bit (`0x01`)
// signals that the referenced media is in the same file as the box; in
// that case the location / name strings are empty on the wire.

import Foundation

// MARK: - dref

/// Data reference container.
///
/// Per ISO/IEC 14496-12 §8.7.2, the children of `dref` enumerate the
/// sources of the track's media data. The `sample_description_index` of
/// `stsc` selects which data reference applies to a given chunk.
public struct DataReferenceBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "dref"

    public let version: UInt8
    public let flags: UInt32
    public let entries: [any ISOBox]

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        entries: [any ISOBox]
    ) {
        self.version = version
        self.flags = flags
        self.entries = entries
    }

    /// Equality is defined as byte-equality of the encoded form.
    ///
    /// The `[any ISOBox]` storage cannot synthesise `Equatable`
    /// automatically; encoding-then-comparing is the canonical fallback
    /// and lines up with how round-trip equality is verified across the
    /// rest of the library. The cost is O(N) on the encoded length, paid
    /// only when the consumer explicitly tests equality.
    public static func == (lhs: DataReferenceBox, rhs: DataReferenceBox) -> Bool {
        if lhs.version != rhs.version || lhs.flags != rhs.flags { return false }
        var lhsWriter = BinaryWriter()
        var rhsWriter = BinaryWriter()
        lhs.encode(to: &lhsWriter)
        rhs.encode(to: &rhsWriter)
        return lhsWriter.data == rhsWriter.data
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> DataReferenceBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let entryCount = try reader.readUInt32()

        var entries: [any ISOBox] = []
        entries.reserveCapacity(Int(entryCount))
        let isoBoxReader = ISOBoxReader()
        for _ in 0..<entryCount {
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

            let entry: any ISOBox
            if let parser = await registry.parser(for: entryHeader.type) {
                entry = try await parser(&bodyReader, entryHeader, registry)
            } else {
                entry = UnknownBox(
                    actualType: entryHeader.type,
                    header: entryHeader,
                    payload: bodyData
                )
            }
            entries.append(entry)
        }

        return DataReferenceBox(version: version, flags: flags, entries: entries)
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
}

// MARK: - url

/// URL-style data entry.
///
/// FourCC: `"url "` (with trailing space). The self-contained flag
/// (`0x01`) indicates that the media data is in the same file as this
/// box; in that case, ``location`` is empty on the wire and the
/// constructor enforces that empty value.
public struct DataEntryURLBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "url "

    /// Bit 0 of `flags`: self-contained — media data is in the same file
    /// as this box.
    public static let flagSelfContained: UInt32 = 0x0000_0001

    public let version: UInt8
    public let flags: UInt32
    /// URL pointing at the media data, or the empty string when
    /// self-contained.
    public let location: String

    /// Public initialiser enforcing wire-format consistency between the
    /// self-contained flag and the location string.
    public init(
        version: UInt8 = 0,
        selfContained: Bool,
        location: String
    ) {
        if selfContained {
            precondition(
                location.isEmpty,
                "DataEntryURLBox: self-contained entries must have an empty location"
            )
        } else {
            precondition(
                !location.isEmpty,
                "DataEntryURLBox: non-self-contained entries must have a non-empty location"
            )
        }
        self.version = version
        self.flags = selfContained ? Self.flagSelfContained : 0
        self.location = location
    }

    /// `true` when bit 0 of `flags` is set.
    public var isSelfContained: Bool {
        (flags & Self.flagSelfContained) != 0
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> DataEntryURLBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let location: String
        if (flags & Self.flagSelfContained) != 0 {
            location = ""
        } else {
            location = try reader.readNullTerminatedString()
        }
        return DataEntryURLBox(version: version, flagsRaw: flags, location: location)
    }

    /// Decode-side initialiser that bypasses the public consistency
    /// precondition. The wire is the source of truth on decode.
    internal init(version: UInt8, flagsRaw: UInt32, location: String) {
        self.version = version
        self.flags = flagsRaw
        self.location = location
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            if !isSelfContained {
                body.writeNullTerminatedString(location)
            }
        }
    }
}

// MARK: - urn

/// URN-style data entry.
///
/// FourCC: `"urn "` (with trailing space). The self-contained flag
/// (`0x01`) indicates that the media data is in the same file as this
/// box; in that case, ``name`` and ``location`` are empty on the wire.
public struct DataEntryURNBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "urn "

    /// Bit 0 of `flags`: self-contained — media data is in the same file
    /// as this box.
    public static let flagSelfContained: UInt32 = 0x0000_0001

    public let version: UInt8
    public let flags: UInt32
    public let name: String
    public let location: String

    public init(
        version: UInt8 = 0,
        selfContained: Bool,
        name: String,
        location: String
    ) {
        if selfContained {
            precondition(
                name.isEmpty && location.isEmpty,
                "DataEntryURNBox: self-contained entries must have empty name and location"
            )
        }
        self.version = version
        self.flags = selfContained ? Self.flagSelfContained : 0
        self.name = name
        self.location = location
    }

    /// `true` when bit 0 of `flags` is set.
    public var isSelfContained: Bool {
        (flags & Self.flagSelfContained) != 0
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> DataEntryURNBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let name: String
        let location: String
        if (flags & Self.flagSelfContained) != 0 {
            name = ""
            location = ""
        } else {
            name = try reader.readNullTerminatedString()
            location = try reader.readNullTerminatedString()
        }
        return DataEntryURNBox(
            version: version,
            flagsRaw: flags,
            name: name,
            location: location
        )
    }

    /// Decode-side initialiser that bypasses the public consistency
    /// precondition. The wire is the source of truth on decode.
    internal init(version: UInt8, flagsRaw: UInt32, name: String, location: String) {
        self.version = version
        self.flags = flagsRaw
        self.name = name
        self.location = location
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            if !isSelfContained {
                body.writeNullTerminatedString(name)
                body.writeNullTerminatedString(location)
            }
        }
    }
}
