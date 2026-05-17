// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ISOBoxReader
//
// Reference: ISO/IEC 14496-12 §4.2 (object-structured representation).
//
// Parses an ISOBMFF byte stream into a tree of typed `ISOBox` instances
// using a `BoxRegistry` to dispatch on FourCC. Unknown FourCCs become
// `UnknownBox` instances that preserve their payload byte-for-byte.

import Foundation

/// Reader entry point for ISOBMFF byte streams.
///
/// `ISOBoxReader` is a value type. Instances are cheap to construct; the
/// underlying state is the parser state on each `read` call. For
/// repeated-use scenarios, supply the same ``BoxRegistry`` across calls
/// to avoid re-creating the default registry each time.
public struct ISOBoxReader: Sendable {

    public init() {}

    // MARK: Reading from Data

    /// Parse all top-level boxes from a complete `Data` buffer.
    ///
    /// - Parameters:
    ///   - data: The complete ISOBMFF buffer (an init segment, a media
    ///     segment, or a full mp4 file held in memory).
    ///   - registry: The box registry to use for FourCC-to-parser dispatch.
    ///     When `nil`, a default registry is built once for this call.
    /// - Returns: The top-level boxes in the order they appear.
    public func readBoxes(
        from data: Data,
        using registry: BoxRegistry? = nil
    ) async throws -> [any ISOBox] {
        let activeRegistry: BoxRegistry
        if let registry {
            activeRegistry = registry
        } else {
            activeRegistry = await BoxRegistry.defaultRegistry()
        }
        var reader = BinaryReader(data)
        return try await readTopLevelBoxes(&reader, registry: activeRegistry)
    }

    // MARK: Reading from URL

    /// Parse all top-level boxes from a file URL.
    ///
    /// This method reads the file fully into memory. It is suitable for
    /// init segments and short media segments (typically < 50 MB). For
    /// long-form files (multi-GB), use a streaming reader.
    public func readBoxes(
        from url: URL,
        using registry: BoxRegistry? = nil
    ) async throws -> [any ISOBox] {
        let data = try Data(contentsOf: url)
        return try await readBoxes(from: data, using: registry)
    }

    // MARK: Random access

    /// Parse a single box of a known type at a known byte offset within the
    /// buffer.
    ///
    /// Useful when the consumer has indexing information from `sidx` /
    /// `ssix` and wants to read a specific moof or mdat directly.
    public func readBox<B: ISOBox>(
        _ type: B.Type,
        from data: Data,
        at offset: Int,
        using registry: BoxRegistry? = nil
    ) async throws -> B {
        let activeRegistry: BoxRegistry
        if let registry {
            activeRegistry = registry
        } else {
            activeRegistry = await BoxRegistry.defaultRegistry()
        }
        var reader = BinaryReader(data, offset: offset)
        let header = try parseBoxHeader(&reader)
        guard header.type == type.boxType else {
            throw ISOBoxError.unexpectedType(expected: type.boxType, found: header.type)
        }
        let box = try await dispatchParse(
            type: header.type,
            header: header,
            from: &reader,
            registry: activeRegistry
        )
        guard let typed = box as? B else {
            throw ISOBoxError.unexpectedType(expected: type.boxType, found: header.type)
        }
        return typed
    }

    // MARK: Path-based lookup

    /// Find a box anywhere in a tree by FourCC path.
    ///
    /// The path is `/`-separated FourCC components, for example
    /// `"moov/trak/mdia/minf/stbl/stsd"`. Leading `/` is optional. The
    /// first matching box at each level is followed. Returns `nil` if any
    /// segment fails to resolve.
    public func findBox(
        at path: String,
        in boxes: [any ISOBox]
    ) -> (any ISOBox)? {
        let stripped = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let segments = stripped.split(separator: "/").map(String.init)
        return walk(segments: segments, in: boxes)
    }

    // MARK: - Internals

