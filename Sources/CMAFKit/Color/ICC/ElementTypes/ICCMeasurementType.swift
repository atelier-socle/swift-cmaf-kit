// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCMeasurementType
//
// Reference: ICC.1:2022 §10.14 (measurementType, signature 'meas').
//
// On-wire layout (36 bytes total):
//   UInt32 standardObserver + XYZNumber backing (12 bytes)
//   + UInt32 measurementGeometry + u16Fixed16 measurementFlare
//   + UInt32 standardIlluminant.

import Foundation

/// Measurement type per ICC.1:2022 §10.14.
public struct ICCMeasurementType: Sendable, Hashable, Equatable, Codable {
    /// Standard observer category per ICC.1:2022.
    public enum StandardObserver: UInt32, Sendable, Hashable, CaseIterable, Codable {
        case unknown = 0
        case cie1931_2deg = 1
        case cie1964_10deg = 2
    }

    /// Measurement geometry per ICC.1:2022.
    public enum MeasurementGeometry: UInt32, Sendable, Hashable, CaseIterable, Codable {
        case unknown = 0
        case zeroDegree_45OrFortyFiveDegree_0 = 1
        case zeroDegree_d_or_d_zeroDegree = 2
    }

    /// Standard illuminant per ICC.1:2022.
    public enum StandardIlluminant: UInt32, Sendable, Hashable, CaseIterable, Codable {
        case unknown = 0
        case d50 = 1
        case d65 = 2
        case d93 = 3
        case f2 = 4
        case d55 = 5
        case a = 6
        case equiPowerE = 7
        case f8 = 8
    }

    public let standardObserver: StandardObserver
    public let backingMeasurement: ICCXYZNumber
    public let measurementGeometry: MeasurementGeometry
    public let measurementFlare: ICCU16Fixed16Number
    public let standardIlluminant: StandardIlluminant

    public init(
        standardObserver: StandardObserver,
        backingMeasurement: ICCXYZNumber,
        measurementGeometry: MeasurementGeometry,
        measurementFlare: ICCU16Fixed16Number,
        standardIlluminant: StandardIlluminant
    ) {
        self.standardObserver = standardObserver
        self.backingMeasurement = backingMeasurement
        self.measurementGeometry = measurementGeometry
        self.measurementFlare = measurementFlare
        self.standardIlluminant = standardIlluminant
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCMeasurementType {
        let observerRaw = try reader.readUInt32()
        guard let observer = StandardObserver(rawValue: observerRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC measurement standardObserver \(observerRaw)"
            )
        }
        let backing = try ICCXYZNumber.parse(reader: &reader)
        let geomRaw = try reader.readUInt32()
        guard let geom = MeasurementGeometry(rawValue: geomRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC measurement geometry \(geomRaw)"
            )
        }
        let flare = try ICCU16Fixed16Number.parse(reader: &reader)
        let illumRaw = try reader.readUInt32()
        guard let illum = StandardIlluminant(rawValue: illumRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC standard illuminant \(illumRaw)"
            )
        }
        return ICCMeasurementType(
            standardObserver: observer,
            backingMeasurement: backing,
            measurementGeometry: geom,
            measurementFlare: flare,
            standardIlluminant: illum
        )
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt32(standardObserver.rawValue)
        backingMeasurement.encode(to: &writer)
        writer.writeUInt32(measurementGeometry.rawValue)
        measurementFlare.encode(to: &writer)
        writer.writeUInt32(standardIlluminant.rawValue)
    }
}
