// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - LazyTableData
//
// Internal contract for fixed-stride lazy tables backed by a Data slice.
// Conforming public types in the SampleTableBoxes subdirectory expose
// entries through O(1) indexed access without materialising an Array of
// entries. The design avoids three concrete failure modes that an eager
// array materialisation would expose:
//   1. Memory amplification on multi-file inventories (a validator
//      inspecting thousands of files in parallel would allocate orders of
//      magnitude more memory than the files themselves);
//   2. Worst-case malformed-input behaviour (a declared entry_count near
//      UInt32.max on a tiny payload would attempt a multi-gigabyte
//      allocation before any validation could run);
//   3. Pathological cost on large files (long-form 4K content produces
//      sample tables of several megabytes that an eager design would
//      double in memory).

import Foundation

/// Internal contract for fixed-stride lazy tables.
///
/// A conforming table holds:
///   - `count`: the number of entries, validated at parse time against
///     the available bytes;
///   - `rawEntries`: the raw on-wire byte slice. For uniform-stride
///     tables this is `count * entryStride` bytes; variable-stride
///     tables (`stz2`, `padb`) document their effective byte count.
///
/// Conformers MUST NOT mutate `rawEntries`. The slice is the canonical
/// round-trip representation; `encode(to:)` on the containing box
/// re-emits it verbatim.
internal protocol LazyTableData: Sendable {
    /// Size in bytes of a single entry on the wire. Fixed at compile time
    /// per table type. Variable-stride tables surface a synthetic value
    /// here and document the effective byte count separately.
    static var entryStride: Int { get }

    /// Number of entries.
    var count: Int { get }

    /// Raw byte slice.
    var rawEntries: Data { get }
}

// MARK: - Big-endian read helpers on Data

extension Data {

    internal func readUInt8(at offset: Int) -> UInt8 {
        return self[startIndex.advanced(by: offset)]
    }

    internal func readUInt16BigEndian(at offset: Int) -> UInt16 {
        let base = startIndex.advanced(by: offset)
        let b0 = UInt16(self[base])
        let b1 = UInt16(self[base.advanced(by: 1)])
        return (b0 << 8) | b1
    }

    internal func readUInt24BigEndian(at offset: Int) -> UInt32 {
        let base = startIndex.advanced(by: offset)
        let b0 = UInt32(self[base])
        let b1 = UInt32(self[base.advanced(by: 1)])
        let b2 = UInt32(self[base.advanced(by: 2)])
        return (b0 << 16) | (b1 << 8) | b2
    }

    internal func readUInt32BigEndian(at offset: Int) -> UInt32 {
        let base = startIndex.advanced(by: offset)
        let b0 = UInt32(self[base])
        let b1 = UInt32(self[base.advanced(by: 1)])
        let b2 = UInt32(self[base.advanced(by: 2)])
        let b3 = UInt32(self[base.advanced(by: 3)])
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    internal func readInt32BigEndian(at offset: Int) -> Int32 {
        return Int32(bitPattern: readUInt32BigEndian(at: offset))
    }

    internal func readUInt64BigEndian(at offset: Int) -> UInt64 {
        let high = UInt64(readUInt32BigEndian(at: offset))
        let low = UInt64(readUInt32BigEndian(at: offset + 4))
        return (high << 32) | low
    }
}

// MARK: - Big-endian append helpers on Data

extension Data {

    internal mutating func appendUInt8(_ value: UInt8) {
        append(value)
    }

    internal mutating func appendUInt16BigEndian(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    internal mutating func appendUInt24BigEndian(_ value: UInt32) {
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    internal mutating func appendUInt32BigEndian(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    internal mutating func appendInt32BigEndian(_ value: Int32) {
        appendUInt32BigEndian(UInt32(bitPattern: value))
    }

    internal mutating func appendUInt64BigEndian(_ value: UInt64) {
        appendUInt32BigEndian(UInt32((value >> 32) & 0xffff_ffff))
        appendUInt32BigEndian(UInt32(value & 0xffff_ffff))
    }
}
