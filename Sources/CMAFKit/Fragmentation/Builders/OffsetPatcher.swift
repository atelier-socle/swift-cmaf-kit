// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - OffsetPatcher
//
// Reference: ISO/IEC 23001-7 §9 (SampleAuxiliaryInformationOffsetsBox)
// and ISO/IEC 14496-12 §8.7.5 (`saio` carries byte offsets into the
// containing file).
//
// Writer-side helper that records forward-reference byte locations
// (typically `saio.offsets[]` and `trun.data_offset`) while a `moof`
// is being composed, then patches the resolved values into the
// assembled segment bytes at finalisation time. The technique avoids
// the chicken-and-egg between `moof` size and `mdat` offset.

import Foundation

/// Internal helper that records 32-bit or 64-bit byte-offset patch
/// sites in a writer buffer and applies them later.
///
/// Usage pattern:
///
/// 1. Write a placeholder offset (typically `0`) to the buffer.
/// 2. Record the placeholder's byte position via ``record32(at:value:)``
///    or ``record64(at:value:)``.
/// 3. Continue building the segment.
/// 4. Call ``apply(to:)`` with the final assembled bytes; the helper
///    rewrites each recorded position with the resolved value.
internal struct OffsetPatcher: Sendable {

    /// One recorded patch site.
    fileprivate struct Patch: Sendable, Equatable {
        let position: Int
        let value: UInt64
        let width: Width

        enum Width: Sendable, Equatable {
            case bits32
            case bits64
        }
    }

    private var patches: [Patch] = []

    init() {}

    /// Record a 32-bit big-endian patch site.
    mutating func record32(at position: Int, value: UInt32) {
        patches.append(Patch(position: position, value: UInt64(value), width: .bits32))
    }

    /// Record a 64-bit big-endian patch site.
    mutating func record64(at position: Int, value: UInt64) {
        patches.append(Patch(position: position, value: value, width: .bits64))
    }

    /// Number of patches recorded so far.
    var count: Int { patches.count }

    /// Apply every recorded patch to the supplied buffer.
    func apply(to bytes: inout Data) {
        for patch in patches {
            switch patch.width {
            case .bits32:
                Self.writeUInt32BE(
                    UInt32(truncatingIfNeeded: patch.value),
                    into: &bytes,
                    at: patch.position)
            case .bits64:
                Self.writeUInt64BE(patch.value, into: &bytes, at: patch.position)
            }
        }
    }

    /// Pure helper that returns a patched copy without mutating self.
    func applied(to bytes: Data) -> Data {
        var copy = bytes
        apply(to: &copy)
        return copy
    }

    private static func writeUInt32BE(_ value: UInt32, into bytes: inout Data, at offset: Int) {
        precondition(offset + 4 <= bytes.count, "OffsetPatcher position out of range")
        bytes[offset] = UInt8((value >> 24) & 0xFF)
        bytes[offset + 1] = UInt8((value >> 16) & 0xFF)
        bytes[offset + 2] = UInt8((value >> 8) & 0xFF)
        bytes[offset + 3] = UInt8(value & 0xFF)
    }

    private static func writeUInt64BE(_ value: UInt64, into bytes: inout Data, at offset: Int) {
        precondition(offset + 8 <= bytes.count, "OffsetPatcher position out of range")
        for i in 0..<8 {
            bytes[offset + i] = UInt8((value >> (8 * (7 - i))) & 0xFF)
        }
    }
}
