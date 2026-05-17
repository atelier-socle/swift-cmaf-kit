// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleDependencyTypeBox (sdtp)
//
// Reference: ISO/IEC 14496-12 §8.6.4 (independent and disposable samples box).
//
// Each entry is one byte encoding four 2-bit fields: is_leading,
// sample_depends_on, sample_is_depended_on, sample_has_redundancy. The box
// has no explicit entry_count; the entry count is implied by the track's
// sample count (from `stsz` or `stz2`). The parser consumes all remaining
// bytes of the box body.

import Foundation

/// One sample's dependency information.
public struct SampleDependencyEntry: Sendable, Hashable {
    /// Two-bit classification of a sample's leading status.
    public enum LeadingClass: UInt8, Sendable, Hashable {
        /// Unknown.
        case unknown = 0
        /// This sample leads with a dependency on samples outside the GOP.
        case leadingDependent = 1
        /// This sample is not a leading sample.
        case notLeading = 2
        /// This sample leads without external dependencies.
        case leadingIndependent = 3
    }

    public let isLeading: LeadingClass
    public let dependsOn: SampleDependencyInfo.DependencyClass
    public let isDependedOn: SampleDependencyInfo.DependencyClass
    public let hasRedundancy: SampleDependencyInfo.DependencyClass

    public init(
        isLeading: LeadingClass,
        dependsOn: SampleDependencyInfo.DependencyClass,
        isDependedOn: SampleDependencyInfo.DependencyClass,
        hasRedundancy: SampleDependencyInfo.DependencyClass
    ) {
        self.isLeading = isLeading
        self.dependsOn = dependsOn
        self.isDependedOn = isDependedOn
        self.hasRedundancy = hasRedundancy
    }

    /// Decode one entry from its single-byte on-wire form.
    internal init(rawByte: UInt8) {
        let leadingBits = (rawByte >> 6) & 0x03
        let dependsBits = (rawByte >> 4) & 0x03
        let dependedBits = (rawByte >> 2) & 0x03
        let redundancyBits = rawByte & 0x03
        self.isLeading = LeadingClass(rawValue: leadingBits) ?? .unknown
        self.dependsOn = SampleDependencyInfo.DependencyClass(rawValue: dependsBits) ?? .unknown
        self.isDependedOn = SampleDependencyInfo.DependencyClass(rawValue: dependedBits) ?? .unknown
        self.hasRedundancy = SampleDependencyInfo.DependencyClass(rawValue: redundancyBits) ?? .unknown
    }

    /// Encode this entry to its single-byte on-wire form.
    internal var rawByte: UInt8 {
        let leadingBits = isLeading.rawValue & 0x03
        let dependsBits = dependsOn.rawValue & 0x03
        let dependedBits = isDependedOn.rawValue & 0x03
        let redundancyBits = hasRedundancy.rawValue & 0x03
        return (leadingBits << 6) | (dependsBits << 4) | (dependedBits << 2) | redundancyBits
    }
}

/// A lazy view over the entries of a ``SampleDependencyTypeBox``.
///
/// Reference: ISO/IEC 14496-12 §8.6.4.
///
/// `SampleDependencyTable` conforms to `RandomAccessCollection` and is
/// backed directly by the on-wire byte slice (one byte per entry).
/// Entries are decoded on demand at O(1) cost per index. Round-trip
/// re-emits the raw bytes verbatim.
public struct SampleDependencyTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = SampleDependencyEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> SampleDependencyEntry {
        precondition(
            position >= 0 && position < count,
            "SampleDependencyTable: index \(position) out of range 0..<\(count)"
        )
        let byte = rawEntries.readUInt8(at: position)
        return SampleDependencyEntry(rawByte: byte)
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(entries: [SampleDependencyEntry]) {
        var bytes = Data()
        bytes.reserveCapacity(entries.count)
        for entry in entries {
            bytes.append(entry.rawByte)
        }
        self.init(count: entries.count, rawEntries: bytes)
    }
}

extension SampleDependencyTable: LazyTableData {
    internal static var entryStride: Int { 1 }
}

/// Independent and disposable samples box.
///
/// The entry count of `sdtp` is not stored explicitly in the box; it is
/// determined by the track's sample count from `stsz` or `stz2`. CMAFKit's
/// `sdtp` parser consumes all remaining bytes of the box body, which lets
/// the box round-trip in isolation; consumers cross-checking against the
/// expected sample count perform that check separately.
public struct SampleDependencyTypeBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "sdtp"

    public let version: UInt8
    public let flags: UInt32
    public let table: SampleDependencyTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: SampleDependencyTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SampleDependencyTypeBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        // sdtp has no explicit entry_count; consume all remaining bytes.
        let rawEntries = reader.readToEnd()
        let table = SampleDependencyTable(count: rawEntries.count, rawEntries: rawEntries)
        return SampleDependencyTypeBox(version: version, flags: flags, table: table)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeData(table.rawEntries)
        }
    }
}
