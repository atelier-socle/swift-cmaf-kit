// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCParametricCurveType
//
// Reference: ICC.1:2022 §10.16 (parametricCurveType, signature 'para').
//
// On-wire layout: UInt16 functionType + UInt16 reserved + parameters
// (count varies with functionType, each a s15Fixed16Number).

import Foundation

/// Parametric curve type per ICC.1:2022 §10.16.
public struct ICCParametricCurveType: Sendable, Hashable, Equatable, Codable {
    /// Function form indicator. Each form requires a specific number of
    /// parameters in the order documented by ICC.1:2022 Table 71.
    public enum FunctionType: UInt16, Sendable, Hashable, CaseIterable, Codable {
        /// Y = X^g. Requires `g`.
        case gammaOnly = 0
        /// Y = (aX + b)^g if X ≥ -b/a, else 0. Requires `g, a, b`.
        case ifNonNegative = 1
        /// Y = (aX + b)^g + c. Requires `g, a, b, c`.
        case withOffset = 2
        /// Piecewise (3 + 1 parameters). Requires `g, a, b, c, d`.
        case piecewise3 = 3
        /// Piecewise (3 + 1 parameters, shifted). Requires `g, a, b, c, d, e, f`.
        case piecewise4 = 4
    }

    public let functionType: FunctionType
    public let parameters: [ICCS15Fixed16Number]

    public init(functionType: FunctionType, parameters: [ICCS15Fixed16Number]) {
        self.functionType = functionType
        self.parameters = parameters
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCParametricCurveType {
        let fnRaw = try reader.readUInt16()
        guard let fn = FunctionType(rawValue: fnRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC parametricCurve functionType \(fnRaw)"
            )
        }
        try reader.skip(2)  // reserved
        let parameterCount = (byteCount - 4) / 4
        var params: [ICCS15Fixed16Number] = []
        params.reserveCapacity(parameterCount)
        for _ in 0..<parameterCount {
            params.append(try ICCS15Fixed16Number.parse(reader: &reader))
        }
        return ICCParametricCurveType(functionType: fn, parameters: params)
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt16(functionType.rawValue)
        writer.writeZeros(2)
        for p in parameters { p.encode(to: &writer) }
    }
}
