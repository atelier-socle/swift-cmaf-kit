// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - URIMetadataSampleEntry (urim) + URIBox (uri ) + URIInitBox (uriI)
//
// Reference: ISO/IEC 14496-12 §8.5.2.4 (URIMetaSampleEntry).
//
// Plain sample entry carrying a mandatory `uri ` (with trailing
// space) child holding the URI string, plus an optional `uriI`
// child carrying initialisation data the consumer needs to bind
// per-sample bytes to the scheme.

import Foundation

/// URI box (`uri `) per ISO/IEC 14496-12 §8.5.2.4.
public struct URIBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "uri "

    public let version: UInt8
    public let flags: UInt32
    public let uri: String

    public init(version: UInt8 = 0, flags: UInt32 = 0, uri: String) {
        self.version = version
        self.flags = flags
        self.uri = uri
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> URIBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let uri = try reader.readNullTerminatedString()
        return URIBox(version: version, flags: flags, uri: uri)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(type: Self.boxType, version: version, flags: flags) { body in
            body.writeNullTerminatedString(uri)
        }
    }
}

/// URI init box (`uriI`) per ISO/IEC 14496-12 §8.5.2.4.
public struct URIInitBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "uriI"

    public let version: UInt8
    public let flags: UInt32
    public let initData: Data

    public init(version: UInt8 = 0, flags: UInt32 = 0, initData: Data) {
        self.version = version
        self.flags = flags
        self.initData = initData
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> URIInitBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let data = reader.readToEnd()
        return URIInitBox(version: version, flags: flags, initData: data)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(type: Self.boxType, version: version, flags: flags) { body in
            body.writeData(initData)
        }
    }
}

/// URI metadata sample entry (`urim`) per ISO/IEC 14496-12 §8.5.2.4.
public struct URIMetadataSampleEntry: SampleEntry, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "urim"

    public let dataReferenceIndex: UInt16
    public let uri: URIBox
    public let uriInit: URIInitBox?

    public init(
        dataReferenceIndex: UInt16 = 1,
        uri: URIBox,
        uriInit: URIInitBox? = nil
    ) {
        self.dataReferenceIndex = dataReferenceIndex
        self.uri = uri
        self.uriInit = uriInit
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> URIMetadataSampleEntry {
        try reader.skip(6)  // reserved
        let dataRefIdx = try reader.readUInt16()

        var uriBox: URIBox?
        var uriInitBox: URIInitBox?
        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            let childHeader = try isoBoxReader.parseBoxHeader(&reader)
            switch childHeader.type {
            case URIBox.boxType:
                uriBox = try await URIBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case URIInitBox.boxType:
                uriInitBox = try await URIInitBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            default:
                _ = try ISOBoxOpaque.parse(reader: &reader)
            }
        }
        guard let resolved = uriBox else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "urim missing mandatory uri box"
            )
        }
        return URIMetadataSampleEntry(
            dataReferenceIndex: dataRefIdx,
            uri: resolved,
            uriInit: uriInitBox
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeZeros(6)  // reserved
            body.writeUInt16(dataReferenceIndex)
            uri.encode(to: &body)
            uriInit?.encode(to: &body)
        }
    }
}
