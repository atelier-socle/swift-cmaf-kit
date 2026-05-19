// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BoxRegistry encryption builtins
//
// Registers the typed parsers for every encryption-module box documented
// by ISO/IEC 23001-7 (Common Encryption) and the ISO BMFF protection-
// scheme group (ISO/IEC 14496-12 §8.12).
//
// `senc` is intentionally NOT registered here: its parse depends on the
// per-track `tenc.defaultPerSampleIVSize` context, which the registry
// cannot supply during a generic box-walk. Callers parse `senc` via the
// explicit ``SampleEncryptionBox/parse(reader:header:registry:ivSize:)``
// entry point once they have resolved the encryption context.

import Foundation

extension BoxRegistry {
    /// Register the encryption-module box parsers.
    ///
    /// Called from ``registerBuiltinBoxes`` alongside the other built-in
    /// registration methods.
    internal func registerEncryptionBuiltinBoxes() {
        register(OriginalFormatBox.self) { reader, header, registry in
            try await OriginalFormatBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SchemeTypeBox.self) { reader, header, registry in
            try await SchemeTypeBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SchemeInformationBox.self) { reader, header, registry in
            try await SchemeInformationBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(ProtectionSchemeInfoBox.self) { reader, header, registry in
            try await ProtectionSchemeInfoBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackEncryptionBox.self) { reader, header, registry in
            try await TrackEncryptionBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(ProtectionSystemSpecificHeaderBox.self) { reader, header, registry in
            try await ProtectionSystemSpecificHeaderBox.parse(
                reader: &reader, header: header, registry: registry
            )
        }
    }
}
