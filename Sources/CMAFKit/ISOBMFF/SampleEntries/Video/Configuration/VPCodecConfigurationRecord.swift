// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - VPCodecConfigurationRecord (vpcC)
//
// Reference: VP Codec ISO Media File Format Binding v1.0 §2.4.
//
// `vpcC` is a full box (4-byte version + flags prefix). On-wire layout
// after the full-box header:
//   UInt8 profile
//   UInt8 level
//   UInt8 (bitDepth: 4 | chromaSubsampling: 3 | videoFullRangeFlag: 1)
//   UInt8 colourPrimaries
//   UInt8 transferCharacteristics
//   UInt8 matrixCoefficients
//   UInt16 codecInitializationDataSize (always 0 per current spec)
//   codecInitializationDataSize bytes codecInitializationData

import Foundation

/// VP codec configuration record carried by the `vpcC` full box.
///
/// Reference: VP Codec ISO Media File Format Binding v1.0 §2.4.
public struct VPCodecConfigurationRecord: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "vpcC"

    public let version: UInt8
    public let flags: UInt32
    public let profile: VPProfile
    public let level: VPLevel
    public let bitDepth: UInt8
    public let chromaSubsampling: VPChromaSubsampling
    public let videoFullRangeFlag: VideoFullRangeFlag
    public let colourPrimaries: ColorPrimaries
    public let transferCharacteristics: TransferCharacteristics
    public let matrixCoefficients: MatrixCoefficients
    public let codecInitializationData: Data

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        profile: VPProfile,
        level: VPLevel,
        bitDepth: UInt8,
        chromaSubsampling: VPChromaSubsampling,
        videoFullRangeFlag: VideoFullRangeFlag,
        colourPrimaries: ColorPrimaries,
        transferCharacteristics: TransferCharacteristics,
        matrixCoefficients: MatrixCoefficients,
        codecInitializationData: Data = Data()
    ) {
        precondition(
            bitDepth <= 0x0F,
            "VP bitDepth must fit in 4 bits"
        )
        self.version = version
        self.flags = flags
        self.profile = profile
        self.level = level
        self.bitDepth = bitDepth
        self.chromaSubsampling = chromaSubsampling
        self.videoFullRangeFlag = videoFullRangeFlag
        self.colourPrimaries = colourPrimaries
        self.transferCharacteristics = transferCharacteristics
        self.matrixCoefficients = matrixCoefficients
        self.codecInitializationData = codecInitializationData
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> VPCodecConfigurationRecord {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()

        let profileRaw = try reader.readUInt8()
        guard let profile = VPProfile(rawValue: profileRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown VP profile \(profileRaw)"
            )
        }
        let levelRaw = try reader.readUInt8()
        guard let level = VPLevel(rawValue: levelRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown VP level \(levelRaw)"
            )
        }
        let packed = try reader.readUInt8()
        let bitDepth = (packed >> 4) & 0x0F
        let chromaRaw = (packed >> 1) & 0x07
        // ChromaSubsampling is documented as 3 bits, but only values 0..3
        // are defined per VP Codec ISO Media File Format Binding §2.4.
        guard let chroma = VPChromaSubsampling(rawValue: chromaRaw & 0x03) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown VP chroma subsampling \(chromaRaw)"
            )
        }
        let rangeRaw = packed & 0x01
        guard let range = VideoFullRangeFlag(rawValue: rangeRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown VP videoFullRangeFlag \(rangeRaw)"
            )
        }
        let primariesRaw = try reader.readUInt8()
        guard let primaries = ColorPrimaries(rawValue: primariesRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown VP colour_primaries \(primariesRaw)"
            )
        }
        let transferRaw = try reader.readUInt8()
        guard let transfer = TransferCharacteristics(rawValue: transferRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown VP transfer_characteristics \(transferRaw)"
            )
        }
        let matrixRaw = try reader.readUInt8()
        guard let matrix = MatrixCoefficients(rawValue: matrixRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown VP matrix_coefficients \(matrixRaw)"
            )
        }
        let initSize = try reader.readUInt16()
        let initData = try reader.readData(count: Int(initSize))

        return VPCodecConfigurationRecord(
            version: version,
            flags: flags,
            profile: profile,
            level: level,
            bitDepth: bitDepth,
            chromaSubsampling: chroma,
            videoFullRangeFlag: range,
            colourPrimaries: primaries,
            transferCharacteristics: transfer,
            matrixCoefficients: matrix,
            codecInitializationData: initData
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt8(profile.rawValue)
            body.writeUInt8(level.rawValue)
            var packed: UInt8 = (bitDepth & 0x0F) << 4
            packed |= (chromaSubsampling.rawValue & 0x07) << 1
            packed |= videoFullRangeFlag.rawValue & 0x01
            body.writeUInt8(packed)
            body.writeUInt8(colourPrimaries.rawValue)
            body.writeUInt8(transferCharacteristics.rawValue)
            body.writeUInt8(matrixCoefficients.rawValue)
            body.writeUInt16(UInt16(codecInitializationData.count))
            body.writeData(codecInitializationData)
        }
    }
}
