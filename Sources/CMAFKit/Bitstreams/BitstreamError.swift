// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BitstreamError
//
// Dedicated error type for codec-bitstream parsers (AAC, AVC, HEVC, AV1,
// AC-4, FLAC). Bitstream errors are distinct from `ISOBoxError` so callers
// can disambiguate a malformed ISO BMFF box from a malformed codec payload
// it carries.

import Foundation

/// Errors raised by the codec-bitstream parsers.
public enum BitstreamError: Error, Sendable, Equatable {
    /// The bitstream ended before all required bits of `field` could be
    /// read for `codec`.
    case truncated(codec: String, field: String)
    /// A field whose standard mandates a zero value was non-zero on the
    /// wire.
    case reservedBitsNonZero(codec: String, field: String)
    /// A field carried a value outside the documented set for `codec`.
    case unsupportedValue(codec: String, field: String, value: UInt64)
    /// An on-wire NAL unit type code is not in the documented enum for
    /// the codec.
    case unknownNALUnitType(codec: String, rawValue: UInt8)
    /// An Exp-Golomb codeword could not be decoded (typically a leading
    /// run of zeros exceeded the implementation's safe range).
    case malformedExpGolomb(reason: String)
    /// RBSP emulation-prevention byte stripping failed.
    case rbspStrippingFailure(reason: String)
    /// AV1 LEB128 decoding overflowed the 8-byte / 56-bit envelope.
    case obuLEB128Overflow
    /// AC-4 declared `nPresentations` did not match the parsed count.
    case ac4PresentationCountMismatch(declared: Int, actual: Int)
    /// A FLAC frame header's sync code did not match `0x3FFE` (14-bit
    /// sync per Xiph FLAC spec).
    case flacFrameSyncMismatch(found: UInt16)
    /// A FLAC frame header's CRC-8 byte did not match a recomputation
    /// over the preceding header bytes.
    case flacCRC8Mismatch(expected: UInt8, computed: UInt8)
}
