// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitCommands

@Suite("Output formatters")
struct OutputFormattersTests {

    // MARK: - OutputFormat

    @Test
    func outputFormatAllCasesIsThree() {
        #expect(OutputFormat.allCases.count == 3)
    }

    @Test
    func outputFormatDefaultIsText() {
        #expect(OutputFormat.defaultFormat == .text)
    }

    // MARK: - JSONFormatter

    @Test
    func jsonFormatterEncodesSortedKeys() throws {
        struct Payload: Codable, Equatable {
            let zebra: Int
            let alpha: Int
        }
        let json = try JSONFormatter.string(Payload(zebra: 1, alpha: 2))
        let alphaPos = try #require(json.range(of: "\"alpha\""))
        let zebraPos = try #require(json.range(of: "\"zebra\""))
        #expect(alphaPos.lowerBound < zebraPos.lowerBound)
    }

    @Test
    func jsonFormatterPrettyPrints() throws {
        struct Payload: Codable { let value: Int }
        let json = try JSONFormatter.string(Payload(value: 42))
        #expect(json.contains("\n"))
        #expect(json.contains("\"value\""))
    }

    // MARK: - TextFormatter

    @Test
    func textFormatterKeyValueLine() {
        #expect(TextFormatter.keyValue("name", "Alice") == "name: Alice")
    }

    @Test
    func textFormatterHeaderUnderlinesTitle() {
        let result = TextFormatter.header("abc")
        let parts = result.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(parts.count == 2)
        #expect(parts[0] == "abc")
        #expect(parts[1].count == 3)
    }

    @Test
    func textFormatterListHandlesEmpty() {
        #expect(TextFormatter.list([]) == "(none)")
    }

    @Test
    func textFormatterListJoinsWithCommas() {
        #expect(TextFormatter.list(["a", "b", "c"]) == "a, b, c")
    }

    @Test
    func textFormatterHexLowercaseNoSeparator() {
        let bytes = Data([0x00, 0xAB, 0xCD, 0xFF])
        #expect(TextFormatter.hex(bytes) == "00abcdff")
    }

    // MARK: - TableFormatter

    @Test
    func tableFormatterRendersHeaderUnderlineAndRows() {
        let table = TableFormatter.render(
            headers: ["a", "b"],
            rows: [["1", "22"], ["33", "4"]]
        )
        let lines = table.split(separator: "\n")
        #expect(lines.count == 4)  // header + separator + 2 rows
        #expect(table.contains("a"))
        #expect(table.contains("22"))
    }

    @Test
    func tableFormatterPadsToWidestColumnValue() {
        let table = TableFormatter.render(
            headers: ["x"], rows: [["short"], ["longer"]]
        )
        // The header column must be padded to fit the widest cell.
        let lines = table.split(separator: "\n")
        let headerLine = String(lines[0])
        #expect(headerLine.contains("x     "))  // padded
    }
}
