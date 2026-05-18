// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ChannelLayoutBox (chnl)
//
// Reference: ISO/IEC 14496-12 §12.2.4 (channel layout box).
//
// Modern channel-layout descriptor. Supersedes the legacy `channelCount`
// carried by ``AudioSampleEntryFields``. Supports two layout modes plus
// an object-described mode; the parser tracks both presence flags.

import Foundation

/// One channel's typed position within a channel-structured layout.
public struct ExplicitChannelPosition: Sendable, Hashable, Equatable, Codable {
    /// Loudspeaker position. When equal to ``SpeakerPosition/explicit``,
    /// ``customPosition`` carries the channel's angular coordinates.
    public let speakerPosition: SpeakerPosition
    /// Custom angular position, present iff ``speakerPosition`` is
    /// ``SpeakerPosition/explicit`` (raw value 126).
    public let customPosition: CustomPosition?

    /// Custom angular position carried alongside an explicit speaker.
    public struct CustomPosition: Sendable, Hashable, Equatable, Codable {
        /// Azimuth in degrees, range -180..+180.
        public let azimuth: Int16
        /// Elevation in degrees, range -90..+90.
        public let elevation: Int8

        public init(azimuth: Int16, elevation: Int8) {
            self.azimuth = azimuth
            self.elevation = elevation
        }
    }

    public init(speakerPosition: SpeakerPosition, customPosition: CustomPosition? = nil) {
        precondition(
            (speakerPosition == .explicit) == (customPosition != nil),
            "ExplicitChannelPosition: customPosition presence must match speakerPosition == .explicit"
        )
        self.speakerPosition = speakerPosition
        self.customPosition = customPosition
    }
}

/// Channel layout descriptor: either a predefined ID (with an omitted-
/// channels bitmap) or an explicit list of per-channel positions.
public enum ChannelLayoutStructure: Sendable, Equatable, Hashable {
    /// Predefined channel layout. `omittedChannelsMap` carries the bitmap
    /// of channels intentionally absent from the stream.
    case predefined(layout: PredefinedChannelLayout, omittedChannelsMap: UInt64)
    /// Explicit per-channel layout. `positions.count` equals the parent
    /// audio entry's channel count.
    case explicit(positions: [ExplicitChannelPosition])
}

/// Channel layout box (`chnl`).
public struct ChannelLayoutBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "chnl"

    /// Stream structure flag set per ISO/IEC 14496-12 §12.2.4.
    public struct StreamStructure: OptionSet, Sendable, Hashable, Equatable, Codable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }
        /// Bit 0: stream carries channel-structured audio.
        public static let channelStructured = StreamStructure(rawValue: 0x01)
        /// Bit 1: stream carries object-structured audio.
        public static let objectStructured = StreamStructure(rawValue: 0x02)
    }

    public let version: UInt8
    public let flags: UInt32
    public let streamStructure: StreamStructure
    /// Present iff ``streamStructure`` contains ``StreamStructure/channelStructured``.
    public let channelLayout: ChannelLayoutStructure?
    /// Present iff ``streamStructure`` contains ``StreamStructure/objectStructured``.
    public let objectCount: UInt8?

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        streamStructure: StreamStructure,
        channelLayout: ChannelLayoutStructure? = nil,
        objectCount: UInt8? = nil
    ) {
        precondition(
            streamStructure.contains(.channelStructured) == (channelLayout != nil),
            "ChannelLayoutBox: channelLayout presence must match channelStructured bit"
        )
        precondition(
            streamStructure.contains(.objectStructured) == (objectCount != nil),
            "ChannelLayoutBox: objectCount presence must match objectStructured bit"
        )
        self.version = version
        self.flags = flags
        self.streamStructure = streamStructure
        self.channelLayout = channelLayout
        self.objectCount = objectCount
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ChannelLayoutBox {
        // The explicit-positions list is variable-length and ended by the
        // box body boundary; slice the reader to the declared body size
        // so the inner loop honours the box edge regardless of what
        // follows on the parent stream.
        let bodyByteCount = Int(header.size) - header.headerSize
        let bodyBytes = try reader.readData(count: bodyByteCount)
        var body = BinaryReader(bodyBytes)

        let version = try body.readUInt8()
        let flags = try body.readUInt24()
        let structureRaw = try body.readUInt8()
        let streamStructure = StreamStructure(rawValue: structureRaw)

        var channelLayout: ChannelLayoutStructure?
        if streamStructure.contains(.channelStructured) {
            channelLayout = try parseChannelLayout(
                reader: &body,
                objectStructured: streamStructure.contains(.objectStructured)
            )
        }
        var objectCount: UInt8?
        if streamStructure.contains(.objectStructured) {
            objectCount = try body.readUInt8()
        }

        return ChannelLayoutBox(
            version: version,
            flags: flags,
            streamStructure: streamStructure,
            channelLayout: channelLayout,
            objectCount: objectCount
        )
    }

    private static func parseChannelLayout(
        reader: inout BinaryReader,
        objectStructured: Bool
    ) throws -> ChannelLayoutStructure {
        let definedLayoutRaw = try reader.readUInt8()
        if definedLayoutRaw == 0 {
            // Explicit positions consume the remainder of the body. If
            // an object count follows, leave its single byte for the
            // caller.
            let positionsTail = objectStructured ? 1 : 0
            var positions: [ExplicitChannelPosition] = []
            while reader.remaining > positionsTail {
                let positionRaw = try reader.readUInt8()
                guard let position = SpeakerPosition(rawValue: positionRaw) else {
                    throw ISOBoxError.malformedFullBox(
                        type: Self.boxType,
                        reason: "Unknown SpeakerPosition 0x\(String(positionRaw, radix: 16))"
                    )
                }
                var custom: ExplicitChannelPosition.CustomPosition?
                if position == .explicit {
                    let azimuthRaw = try reader.readUInt16()
                    let azimuth = Int16(bitPattern: azimuthRaw)
                    let elevationRaw = try reader.readUInt8()
                    let elevation = Int8(bitPattern: elevationRaw)
                    custom = ExplicitChannelPosition.CustomPosition(
                        azimuth: azimuth,
                        elevation: elevation
                    )
                }
                positions.append(
                    ExplicitChannelPosition(
                        speakerPosition: position,
                        customPosition: custom
                    )
                )
            }
            return .explicit(positions: positions)
        } else {
            guard let layout = PredefinedChannelLayout(rawValue: definedLayoutRaw) else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "Unknown PredefinedChannelLayout \(definedLayoutRaw)"
                )
            }
            let omitted = try reader.readUInt64()
            return .predefined(layout: layout, omittedChannelsMap: omitted)
        }
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt8(streamStructure.rawValue)
            if let layout = channelLayout {
                switch layout {
                case .predefined(let predefined, let omitted):
                    body.writeUInt8(predefined.rawValue)
                    body.writeUInt64(omitted)
                case .explicit(let positions):
                    body.writeUInt8(0)
                    for position in positions {
                        body.writeUInt8(position.speakerPosition.rawValue)
                        if let custom = position.customPosition {
                            body.writeUInt16(UInt16(bitPattern: custom.azimuth))
                            body.writeUInt8(UInt8(bitPattern: custom.elevation))
                        }
                    }
                }
            }
            if let count = objectCount {
                body.writeUInt8(count)
            }
        }
    }
}
