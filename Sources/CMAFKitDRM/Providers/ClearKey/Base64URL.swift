// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Base64URL
//
// Reference: RFC 4648 §5 (Base 64 Encoding with URL and Filename
// Safe Alphabet). Used by the W3C EME ClearKey init data per RFC
// 7515 §2 conventions: padding is omitted; `+` is replaced by `-`;
// `/` is replaced by `_`.
//
// Foundation's `Data(base64Encoded:)` requires standard base64
// (with padding and `+`/`/`). This helper converts between the
// two forms.

import Foundation

internal enum Base64URL {

    /// Decode a base64url string per RFC 4648 §5 (no padding).
    /// Returns `nil` on malformed input.
    static func decode(_ string: String) -> Data? {
        var sanitized =
            string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = sanitized.count % 4
        if remainder == 2 {
            sanitized.append("==")
        } else if remainder == 3 {
            sanitized.append("=")
        } else if remainder == 1 {
            // base64url with a remainder of 1 is malformed
            // per RFC 4648 §5 — no padding combination recovers
            // a valid 4-character group.
            return nil
        }
        return Data(base64Encoded: sanitized)
    }

    /// Encode bytes as a base64url string per RFC 4648 §5 (no padding).
    static func encode(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        return
            base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
