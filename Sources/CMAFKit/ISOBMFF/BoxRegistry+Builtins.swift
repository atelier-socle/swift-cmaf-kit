// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BoxRegistry built-ins
//
// Registers every box type CMAFKit ships, grouped by their structural role
// (simple leaf, container, protection-scheme, full-box header). New box
// types are added to the corresponding group method as they land in the
// library.

import Foundation

extension BoxRegistry {

    /// Registers every built-in box parser shipped with CMAFKit.
    ///
    /// Called from ``registerBuiltins()``. Each registration maps a FourCC
    /// to the corresponding box type's static
    /// `parse(reader:header:registry:)` factory. The registrations are
    /// split across helper methods grouped by structural role.
    internal func registerBuiltinBoxes() async {
        registerLeafSimpleBoxes()
        registerContainerBoxes()
        registerProtectionSchemeBoxes()
        registerHeaderFullBoxes()
    }

    // MARK: Leaf simple boxes

    /// Registers `ftyp`, `styp`, `free`, `skip`, `mdat`, `uuid`.
    private func registerLeafSimpleBoxes() {
        register(FileTypeBox.self) { reader, header, registry in
            try await FileTypeBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SegmentTypeBox.self) { reader, header, registry in
            try await SegmentTypeBox.parse(reader: &reader, header: header, registry: registry)
        }
        // `free` and `skip` map to the same parser; the on-wire FourCC is
        // preserved on the resulting instance.
        let freeSkipParser: Parser = { reader, header, registry in
            try await FreeSpaceBox.parse(reader: &reader, header: header, registry: registry)
        }
        register("free", parser: freeSkipParser)
        register("skip", parser: freeSkipParser)
        register(MediaDataBox.self) { reader, header, registry in
            try await MediaDataBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(UUIDBox.self) { reader, header, registry in
            try await UUIDBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    // MARK: Container boxes

    /// Registers `moov`, `trak`, `mdia`, `minf`, `dinf`, `stbl`, `edts`, `udta`.
    private func registerContainerBoxes() {
        register(MovieBox.self) { reader, header, registry in
            try await MovieBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackBox.self) { reader, header, registry in
            try await TrackBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MediaBox.self) { reader, header, registry in
            try await MediaBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MediaInformationBox.self) { reader, header, registry in
            try await MediaInformationBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(DataInformationBox.self) { reader, header, registry in
            try await DataInformationBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SampleTableBox.self) { reader, header, registry in
            try await SampleTableBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(EditBox.self) { reader, header, registry in
            try await EditBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(UserDataBox.self) { reader, header, registry in
            try await UserDataBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    // MARK: Protection-scheme group

    /// Registers `sinf`, `frma`, `schm`, `schi`.
    private func registerProtectionSchemeBoxes() {
        register(ProtectionSchemeInfoBox.self) { reader, header, registry in
            try await ProtectionSchemeInfoBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(OriginalFormatBox.self) { reader, header, registry in
            try await OriginalFormatBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SchemeTypeBox.self) { reader, header, registry in
            try await SchemeTypeBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(SchemeInformationBox.self) { reader, header, registry in
            try await SchemeInformationBox.parse(reader: &reader, header: header, registry: registry)
        }
    }

    // MARK: Header full boxes

    /// Registers `mvhd`, `tkhd`, `mdhd`, `hdlr`.
    private func registerHeaderFullBoxes() {
        register(MovieHeaderBox.self) { reader, header, registry in
            try await MovieHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(TrackHeaderBox.self) { reader, header, registry in
            try await TrackHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(MediaHeaderBox.self) { reader, header, registry in
            try await MediaHeaderBox.parse(reader: &reader, header: header, registry: registry)
        }
        register(HandlerReferenceBox.self) { reader, header, registry in
            try await HandlerReferenceBox.parse(reader: &reader, header: header, registry: registry)
        }
    }
}
