// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AVCScalingList")
struct AVCScalingListTests {

    @Test
    func explicit4x4DeltaRoundTrip() throws {
        // A trivial flat-16 scaling list: 16 zero deltas (every value
        // inherits from the previous).
        let list = AVCScalingList.explicit(deltas: Array(repeating: Int32(0), count: 16))
        var writer = BitWriter()
        list.encode(to: &writer, count: 16)
        writer.writeBit(1)  // pseudo stop bit so reader can advance
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCScalingList.parse(reader: &reader, count: 16)
        // After the very first delta (0), nextScale stays at 8 (non-zero),
        // so the parser keeps reading. The trip must equal the original.
        #expect(decoded == list)
    }

    @Test
    func useDefaultIsSignalledWithSingleDelta() throws {
        let list = AVCScalingList.useDefault
        var writer = BitWriter()
        list.encode(to: &writer, count: 16)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCScalingList.parse(reader: &reader, count: 16)
        #expect(decoded == .useDefault)
    }

    @Test
    func explicit8x8RoundTrip() throws {
        let list = AVCScalingList.explicit(deltas: Array(repeating: Int32(0), count: 64))
        var writer = BitWriter()
        list.encode(to: &writer, count: 64)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCScalingList.parse(reader: &reader, count: 64)
        #expect(decoded == list)
    }

    @Test
    func scalingMatrixAllNilLists() throws {
        let matrix = AVCScalingMatrix(
            lists4x4: Array(repeating: nil, count: 6),
            lists8x8: Array(repeating: nil, count: 2)
        )
        var writer = BitWriter()
        matrix.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCScalingMatrix.parse(reader: &reader, chromaFormatIDC: 1)
        #expect(decoded == matrix)
    }
}
