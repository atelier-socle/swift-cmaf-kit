// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DRMInitDataParsing
//
// Reference: ISO/IEC 23001-7 §8.1.1 (pssh.data is opaque; the
// content protection scheme defines its layout).
//
// Provider parsers implement this protocol to expose a typed
// initialisation-data shape for their DRM system. Round-trip
// (`encode(parse(bytes)) == bytes`) is mandatory and verified by
// the provider's test suite once the provider parser lands.

import Foundation

/// Parser/encoder for a single DRM system's pssh init-data
/// payload.
///
/// Conformers expose the typed `TypedInitData` shape via
/// ``parse(_:)`` and reverse the operation via ``encode(_:)``.
/// The CMAFKitDRM dispatch path
/// (`ProtectionSystemSpecificHeaderBox.typedInitData()`) selects
/// the conforming parser by FourCC system identifier and forwards
/// the raw pssh bytes.
public protocol DRMInitDataParsing: Sendable {
    /// The DRM system this parser targets.
    static var systemID: KnownDRMSystemID { get }

    /// The typed init data payload structure (provider-specific).
    associatedtype TypedInitData: Sendable & Equatable

    /// Parse the opaque pssh.data bytes into the typed structure.
    ///
    /// - Throws: ``DRMSystemError/malformedInitData(systemID:reason:)``
    ///   when the bytes do not match the provider's expected
    ///   format; other ``DRMSystemError`` cases when a more
    ///   specific shape applies.
    static func parse(_ rawData: Data) throws -> TypedInitData

    /// Encode the typed structure back to opaque pssh.data bytes.
    ///
    /// The round-trip `encode(parse(input)) == input` must hold
    /// byte-for-byte for any well-formed input.
    static func encode(_ typedData: TypedInitData) throws -> Data
}
