// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - GASpecificConfig
//
// Reference: ISO/IEC 14496-3 §4.4.1 (GASpecificConfig).
//
// Subsidiary config for General Audio family AudioObjectTypes. The
// composition of `extension_flag3` is reserved for future profiles
// and is captured as a flag without further bit-level interpretation.

import Foundation

/// AAC General Audio Specific Config per ISO/IEC 14496-3 §4.4.1.
public struct GASpecificConfig: Sendable, Hashable, Equatable {
    public let frameLengthFlag: Bool
    public let dependsOnCoreCoder: Bool
    public let coreCoderDelay: UInt16?
    public let extensionFlag: Bool
    public let layerNr: UInt8?
    public let extensionFlag3: Bool?

    public init(
        frameLengthFlag: Bool,
        dependsOnCoreCoder: Bool,
        coreCoderDelay: UInt16? = nil,
        extensionFlag: Bool,
        layerNr: UInt8? = nil,
        extensionFlag3: Bool? = nil
    ) {
        precondition(
            dependsOnCoreCoder == (coreCoderDelay != nil),
            "coreCoderDelay presence must match dependsOnCoreCoder"
        )
        self.frameLengthFlag = frameLengthFlag
        self.dependsOnCoreCoder = dependsOnCoreCoder
        self.coreCoderDelay = coreCoderDelay
        self.extensionFlag = extensionFlag
        self.layerNr = layerNr
        self.extensionFlag3 = extensionFlag3
    }

    public static func parse(
        reader: inout BitReader,
        audioObjectType: MPEG4AudioObjectType,
        channelConfiguration: MPEG4ChannelConfiguration
    ) throws -> GASpecificConfig {
        let frameLength = try reader.readBool()
        let dependsOnCore = try reader.readBool()
        var coreDelay: UInt16?
        if dependsOnCore { coreDelay = UInt16(try reader.readBits(14)) }
        let extFlag = try reader.readBool()
        var layerNr: UInt8?
        // Per Table 4.1: scalable AOTs (6, 20) carry a 3-bit layer_nr.
        if audioObjectType == .aacScalable || audioObjectType == .erAACScalable {
            layerNr = UInt8(try reader.readBits(3))
        }
        var extFlag3: Bool?
        if extFlag {
            // For non-scalable General Audio family AOTs the
            // extension_flag3 follows the extension_flag bit directly;
            // its semantics are reserved.
            extFlag3 = try reader.readBool()
        }
        // Channel configuration is plumbed in for shape but does not
        // affect this struct's wire layout.
        _ = channelConfiguration
        return GASpecificConfig(
            frameLengthFlag: frameLength,
            dependsOnCoreCoder: dependsOnCore,
            coreCoderDelay: coreDelay,
            extensionFlag: extFlag,
            layerNr: layerNr,
            extensionFlag3: extFlag3
        )
    }

    public func encode(
        to writer: inout BitWriter,
        audioObjectType: MPEG4AudioObjectType
    ) {
        writer.writeBool(frameLengthFlag)
        writer.writeBool(dependsOnCoreCoder)
        if dependsOnCoreCoder {
            writer.writeBits(UInt64(coreCoderDelay ?? 0), count: 14)
        }
        writer.writeBool(extensionFlag)
        if audioObjectType == .aacScalable || audioObjectType == .erAACScalable {
            writer.writeBits(UInt64(layerNr ?? 0), count: 3)
        }
        if extensionFlag {
            writer.writeBool(extensionFlag3 ?? false)
        }
    }
}
