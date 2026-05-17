// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCResponseCurveSet16Type
//
// Reference: ICC.1:2022 §10.20 (responseCurveSet16Type, signature 'rcs2').
//
// On-wire layout (after the 8-byte type preamble):
//   UInt16 numberOfChannels (n)
//   UInt16 measurementTypeCount (m)
//   m × UInt32 offsetToMeasurementType[i]   (relative to start of
//                                            element data — i.e. the
//                                            start of the 8-byte preamble)
//   For each measurement type i:
//     UInt32 measurementUnitSig
//     n × UInt32 measurementCount per channel
//     n × ICCXYZNumber pcsValuesAtMaxColorant per channel
//     For each channel c:
//       measurementCount[c] × ICCResponse16Number
//
// The offset table allows non-contiguous storage on read; encoding emits
// a contiguous canonical layout.

import Foundation

/// Response-curve set for n channels and m measurement types, per
/// ICC.1:2022 §10.20.
public struct ICCResponseCurveSet16Type: Sendable, Hashable, Equatable {

    /// One measurement-type entry within the response-curve set.
    public struct MeasurementTypeEntry: Sendable, Hashable, Equatable {
        /// Measurement unit signature.
        public let measurementUnit: ICCMeasurementUnitSignature
        /// PCS XYZ value at the maximum colorant per channel. Count
        /// equals the parent ``numberOfChannels``.
        public let pcsValuesAtMaxColorant: [ICCXYZNumber]
        /// Measurements per channel. Outer count equals the parent
        /// ``numberOfChannels``.
        public let measurementsByChannel: [[ICCResponse16Number]]

        public init(
            measurementUnit: ICCMeasurementUnitSignature,
            pcsValuesAtMaxColorant: [ICCXYZNumber],
            measurementsByChannel: [[ICCResponse16Number]]
        ) {
            precondition(
                pcsValuesAtMaxColorant.count == measurementsByChannel.count,
                "ICCResponseCurveSet16Type: channel counts disagree"
            )
            self.measurementUnit = measurementUnit
            self.pcsValuesAtMaxColorant = pcsValuesAtMaxColorant
            self.measurementsByChannel = measurementsByChannel
        }
    }

    public let numberOfChannels: UInt16
    public let measurementTypes: [MeasurementTypeEntry]

    public init(numberOfChannels: UInt16, measurementTypes: [MeasurementTypeEntry]) {
        for entry in measurementTypes {
            precondition(
                entry.pcsValuesAtMaxColorant.count == Int(numberOfChannels),
                "ICCResponseCurveSet16Type: per-channel counts must match numberOfChannels"
            )
        }
        self.numberOfChannels = numberOfChannels
        self.measurementTypes = measurementTypes
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCResponseCurveSet16Type {
        // Snapshot the payload for offset-based access.
        let payload = try reader.readData(count: byteCount)
        var head = BinaryReader(payload)

        let numberOfChannels = try head.readUInt16()
        let measurementTypeCount = try head.readUInt16()

        var offsets: [UInt32] = []
        offsets.reserveCapacity(Int(measurementTypeCount))
        for _ in 0..<measurementTypeCount {
            offsets.append(try head.readUInt32())
        }

        // Offsets are relative to the start of the element data, which
        // includes the 8-byte preamble that sits in front of `payload`.
        let preambleOffset = 8

        var entries: [MeasurementTypeEntry] = []
        entries.reserveCapacity(Int(measurementTypeCount))
        for offsetWire in offsets {
            let offsetInPayload = Int(offsetWire) - preambleOffset
            guard offsetInPayload >= 0, offsetInPayload < payload.count else {
                throw ISOBoxError.malformedFullBox(
                    type: "colr",
                    reason: "ICC rcs2 measurement-type offset out of payload bounds"
                )
            }
            let absStart = payload.startIndex.advanced(by: offsetInPayload)
            let slice = payload.subdata(in: absStart..<payload.endIndex)
            var entryReader = BinaryReader(slice)
            let entry = try parseMeasurementTypeEntry(
                reader: &entryReader,
                numberOfChannels: numberOfChannels
            )
            entries.append(entry)
        }

        return ICCResponseCurveSet16Type(
            numberOfChannels: numberOfChannels,
            measurementTypes: entries
        )
    }

    private static func parseMeasurementTypeEntry(
        reader: inout BinaryReader,
        numberOfChannels: UInt16
    ) throws -> MeasurementTypeEntry {
        let unitRaw = try reader.readUInt32()
        guard let unit = ICCMeasurementUnitSignature(rawValue: unitRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC rcs2 measurement-unit signature 0x\(String(unitRaw, radix: 16))"
            )
        }

        var perChannelCounts: [UInt32] = []
        perChannelCounts.reserveCapacity(Int(numberOfChannels))
        for _ in 0..<numberOfChannels {
            perChannelCounts.append(try reader.readUInt32())
        }

        var pcsValues: [ICCXYZNumber] = []
        pcsValues.reserveCapacity(Int(numberOfChannels))
        for _ in 0..<numberOfChannels {
            pcsValues.append(try ICCXYZNumber.parse(reader: &reader))
        }

        var measurementsByChannel: [[ICCResponse16Number]] = []
        measurementsByChannel.reserveCapacity(Int(numberOfChannels))
        for c in 0..<Int(numberOfChannels) {
            let count = Int(perChannelCounts[c])
            var perChannel: [ICCResponse16Number] = []
            perChannel.reserveCapacity(count)
            for _ in 0..<count {
                perChannel.append(try ICCResponse16Number.parse(reader: &reader))
            }
            measurementsByChannel.append(perChannel)
        }

        return MeasurementTypeEntry(
            measurementUnit: unit,
            pcsValuesAtMaxColorant: pcsValues,
            measurementsByChannel: measurementsByChannel
        )
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        let preambleSize = 8
        let headerSize = 2 + 2 + 4 * measurementTypes.count

        // First pass: encode each entry into its own buffer and record
        // the wire-relative offset where it will land.
        var entryBuffers: [Data] = []
        entryBuffers.reserveCapacity(measurementTypes.count)
        var offsetsWire: [UInt32] = []
        offsetsWire.reserveCapacity(measurementTypes.count)

        var cursor = preambleSize + headerSize
        for entry in measurementTypes {
            var entryWriter = BinaryWriter()
            entryWriter.writeUInt32(entry.measurementUnit.rawValue)
            for channel in entry.measurementsByChannel {
                entryWriter.writeUInt32(UInt32(channel.count))
            }
            for value in entry.pcsValuesAtMaxColorant {
                value.encode(to: &entryWriter)
            }
            for channel in entry.measurementsByChannel {
                for r in channel { r.encode(to: &entryWriter) }
            }
            offsetsWire.append(UInt32(cursor))
            entryBuffers.append(entryWriter.data)
            cursor += entryWriter.data.count
        }

        writer.writeUInt16(numberOfChannels)
        writer.writeUInt16(UInt16(measurementTypes.count))
        for offset in offsetsWire {
            writer.writeUInt32(offset)
        }
        for buffer in entryBuffers {
            writer.writeData(buffer)
        }
    }
}
