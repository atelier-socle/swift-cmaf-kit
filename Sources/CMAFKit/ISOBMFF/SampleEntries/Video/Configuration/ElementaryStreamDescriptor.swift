// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ElementaryStreamDescriptor (esds)
//
// Reference: ISO/IEC 14496-1 §7.2.6.5 + §8.6.6 (MPEG-4 Systems).
//
// The `esds` box is a full box containing an `ES_Descriptor` (tag 0x03)
// which contains a `DecoderConfigDescriptor` (tag 0x04) which contains a
// `DecoderSpecificInfo` (tag 0x05). The descriptor sub-language uses
// BER-style length encoding: each length byte contributes 7 bits, with
// the high bit set to indicate continuation. Maximum 4 length bytes per
// the spec.

import Foundation

/// Descriptor tag constants per ISO/IEC 14496-1 Table 1.
public enum MP4DescriptorTag: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case esDescriptor = 0x03
    case decoderConfigDescriptor = 0x04
    case decoderSpecificInfo = 0x05
    case slConfigDescriptor = 0x06
}

/// MPEG-4 elementary stream descriptor carried by the `esds` full box.
///
/// Reference: ISO/IEC 14496-1 §7.2.6.5.
public struct ElementaryStreamDescriptor: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "esds"

    public let version: UInt8
    public let flags: UInt32
    public let esID: UInt16
    public let streamDependenceFlag: Bool
    public let urlFlag: Bool
    public let ocrStreamFlag: Bool
    public let streamPriority: UInt8
    public let dependsOnESID: UInt16?
    public let url: String?
    public let ocrESID: UInt16?
    public let decoderConfig: DecoderConfigDescriptor
    public let slConfig: SLConfigDescriptor

    public struct DecoderConfigDescriptor: Sendable, Equatable, Hashable {
        public let objectTypeIndication: MP4ObjectTypeIndication
        public let streamType: MP4StreamType
        public let upStream: Bool
        /// Decoder buffer size in bytes (24-bit value on the wire).
        public let bufferSizeDB: UInt32
        public let maxBitrate: UInt32
        public let avgBitrate: UInt32
        /// DecoderSpecificInfo payload bytes (tag 0x05 contents), if
        /// present. CMAFKit preserves these verbatim; structured
        /// audio-config parsing lives in a later codec-bitstream
        /// checkpoint.
        public let decoderSpecificInfo: Data?

        public init(
            objectTypeIndication: MP4ObjectTypeIndication,
            streamType: MP4StreamType,
            upStream: Bool,
            bufferSizeDB: UInt32,
            maxBitrate: UInt32,
            avgBitrate: UInt32,
            decoderSpecificInfo: Data? = nil
        ) {
            precondition(
                bufferSizeDB <= 0x00FF_FFFF,
                "DecoderConfigDescriptor bufferSizeDB must fit in 24 bits"
            )
            self.objectTypeIndication = objectTypeIndication
            self.streamType = streamType
            self.upStream = upStream
            self.bufferSizeDB = bufferSizeDB
            self.maxBitrate = maxBitrate
            self.avgBitrate = avgBitrate
            self.decoderSpecificInfo = decoderSpecificInfo
        }
    }

    public struct SLConfigDescriptor: Sendable, Equatable, Hashable {
        public let predefined: UInt8

        public init(predefined: UInt8 = 2) {
            self.predefined = predefined
        }
    }

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        esID: UInt16,
        streamDependenceFlag: Bool = false,
        urlFlag: Bool = false,
        ocrStreamFlag: Bool = false,
        streamPriority: UInt8 = 0,
        dependsOnESID: UInt16? = nil,
        url: String? = nil,
        ocrESID: UInt16? = nil,
        decoderConfig: DecoderConfigDescriptor,
        slConfig: SLConfigDescriptor = SLConfigDescriptor()
    ) {
        precondition(
            streamPriority <= 0x1F,
            "ES_Descriptor streamPriority must fit in 5 bits"
        )
        precondition(
            streamDependenceFlag == (dependsOnESID != nil),
            "ES_Descriptor streamDependenceFlag must match dependsOnESID presence"
        )
        precondition(
            urlFlag == (url != nil),
            "ES_Descriptor urlFlag must match url presence"
        )
        precondition(
            ocrStreamFlag == (ocrESID != nil),
            "ES_Descriptor ocrStreamFlag must match ocrESID presence"
        )
        self.version = version
        self.flags = flags
        self.esID = esID
        self.streamDependenceFlag = streamDependenceFlag
        self.urlFlag = urlFlag
        self.ocrStreamFlag = ocrStreamFlag
        self.streamPriority = streamPriority
        self.dependsOnESID = dependsOnESID
        self.url = url
        self.ocrESID = ocrESID
        self.decoderConfig = decoderConfig
        self.slConfig = slConfig
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ElementaryStreamDescriptor {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        return try parseBody(reader: &reader, version: version, flags: flags)
    }

    private static func parseBody(
        reader: inout BinaryReader,
        version: UInt8,
        flags: UInt32
    ) throws -> ElementaryStreamDescriptor {
        let esDescTag = try reader.readUInt8()
        guard esDescTag == MP4DescriptorTag.esDescriptor.rawValue else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected ES_Descriptor tag 0x03, got 0x\(String(esDescTag, radix: 16))"
            )
        }
        _ = try readBERLength(reader: &reader)
        let esID = try reader.readUInt16()
        let flagsByte = try reader.readUInt8()
        let streamDependenceFlag = (flagsByte & 0x80) != 0
        let urlFlag = (flagsByte & 0x40) != 0
        let ocrStreamFlag = (flagsByte & 0x20) != 0
        let streamPriority = flagsByte & 0x1F

        var dependsOnESID: UInt16?
        if streamDependenceFlag {
            dependsOnESID = try reader.readUInt16()
        }
        var url: String?
        if urlFlag {
            let urlLength = Int(try reader.readUInt8())
            let urlBytes = try reader.readData(count: urlLength)
            url = String(data: urlBytes, encoding: .utf8) ?? ""
        }
        var ocrESID: UInt16?
        if ocrStreamFlag {
            ocrESID = try reader.readUInt16()
        }

        let decoderConfig = try parseDecoderConfig(reader: &reader)
        let slConfig = try parseSLConfig(reader: &reader)

        return ElementaryStreamDescriptor(
            version: version,
            flags: flags,
            esID: esID,
            streamDependenceFlag: streamDependenceFlag,
            urlFlag: urlFlag,
            ocrStreamFlag: ocrStreamFlag,
            streamPriority: streamPriority,
            dependsOnESID: dependsOnESID,
            url: url,
            ocrESID: ocrESID,
            decoderConfig: decoderConfig,
            slConfig: slConfig
        )
    }

    fileprivate static func parseDecoderConfig(
        reader: inout BinaryReader
    ) throws -> DecoderConfigDescriptor {
        try ESDSDescriptorHelpers.parseDecoderConfig(reader: &reader)
    }

    fileprivate static func parseSLConfig(
        reader: inout BinaryReader
    ) throws -> SLConfigDescriptor {
        try ESDSDescriptorHelpers.parseSLConfig(reader: &reader)
    }

    fileprivate static func readBERLength(reader: inout BinaryReader) throws -> Int {
        try ESDSDescriptorHelpers.readBERLength(reader: &reader)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            // ES_Descriptor body
            var esBody = BinaryWriter()
            esBody.writeUInt16(esID)
            var fb: UInt8 = 0
            if streamDependenceFlag { fb |= 0x80 }
            if urlFlag { fb |= 0x40 }
            if ocrStreamFlag { fb |= 0x20 }
            fb |= streamPriority & 0x1F
            esBody.writeUInt8(fb)
            if let dep = dependsOnESID {
                esBody.writeUInt16(dep)
            }
            if let urlString = url {
                let urlBytes = urlString.data(using: .utf8) ?? Data()
                esBody.writeUInt8(UInt8(min(urlBytes.count, Int(UInt8.max))))
                esBody.writeData(urlBytes.prefix(Int(UInt8.max)))
            }
            if let ocr = ocrESID {
                esBody.writeUInt16(ocr)
            }
            // DecoderConfigDescriptor body
            var dcBody = BinaryWriter()
            dcBody.writeUInt8(decoderConfig.objectTypeIndication.rawValue)
            var stByte: UInt8 = (decoderConfig.streamType.rawValue & 0x3F) << 2
            if decoderConfig.upStream { stByte |= 0x02 }
            stByte |= 0x01  // reserved bit = 1 per spec
            dcBody.writeUInt8(stByte)
            dcBody.writeUInt24(decoderConfig.bufferSizeDB & 0x00FF_FFFF)
            dcBody.writeUInt32(decoderConfig.maxBitrate)
            dcBody.writeUInt32(decoderConfig.avgBitrate)
            if let dsi = decoderConfig.decoderSpecificInfo {
                dcBody.writeUInt8(MP4DescriptorTag.decoderSpecificInfo.rawValue)
                writeBERLength(dsi.count, to: &dcBody)
                dcBody.writeData(dsi)
            }
            esBody.writeUInt8(MP4DescriptorTag.decoderConfigDescriptor.rawValue)
            writeBERLength(dcBody.data.count, to: &esBody)
            esBody.writeData(dcBody.data)
            // SLConfigDescriptor
            esBody.writeUInt8(MP4DescriptorTag.slConfigDescriptor.rawValue)
            writeBERLength(1, to: &esBody)
            esBody.writeUInt8(slConfig.predefined)

            body.writeUInt8(MP4DescriptorTag.esDescriptor.rawValue)
            writeBERLength(esBody.data.count, to: &body)
            body.writeData(esBody.data)
        }
    }

    /// Emit a 4-byte BER length encoding (canonical, with leading
    /// continuation bytes). Always emits 4 bytes per the common MPEG-4
    /// convention used by macOS / FFmpeg.
    private func writeBERLength(_ length: Int, to writer: inout BinaryWriter) {
        ESDSDescriptorHelpers.writeBERLength(length, to: &writer)
    }
}