    /// Read the box header at the reader's current offset. Resolves
    /// `size = 1` (largesize) and `type == "uuid"` (extended user type).
    internal func parseBoxHeader(_ reader: inout BinaryReader) throws -> ISOBoxHeader {
        let startOffset = reader.offset
        let rawSize = try reader.readUInt32()
        let rawType = try reader.readFourCC()

        var resolvedSize: UInt64
        var headerSize: Int

        if rawSize == 1 {
            // Largesize: read 64-bit size.
            let largesize = try reader.readUInt64()
            resolvedSize = largesize
            headerSize = 16
        } else if rawSize == 0 {
            // size == 0 means "extends to end of containing box / file".
            // For top-level, we leave the caller to detect end-of-buffer.
            resolvedSize = UInt64(reader.remaining + (reader.offset - startOffset))
            headerSize = 8
        } else {
            resolvedSize = UInt64(rawSize)
            headerSize = 8
        }

        var userType: UUID?
        if rawType == "uuid" {
            userType = try reader.readUUID()
            headerSize += 16
        }

        guard resolvedSize >= UInt64(headerSize) else {
            throw ISOBoxError.sizeSmallerThanHeader(
                declared: resolvedSize,
                headerSize: headerSize,
                type: rawType
            )
        }

        return ISOBoxHeader(
            type: rawType,
            size: resolvedSize,
            headerSize: headerSize,
            userType: userType
        )
    }

    /// Dispatch parsing of one box to the registry. Returns an
    /// ``UnknownBox`` if the FourCC is not registered.
    internal func dispatchParse(
        type: FourCC,
        header: ISOBoxHeader,
        from reader: inout BinaryReader,
        registry: BoxRegistry
    ) async throws -> any ISOBox {
        let bodySize = Int(header.size) - header.headerSize
        guard bodySize >= 0 else {
            throw ISOBoxError.sizeSmallerThanHeader(
                declared: header.size,
                headerSize: header.headerSize,
                type: type
            )
        }

        if let parser = await registry.parser(for: type) {
            // Carve out the body; hand a sub-reader to the parser so it cannot
            // overshoot into the next box.
            let bodyData = try reader.readData(count: bodySize)
            var bodyReader = BinaryReader(bodyData)
            return try await parser(&bodyReader, header, registry)
        } else {
            // Unknown box — preserve the body verbatim.
            let payload = try reader.readData(count: bodySize)
            return UnknownBox(actualType: type, header: header, payload: payload)
        }
    }

    /// Parse top-level boxes from the current reader position to the end.
    internal func readTopLevelBoxes(
        _ reader: inout BinaryReader,
        registry: BoxRegistry
    ) async throws -> [any ISOBox] {
        var boxes: [any ISOBox] = []
        while reader.remaining > 0 {
            let header = try parseBoxHeader(&reader)
            let box = try await dispatchParse(
                type: header.type,
                header: header,
                from: &reader,
                registry: registry
            )
            boxes.append(box)
        }
        return boxes
    }

    /// Helper used by container box parsers to read their children from the
    /// reader carved to the container's body.
    internal func readChildren(
        from reader: inout BinaryReader,
        registry: BoxRegistry
    ) async throws -> [any ISOBox] {
        return try await readTopLevelBoxes(&reader, registry: registry)
    }

    // MARK: Path walker

    private func walk(segments: [String], in boxes: [any ISOBox]) -> (any ISOBox)? {
        guard let head = segments.first else { return nil }
        guard let target = FourCC(head) else { return nil }

        for box in boxes {
            // Match by `actualType` for UnknownBox, by static `boxType` otherwise.
            let typeOnWire: FourCC
            if let unknown = box as? UnknownBox {
                typeOnWire = unknown.actualType
            } else {
                typeOnWire = Swift.type(of: box).boxType
            }
            guard typeOnWire == target else { continue }

            if segments.count == 1 {
                return box
            }

            if let container = box as? any ISOContainerBox {
                let remaining = Array(segments.dropFirst())
                return walk(segments: remaining, in: container.children)
            }
        }
        return nil
    }
}
