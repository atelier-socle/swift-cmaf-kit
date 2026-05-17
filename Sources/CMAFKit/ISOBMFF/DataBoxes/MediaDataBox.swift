// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MediaDataBox (mdat)
//
// Reference: ISO/IEC 14496-12 §8.1.1 (media data box).
//
// Carries the raw sample bytes referenced by the sample-table boxes or
// by the moof's trun. The body is opaque to ISOBMFF; semantics come from
// the containing sample tables. The only box whose payload routinely
// exceeds 4 GiB, so largesize is the expected case in long-form
// fragmented files.

import Foundation

/// Media data box — opaque container for sample bytes.
///
/// The payload is interpreted by the sample tables in `moov/trak/mdia/minf/stbl`
/// (for unfragmented files) or by the `moof/traf/trun` for fragmented
/// content. From this box's perspective, the bytes are opaque.
///
/// Long-form fragmented files routinely produce `mdat` boxes exceeding
/// 4 GiB; the writer emits the 64-bit `largesize` form automatically.
public struct MediaDataBox: ISOBox, Sendable, Equatable {
    public static let boxType: FourCC = "mdat"

    /// The sample data carried by this box. Treated as opaque here.
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MediaDataBox {
        let payload = reader.readToEnd()
        return MediaDataBox(data: payload)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType, body: data)
    }
}
