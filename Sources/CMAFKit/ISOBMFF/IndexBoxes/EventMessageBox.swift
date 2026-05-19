// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EventMessageBox (emsg)
//
// Reference: ISO/IEC 23009-1 §5.10.3 (DASH Event Message Box) and
// ISO/IEC 14496-12 §8.16.2 (in-band event signalling within media
// segments).
//
// Two on-wire layouts coexist:
//
//   - **version 0** carries scheme/value/timescale up front, then
//     `presentation_time_delta` (32-bit), `event_duration`, `id`,
//     and the opaque `message_data`.
//   - **version 1** moves scheme/value to the tail and emits an
//     absolute 64-bit `presentation_time`.
//
// The writer surfaces both versions through a typed enum so consumers
// pick the variant explicitly.

import Foundation

/// In-band DASH event message box (`emsg`).
public struct EventMessageBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "emsg"

    public let version: UInt8
    public let flags: UInt32
    /// Identifier of the message scheme; typically a URI like
    /// `"urn:mpeg:dash:event:2012"`.
    public let schemeIDURI: String
    /// Scheme-defined value, may be empty.
    public let value: String
    /// Timescale of the `presentation_time_*` / `event_duration` fields.
    public let timescale: UInt32
    /// Version-0 only: delta from segment's earliest presentation
    /// time. `nil` for version 1.
    public let presentationTimeDelta: UInt32?
    /// Version-1 only: absolute presentation time. `nil` for version 0.
    public let presentationTime: UInt64?
    /// Duration of the event, in `timescale` units. `0xFFFF_FFFF`
    /// signals "unknown" per ISO/IEC 23009-1.
    public let eventDuration: UInt32
    /// Identifier unique within scheme/value.
    public let id: UInt32
    /// Scheme-specific opaque payload.
    public let messageData: Data

    /// Construct a version-0 emsg.
    public init(
        flags: UInt32 = 0,
        schemeIDURI: String,
        value: String,
        timescale: UInt32,
        presentationTimeDelta: UInt32,
        eventDuration: UInt32,
        id: UInt32,
        messageData: Data
    ) {
        self.version = 0
        self.flags = flags
        self.schemeIDURI = schemeIDURI
        self.value = value
        self.timescale = timescale
        self.presentationTimeDelta = presentationTimeDelta
        self.presentationTime = nil
        self.eventDuration = eventDuration
        self.id = id
        self.messageData = messageData
    }

    /// Construct a version-1 emsg.
    public init(
        flags: UInt32 = 0,
        timescale: UInt32,
        presentationTime: UInt64,
        eventDuration: UInt32,
        id: UInt32,
        schemeIDURI: String,
        value: String,
        messageData: Data
    ) {
        self.version = 1
        self.flags = flags
        self.schemeIDURI = schemeIDURI
        self.value = value
        self.timescale = timescale
        self.presentationTimeDelta = nil
        self.presentationTime = presentationTime
        self.eventDuration = eventDuration
        self.id = id
        self.messageData = messageData
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> EventMessageBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        guard version <= 1 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "emsg version must be 0 or 1; got \(version)"
            )
        }
        if version == 0 {
            let scheme = try reader.readNullTerminatedString()
            let value = try reader.readNullTerminatedString()
            let timescale = try reader.readUInt32()
            let presentationDelta = try reader.readUInt32()
            let duration = try reader.readUInt32()
            let id = try reader.readUInt32()
            let data = reader.readToEnd()
            return EventMessageBox(
                flags: flags,
                schemeIDURI: scheme,
                value: value,
                timescale: timescale,
                presentationTimeDelta: presentationDelta,
                eventDuration: duration,
                id: id,
                messageData: data
            )
        } else {
            let timescale = try reader.readUInt32()
            let presentationTime = try reader.readUInt64()
            let duration = try reader.readUInt32()
            let id = try reader.readUInt32()
            let scheme = try reader.readNullTerminatedString()
            let value = try reader.readNullTerminatedString()
            let data = reader.readToEnd()
            return EventMessageBox(
                flags: flags,
                timescale: timescale,
                presentationTime: presentationTime,
                eventDuration: duration,
                id: id,
                schemeIDURI: scheme,
                value: value,
                messageData: data
            )
        }
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            if version == 0 {
                body.writeNullTerminatedString(schemeIDURI)
                body.writeNullTerminatedString(value)
                body.writeUInt32(timescale)
                body.writeUInt32(presentationTimeDelta ?? 0)
                body.writeUInt32(eventDuration)
                body.writeUInt32(id)
                body.writeData(messageData)
            } else {
                body.writeUInt32(timescale)
                body.writeUInt64(presentationTime ?? 0)
                body.writeUInt32(eventDuration)
                body.writeUInt32(id)
                body.writeNullTerminatedString(schemeIDURI)
                body.writeNullTerminatedString(value)
                body.writeData(messageData)
            }
        }
    }
}
