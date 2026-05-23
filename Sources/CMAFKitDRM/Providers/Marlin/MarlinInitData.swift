// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MarlinInitData
//
// Reference: Marlin Developer Community (MDC) "Marlin Broadband
// Specification" public documentation. The Marlin system
// identifier `5e629af5-38da-4063-8977-97ffbd9902d4` carries a
// Marlin Broadband Asset Identifier (BBA) followed by optional
// inner payload.
//
// The publicly-documented portion of the pssh.data is the BBA
// content-id URN string. Some deployments embed additional
// operator-specific fields after the BBA. CMAFKitDRM types the
// BBA and preserves any trailing bytes in ``innerPayload`` so
// round-trip is byte-perfect.
//
// Recognised BBA shape: an ASCII string of the form
// `urn:marlin:kid:<lowercase-hex-kid>` (32 hex chars) optionally
// followed by trailing bytes. When the bytes do not match the
// BBA pattern, ``broadbandAssetIdentifier`` is nil and the entire
// payload is preserved in ``innerPayload``.

import Foundation

/// Typed Marlin Broadband init-data payload.
public struct MarlinInitData: Sendable, Hashable, Equatable, Codable {

    /// Broadband Asset Identifier per MDC spec.
    public struct BroadbandAssetIdentifier: Sendable, Hashable, Equatable, Codable {
        /// Raw 16-byte KID per ISO/IEC 23001-7 §8.2 (decoded from
        /// the lowercase-hex `urn:marlin:kid:...` URN).
        public let kid: Data
        /// Original URN string preserved verbatim for round-trip.
        public let urn: String

        public init(kid: Data, urn: String) {
            precondition(
                kid.count == 16,
                "Marlin BBA kid must be exactly 16 bytes"
            )
            self.kid = kid
            self.urn = urn
        }
    }

    /// Parsed BBA when the leading bytes match the MDC public
    /// shape; nil when the entire pssh.data is operator-specific.
    public let broadbandAssetIdentifier: BroadbandAssetIdentifier?
    /// Bytes after the BBA. Preserved verbatim; the MDC spec does
    /// not publish a normative inner-layout — its content is
    /// operator-defined.
    public let innerPayload: Data

    public init(
        broadbandAssetIdentifier: BroadbandAssetIdentifier?,
        innerPayload: Data
    ) {
        self.broadbandAssetIdentifier = broadbandAssetIdentifier
        self.innerPayload = innerPayload
    }

    public static func parse(_ data: Data) throws -> MarlinInitData {
        // The published BBA shape is an ASCII URN. Decode the
        // longest leading ASCII run that matches
        // `urn:marlin:kid:<32-hex>`; everything else goes into
        // innerPayload.
        let asciiBytes = data.prefix { byte in
            (0x20...0x7E).contains(byte)
        }
        let prefix = String(data: Data(asciiBytes), encoding: .ascii) ?? ""
        let urnPrefix = "urn:marlin:kid:"
        if prefix.lowercased().hasPrefix(urnPrefix) {
            let hexStart = prefix.index(prefix.startIndex, offsetBy: urnPrefix.count)
            let hexEnd = prefix.index(hexStart, offsetBy: 32, limitedBy: prefix.endIndex)
            if let end = hexEnd {
                let hexSubstring = prefix[hexStart..<end]
                if let kid = decodeHex(String(hexSubstring)) {
                    let urn = String(prefix[prefix.startIndex..<end])
                    let consumed = urn.utf8.count
                    let inner = data.suffix(from: data.startIndex + consumed)
                    return MarlinInitData(
                        broadbandAssetIdentifier: BroadbandAssetIdentifier(kid: kid, urn: urn),
                        innerPayload: Data(inner)
                    )
                }
            }
        }
        return MarlinInitData(broadbandAssetIdentifier: nil, innerPayload: data)
    }

    public static func encode(_ value: MarlinInitData) throws -> Data {
        var bytes = Data()
        if let bba = value.broadbandAssetIdentifier {
            guard let urnBytes = bba.urn.data(using: .ascii) else {
                throw DRMSystemError.roundTripFailure(
                    systemID: .marlin,
                    reason: "Marlin BBA URN must be ASCII"
                )
            }
            bytes.append(urnBytes)
        }
        bytes.append(value.innerPayload)
        return bytes
    }

    private static func decodeHex(_ string: String) -> Data? {
        guard string.count == 32 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(16)
        var iterator = string.makeIterator()
        while let high = iterator.next(), let low = iterator.next() {
            guard let h = high.hexDigitValue, let l = low.hexDigitValue
            else { return nil }
            bytes.append(UInt8(h * 16 + l))
        }
        return Data(bytes)
    }
}

extension MarlinInitData: DRMInitDataParsing {
    public static var systemID: KnownDRMSystemID { .marlin }
    public typealias TypedInitData = MarlinInitData
}
