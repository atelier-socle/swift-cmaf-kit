// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BoxRegistry
//
// Reference: ISO/IEC 14496-12 §4.2 (object-structured representation).
//
// Maps FourCC values to factory closures that parse a box body into a
// concrete `ISOBox` instance. Built-in boxes register here; consumers may
// register additional box types for proprietary extensions.

import Foundation

/// FourCC-keyed registry of box parsers.
///
/// The registry is an `actor` so concurrent producers can extend it without
/// external synchronisation. The default registry, pre-populated with every
/// box type CMAFKit ships, is obtained via ``defaultRegistry()``.
///
/// The parser closure receives a `BinaryReader` carved to the box body
/// (already past the resolved header), the resolved ``ISOBoxHeader`` for
/// metadata such as `size` and optional uuid extended type, and the
/// registry itself so container boxes can recursively parse their children.
public actor BoxRegistry {

    /// The signature for every box parser.
    ///
    /// The reader is positioned at the start of the box body (the bytes
    /// after the header). The header argument carries the resolved size,
    /// header size, and optional uuid extended type. The registry argument
    /// allows container boxes to recurse into their children.
    public typealias Parser =
        @Sendable (
            _ reader: inout BinaryReader,
            _ header: ISOBoxHeader,
            _ registry: BoxRegistry
        ) async throws -> any ISOBox

    private var parsers: [FourCC: Parser] = [:]

    public init() {}

    /// Register a parser for a given FourCC. Registering the same FourCC
    /// twice overrides the previous entry.
    public func register(_ fourCC: FourCC, parser: @escaping Parser) {
        parsers[fourCC] = parser
    }

    /// Register a parser keyed by the box type's static `boxType`.
    public func register<B: ISOBox>(_ type: B.Type, parser: @escaping Parser) {
        parsers[type.boxType] = parser
    }

    /// The parser registered for `fourCC`, or `nil` if none is registered.
    public func parser(for fourCC: FourCC) -> Parser? {
        parsers[fourCC]
    }

    /// All FourCC values currently registered, in unspecified order.
    public var registeredFourCCs: [FourCC] {
        Array(parsers.keys)
    }

    /// The default registry, populated with every box type CMAFKit ships.
    ///
    /// Construction is async because the registry is an `actor` and each
    /// registration is an actor call.
    public static func defaultRegistry() async -> BoxRegistry {
        let registry = BoxRegistry()
        await registry.registerBuiltins()
        return registry
    }

    /// Registers every built-in box parser.
    ///
    /// Called from ``defaultRegistry()``. The implementation lives in
    /// `BoxRegistry+Builtins.swift` and is extended over time as new box
    /// types are added to the library.
    internal func registerBuiltins() async {
        await registerBuiltinBoxes()
    }
}
