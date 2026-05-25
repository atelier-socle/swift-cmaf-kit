// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DumpTreeCommand
//
// Reference: cmafkit-cli `dump-tree` subcommand. Walks the
// ISOBMFF box hierarchy and prints each box's FourCC, size in
// bytes, and indented position.

import ArgumentParser
import CMAFKit
import Foundation

/// `cmafkit-cli dump-tree` — print the ISOBMFF box hierarchy.
public struct DumpTreeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "dump-tree",
        abstract: "Print the ISOBMFF box hierarchy with sizes and types.",
        discussion: """
            Walks the file's box tree top-down and renders each box's
            FourCC plus its declared on-wire size. Container boxes show
            their children indented underneath.

            Examples:
              cmafkit-cli dump-tree init.mp4
              cmafkit-cli dump-tree init.mp4 --depth 3
              cmafkit-cli dump-tree init.mp4 --output json
            """
    )

    @Argument(help: "Path to an ISOBMFF / CMAF file (or `-` for stdin).")
    public var input: String

    @Option(name: .long, help: "Maximum indent depth (default: unlimited).")
    public var depth: Int?

    @Option(name: .long, help: "Output format (text/json/table).")
    public var output: OutputFormat = .defaultFormat

    public init() {}

    public func run() async throws {
        let bytes = try await CLIInput.read(path: input)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes: [any ISOBox]
        do {
            boxes = try await reader.readBoxes(from: bytes, using: registry)
        } catch {
            throw CLIError.invalidInput(reason: "\(error)")
        }
        let limit = depth.map { max(0, $0) } ?? Int.max
        let nodes = boxes.map { Self.flatten(box: $0, depth: 0, limit: limit) }
        let report = DumpTreeReport(nodes: nodes)
        try CLIWrite.render(report: report, format: output)
    }

    private static func flatten(
        box: any ISOBox, depth: Int, limit: Int
    ) -> DumpTreeReport.Node {
        let type: String = {
            if let unknown = box as? UnknownBox {
                return "\(unknown.actualType)"
            }
            return "\(Swift.type(of: box).boxType)"
        }()
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let size = UInt64(writer.data.count)
        var children: [DumpTreeReport.Node] = []
        if depth < limit, let container = box as? any ISOContainerBox {
            children = container.children.map {
                flatten(box: $0, depth: depth + 1, limit: limit)
            }
        }
        return DumpTreeReport.Node(type: type, size: size, children: children)
    }
}

/// Typed value rendered by `dump-tree`.
public struct DumpTreeReport: Sendable, Equatable, Codable {

    public struct Node: Sendable, Equatable, Codable {
        public let type: String
        public let size: UInt64
        public let children: [Node]
    }

    public let nodes: [Node]
}

extension DumpTreeReport: TextRenderable {

    internal func renderText() -> String {
        var lines: [String] = []
        for node in nodes {
            renderTextNode(node, indent: 0, into: &lines)
        }
        return lines.joined(separator: "\n")
    }

    private func renderTextNode(
        _ node: Node, indent: Int, into lines: inout [String]
    ) {
        let prefix = String(repeating: "  ", count: indent)
        lines.append("\(prefix)\(node.type) (\(node.size) bytes)")
        for child in node.children {
            renderTextNode(child, indent: indent + 1, into: &lines)
        }
    }

    internal func renderTable() -> String {
        var rows: [[String]] = []
        for node in nodes {
            appendTableRows(node, indent: 0, into: &rows)
        }
        return TableFormatter.render(
            headers: ["box", "size", "children"], rows: rows
        )
    }

    private func appendTableRows(
        _ node: Node, indent: Int, into rows: inout [[String]]
    ) {
        let prefix = String(repeating: ". ", count: indent)
        rows.append([
            "\(prefix)\(node.type)", "\(node.size)", "\(node.children.count)"
        ])
        for child in node.children {
            appendTableRows(child, indent: indent + 1, into: &rows)
        }
    }
}
