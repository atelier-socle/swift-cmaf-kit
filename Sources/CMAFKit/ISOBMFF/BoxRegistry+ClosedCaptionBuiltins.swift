// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BoxRegistry closed-caption builtins
//
// Registers the native CEA-608 and CEA-708 caption sample-entry
// boxes per ISO/IEC 14496-30 §11.

import Foundation

extension BoxRegistry {
    internal func registerClosedCaptionBuiltinBoxes() {
        register(CEA608SampleEntry.self) { reader, header, registry in
            try await CEA608SampleEntry.parse(
                reader: &reader, header: header, registry: registry
            )
        }
        register(CEA708SampleEntry.self) { reader, header, registry in
            try await CEA708SampleEntry.parse(
                reader: &reader, header: header, registry: registry
            )
        }
    }
}
