// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCColorantOrderType")
struct ICCColorantOrderTypeTests {

    @Test
    func emptyRoundTrip() throws {
        let original = ICCColorantOrderType(order: [])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCColorantOrderType.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
        #expect(decoded.order.isEmpty)
    }

    @Test
    func singleEntryRoundTrip() throws {
        let original = ICCColorantOrderType(order: [5])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCColorantOrderType.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
        #expect(decoded.order == [5])
    }

    @Test
    func multipleEntriesRoundTrip() throws {
        let indices: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7]
        let original = ICCColorantOrderType(order: indices)
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCColorantOrderType.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
    }

    @Test
    func parseFromKnownHex() throws {
        // count=3, indices=[2, 0, 1]
        let bytes = Data(hex: "00000003 02 00 01")
        var reader = BinaryReader(bytes)
        let decoded = try ICCColorantOrderType.parsePayload(
            reader: &reader,
            byteCount: bytes.count
        )
        #expect(decoded.order == [2, 0, 1])
    }

    @Test
    func encodeProducesExpectedBytes() {
        let value = ICCColorantOrderType(order: [2, 0, 1])
        var writer = BinaryWriter()
        value.encodePayload(to: &writer)
        let expected = Data(hex: "00000003 02 00 01")
        #expect(writer.data == expected)
    }

    @Test
    func roundTripThroughICCElementDispatch() throws {
        let value = ICCColorantOrderType(order: [3, 1, 2])
        let element = ICCElement.colorantOrder(value)

        var writer = BinaryWriter()
        element.encode(to: &writer)
        let elementBytes = writer.data

        var reader = BinaryReader(elementBytes)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: elementBytes.count
        )
        #expect(decoded == element)
    }

    @Test
    func truncatedInputThrows() {
        // count declares 5 but only 2 bytes follow.
        let bytes = Data(hex: "00000005 AA BB")
        #expect(throws: Error.self) {
            var reader = BinaryReader(bytes)
            _ = try ICCColorantOrderType.parsePayload(
                reader: &reader,
                byteCount: bytes.count
            )
        }
    }

    @Test
    func equalityAndHashing() {
        let a = ICCColorantOrderType(order: [1, 2, 3])
        let b = ICCColorantOrderType(order: [1, 2, 3])
        let c = ICCColorantOrderType(order: [1, 2, 4])
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }

    @Test
    func maxColorantsRoundTrip() throws {
        let indices: [UInt8] = (0..<255).map { UInt8($0) }
        let original = ICCColorantOrderType(order: indices)
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCColorantOrderType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.order.count == 255)
    }

    @Test
    func orderIndicesPreserveOrder() throws {
        let indices: [UInt8] = [5, 2, 1, 3, 4, 0]
        let original = ICCColorantOrderType(order: indices)
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCColorantOrderType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.order == indices)
    }

    @Test
    func bodySizeMatchesCountPlusFour() {
        let original = ICCColorantOrderType(order: [10, 20, 30, 40])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        #expect(writer.data.count == 4 + 4)
    }

    @Test
    func maxUInt8ValuePreserved() throws {
        let original = ICCColorantOrderType(order: [0xFF])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCColorantOrderType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.order == [0xFF])
    }
}
