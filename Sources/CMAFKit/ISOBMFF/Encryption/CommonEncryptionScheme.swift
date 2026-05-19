// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CommonEncryptionScheme
//
// Reference: ISO/IEC 23001-7 §10 (the four Common Encryption schemes).
//
// On the wire, the scheme is a FourCC stored in `SchemeTypeBox.schemeType`.
// CMAFKit projects it into a typed enum so consumers can drive
// scheme-specific behaviour (CTR vs CBC, full-sample vs pattern) by
// pattern matching rather than string comparison.

import Foundation

/// Common Encryption scheme per ISO/IEC 23001-7 §10.
///
/// Four schemes are standardised:
///
/// - ``cenc``: AES-128 in CTR mode, full-sample encryption.
/// - ``cbc1``: AES-128 in CBC mode, full-sample encryption.
/// - ``cens``: AES-128 in CTR mode, pattern encryption.
/// - ``cbcs``: AES-128 in CBC mode, pattern encryption (the HLS FairPlay
///   encryption mode).
///
/// The raw value is the big-endian FourCC bit pattern.
public enum CommonEncryptionScheme: UInt32, Sendable, Hashable, CaseIterable, Codable {
    /// AES-128-CTR full-sample encryption per ISO/IEC 23001-7 §10.1.
    case cenc = 0x6365_6E63
    /// AES-128-CBC full-sample encryption per ISO/IEC 23001-7 §10.2.
    case cbc1 = 0x6362_6331
    /// AES-128-CTR pattern encryption per ISO/IEC 23001-7 §10.3.
    case cens = 0x6365_6E73
    /// AES-128-CBC pattern encryption per ISO/IEC 23001-7 §10.4 — the
    /// HLS FairPlay encryption mode.
    case cbcs = 0x6362_6373

    /// The on-wire FourCC, e.g. `"cenc"`.
    public var fourCC: FourCC {
        FourCC(rawValue)
    }

    /// True iff this scheme uses block-level pattern encryption
    /// (`cens`, `cbcs`). Full-sample schemes (`cenc`, `cbc1`) do not.
    public var usesPattern: Bool {
        self == .cens || self == .cbcs
    }

    /// True iff this scheme uses AES-CBC mode (`cbc1`, `cbcs`).
    public var usesCBCMode: Bool {
        self == .cbc1 || self == .cbcs
    }

    /// True iff this scheme uses AES-CTR mode (`cenc`, `cens`).
    public var usesCTRMode: Bool {
        self == .cenc || self == .cens
    }
}
