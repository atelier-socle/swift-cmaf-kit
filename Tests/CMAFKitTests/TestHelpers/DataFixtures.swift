// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Hex-string → `Data` decoder for test fixtures.
///
/// Usage:
/// ```swift
/// let bytes = Data(hex: "00 00 00 0c 66 74 79 70 69 73 6f 6d")
/// ```
///
/// Whitespace is ignored. Non-hex characters are skipped silently — tests are
/// expected to provide clean hex.
internal enum DataFixtures {
    static func data(hex: String) -> Data {
        var data = Data()
        var nibble: UInt8?
        for char in hex {
            guard let v = char.hexDigitValue.map({ UInt8($0) }) else { continue }
            if let high = nibble {
                data.append((high << 4) | v)
                nibble = nil
            } else {
                nibble = v
            }
        }
        return data
    }
}

extension Data {
    init(hex: String) {
        self = DataFixtures.data(hex: hex)
    }
}
