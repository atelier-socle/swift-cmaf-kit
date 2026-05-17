// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HandlerReferenceBox (hdlr)
//
// Reference: ISO/IEC 14496-12 §8.4.3 (handler reference box).
//
// Names the media type of a track via its 4-character handler_type
// ("vide", "soun", "subt", "text", "hint", "meta", "auxv") plus a
// human-readable name string. CMAFKit reads both C-style (ISO-correct
// null-terminated) and Pascal-style (one-byte-length-prefix) name
// fields; encoders always emit C-style.

import Foundation

/// Track handler reference.
///
/// Common handler types:
///   - `vide` — video track
///   - `soun` — audio track
///   - `subt` — subtitle track (CMAF / DASH IMSC1)
///   - `text` — legacy timed text
///   - `hint` — hint track (RTP, etc.)
///   - `meta` — metadata track
///   - `auxv` — auxiliary video (alpha, depth, …)
///
/// The `name` field carries a human-readable label. The standard form is
/// a null-terminated UTF-8 string, but some legacy QuickTime files use a
/// Pascal-style length-prefix instead. The reader accepts both; writers
/// always emit the standard null-terminated form.
public struct HandlerReferenceBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "hdlr"

    public static let typeVideo: FourCC = "vide"
    public static let typeAudio: FourCC = "soun"
    public static let typeSubtitle: FourCC = "subt"
    public static let typeText: FourCC = "text"
    public static let typeHint: FourCC = "hint"
    public static let typeMeta: FourCC = "meta"
    public static let typeAuxiliaryVideo: FourCC = "auxv"

    public let version: UInt8
    public let flags: UInt32
    /// Always `0` in ISOBMFF; preserved for QuickTime compatibility.
    public let preDefined: UInt32
    /// The media type FourCC.
    public let handlerType: FourCC
    /// Human-readable handler name.
    public let name: String

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        preDefined: UInt32 = 0,
        handlerType: FourCC,
        name: String
    ) {
        self.version = version
        self.flags = flags
        self.preDefined = preDefined
        self.handlerType = handlerType
        self.name = name
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> HandlerReferenceBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let preDefined = try reader.readUInt32()
        let handlerType = try reader.readFourCC()
        try reader.skip(12)  // 3 × UInt32 reserved

        // `hdlr.name` decoding: try Pascal-style first; if the length byte
        // matches and the bytes decode cleanly, accept; otherwise treat as
        // null-terminated UTF-8.
        let remaining = reader.remaining
        let nameData = try reader.readData(count: remaining)
        let name = try decodeHandlerName(nameData)

        return HandlerReferenceBox(
            version: version,
            flags: flags,
            preDefined: preDefined,
            handlerType: handlerType,
            name: name
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(preDefined)
            body.writeFourCC(handlerType)
            body.writeZeros(12)
            body.writeNullTerminatedString(name)
        }
    }

    /// Decode the `hdlr.name` field tolerantly for legacy QuickTime files.
    ///
    /// The ISO-correct form is null-terminated UTF-8. Some legacy QuickTime
    /// files use a Pascal-style encoding: one length byte followed by that
    /// many UTF-8 bytes, no terminator.
    ///
    /// Heuristic, applied in order:
    ///   1. Empty buffer → empty string.
    ///   2. If the first byte equals `bytes.count - 1` and the remaining
    ///      bytes decode as UTF-8 → Pascal-style.
    ///   3. Otherwise, take bytes up to the first `0x00` and decode as UTF-8.
    internal static func decodeHandlerName(_ data: Data) throws -> String {
        if data.isEmpty {
            return ""
        }

        // Try Pascal-style first.
        let pascalLength = Int(data[data.startIndex])
        if pascalLength == data.count - 1 {
            let pascalRange = data.startIndex.advanced(by: 1)..<data.endIndex
            let pascalBytes = data[pascalRange]
            if let decoded = String(data: pascalBytes, encoding: .utf8) {
                return decoded
            }
        }

        // Fall back to C-style.
        var bytes = data
        if let nulIndex = bytes.firstIndex(of: 0x00) {
            bytes = bytes[..<nulIndex]
        }
        guard let decoded = String(data: bytes, encoding: .utf8) else {
            throw ISOBoxError.malformedHandlerName
        }
        return decoded
    }
}