// MARK: - ESDSDescriptorHelpers
//
// Fileprivate parsing helpers extracted from ``ElementaryStreamDescriptor``
// to keep the struct body within the project's per-type body-length
// budget. These helpers are intentionally not part of the public surface.

private enum ESDSDescriptorHelpers {

    static func parseDecoderConfig(
        reader: inout BinaryReader
    ) throws -> ElementaryStreamDescriptor.DecoderConfigDescriptor {
        let tag = try reader.readUInt8()
        guard tag == MP4DescriptorTag.decoderConfigDescriptor.rawValue else {
            throw ISOBoxError.malformedFullBox(
                type: ElementaryStreamDescriptor.boxType,
                reason: "Expected DecoderConfigDescriptor tag 0x04, got 0x\(String(tag, radix: 16))"
            )
        }
        let length = try readBERLength(reader: &reader)
        let remainingAfter = reader.remaining - length

        let otiRaw = try reader.readUInt8()
        guard let oti = MP4ObjectTypeIndication(rawValue: otiRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: ElementaryStreamDescriptor.boxType,
                reason: "Unknown MP4 objectTypeIndication 0x\(String(otiRaw, radix: 16))"
            )
        }
        let stByte = try reader.readUInt8()
        let stRaw = (stByte >> 2) & 0x3F
        guard let streamType = MP4StreamType(rawValue: stRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: ElementaryStreamDescriptor.boxType,
                reason: "Unknown MP4 streamType \(stRaw)"
            )
        }
        let upStream = (stByte & 0x02) != 0
        let bufferSizeDB = try reader.readUInt24()
        let maxBitrate = try reader.readUInt32()
        let avgBitrate = try reader.readUInt32()

        var dsi: Data?
        if reader.remaining > remainingAfter {
            let dsiTag = try reader.readUInt8()
            guard dsiTag == MP4DescriptorTag.decoderSpecificInfo.rawValue else {
                throw ISOBoxError.malformedFullBox(
                    type: ElementaryStreamDescriptor.boxType,
                    reason: "Expected DecoderSpecificInfo tag 0x05, got 0x\(String(dsiTag, radix: 16))"
                )
            }
            let dsiLength = try readBERLength(reader: &reader)
            dsi = try reader.readData(count: dsiLength)
        }

        // Skip any trailing descriptors inside the decoder config.
        while reader.remaining > remainingAfter {
            _ = try reader.readUInt8()
        }

        return ElementaryStreamDescriptor.DecoderConfigDescriptor(
            objectTypeIndication: oti,
            streamType: streamType,
            upStream: upStream,
            bufferSizeDB: bufferSizeDB,
            maxBitrate: maxBitrate,
            avgBitrate: avgBitrate,
            decoderSpecificInfo: dsi
        )
    }

    static func parseSLConfig(
        reader: inout BinaryReader
    ) throws -> ElementaryStreamDescriptor.SLConfigDescriptor {
        let tag = try reader.readUInt8()
        guard tag == MP4DescriptorTag.slConfigDescriptor.rawValue else {
            throw ISOBoxError.malformedFullBox(
                type: ElementaryStreamDescriptor.boxType,
                reason: "Expected SLConfigDescriptor tag 0x06, got 0x\(String(tag, radix: 16))"
            )
        }
        let length = try readBERLength(reader: &reader)
        guard length >= 1 else {
            throw ISOBoxError.malformedFullBox(
                type: ElementaryStreamDescriptor.boxType,
                reason: "SLConfigDescriptor length \(length) too short"
            )
        }
        let predefined = try reader.readUInt8()
        for _ in 1..<length {
            _ = try reader.readUInt8()
        }
        return ElementaryStreamDescriptor.SLConfigDescriptor(predefined: predefined)
    }

    /// Read a BER-style descriptor length: up to 4 bytes, each
    /// contributing 7 bits.
    static func readBERLength(reader: inout BinaryReader) throws -> Int {
        var length: Int = 0
        for _ in 0..<4 {
            let byte = try reader.readUInt8()
            length = (length << 7) | Int(byte & 0x7F)
            if (byte & 0x80) == 0 {
                return length
            }
        }
        return length
    }

    /// Emit a 4-byte BER length encoding (canonical, with leading
    /// continuation bytes). Always emits 4 bytes per the common MPEG-4
    /// convention used by macOS / FFmpeg.
    static func writeBERLength(_ length: Int, to writer: inout BinaryWriter) {
        let b3 = UInt8(((length >> 21) & 0x7F) | 0x80)
        let b2 = UInt8(((length >> 14) & 0x7F) | 0x80)
        let b1 = UInt8(((length >> 7) & 0x7F) | 0x80)
        let b0 = UInt8(length & 0x7F)
        writer.writeUInt8(b3)
        writer.writeUInt8(b2)
        writer.writeUInt8(b1)
        writer.writeUInt8(b0)
    }
}
