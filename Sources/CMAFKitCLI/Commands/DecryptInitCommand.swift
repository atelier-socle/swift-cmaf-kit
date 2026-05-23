// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DecryptInitCommand
//
// Reference: cmafkit-cli `decrypt-init` subcommand. Parses every
// `pssh` box in the init segment and prints its typed init data.
// The command name reflects "initialisation data" — no content
// decryption happens; key material is never handled.

import ArgumentParser
import CMAFKit
import CMAFKitDRM
import Foundation

/// `cmafkit-cli decrypt-init` — print typed DRM init data for
/// every `pssh` box in a CMAF init segment.
public struct DecryptInitCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "decrypt-init",
        abstract:
            "Print typed DRM init data for every pssh box in a CMAF init segment.",
        discussion: """
            Decodes the opaque `pssh.data` for every recognised DRM
            system (Widevine, PlayReady, FairPlay, ClearKey, Marlin,
            Nagra, Verimatrix, Adobe Primetime, China DRM) and prints
            its typed shape. Does NOT decrypt content — no key material
            is handled.

            Examples:
              cmafkit-cli decrypt-init init.mp4
              cmafkit-cli decrypt-init init.mp4 --output json
            """
    )

    @Argument(help: "Path to a CMAF init segment (or `-` for stdin).")
    public var input: String

    @Option(name: .long, help: "Output format (text/json/table).")
    public var output: OutputFormat = .defaultFormat

    public init() {}

    public func run() async throws {
        let bytes = try await CLIInput.read(path: input)
        let reader: CMAFInitSegmentReader
        do {
            reader = try await CMAFInitSegmentReader(bytes: bytes)
        } catch {
            throw CLIError.invalidInput(reason: "\(error)")
        }
        let psshBoxes = reader.protectionSystemSpecificHeaders()
        var entries: [DecryptInitReport.Entry] = []
        for box in psshBoxes {
            let typed: TypedDRMInitData
            do {
                typed = try box.typedInitData()
            } catch let error as DRMSystemError {
                throw CLIError.drmParseFailed(
                    systemID: box.systemID.uuidString,
                    reason: "\(error)"
                )
            }
            entries.append(DecryptInitReport.Entry(from: box, typed: typed))
        }
        let report = DecryptInitReport(psshCount: psshBoxes.count, entries: entries)
        try CLIWrite.render(report: report, format: output)
    }
}

/// Typed report rendered by `decrypt-init`.
public struct DecryptInitReport: Sendable, Equatable, Codable {

    public struct Entry: Sendable, Equatable, Codable {
        public let systemID: String
        public let systemName: String
        public let provider: String?
        public let kidCount: Int
        public let keyIDs: [String]
        public let rawBytesLength: Int
        public let typedSummary: String

        public init(from box: ProtectionSystemSpecificHeaderBox, typed: TypedDRMInitData) {
            self.systemID = box.systemID.uuidString
            self.rawBytesLength = box.data.count

            let knownID = KnownDRMSystemID(uuid: box.systemID)
            switch knownID {
            case .widevine: self.systemName = "Widevine"
            case .playReady: self.systemName = "PlayReady"
            case .fairPlay: self.systemName = "FairPlay"
            case .clearKey: self.systemName = "ClearKey"
            case .marlin: self.systemName = "Marlin"
            case .nagra: self.systemName = "Nagra"
            case .verimatrix: self.systemName = "Verimatrix"
            case .adobePrimetime: self.systemName = "Adobe Primetime"
            case .chinaDRM: self.systemName = "China DRM"
            case .other: self.systemName = "(unknown)"
            }

            switch typed {
            case .widevine(let value):
                self.provider = value.provider
                self.kidCount = value.keyIDs.count
                self.keyIDs = value.keyIDs.map(Entry.hex)
                self.typedSummary = "Widevine CencHeader (\(value.keyIDs.count) KID(s))"
            case .playReady(let value):
                self.provider = nil
                var allKIDs: [Data] = []
                for record in value.records {
                    if case let .wrmHeader(header) = record {
                        allKIDs.append(contentsOf: header.kids.map(\.value))
                    }
                }
                self.kidCount = allKIDs.count
                self.keyIDs = allKIDs.map(Entry.hex)
                self.typedSummary =
                    "PlayReady (records: \(value.records.count), KIDs: \(allKIDs.count))"
            case .fairPlay(let value):
                self.provider = nil
                self.kidCount = value.keyIDs.count
                self.keyIDs = value.keyIDs.map(Entry.hex)
                self.typedSummary = "FairPlay Modular DRM (\(value.keyIDs.count) KID(s))"
            case .clearKey(let value):
                self.provider = nil
                self.kidCount = value.kids.count
                self.keyIDs = value.kids.map(Entry.hex)
                self.typedSummary = "ClearKey type=\(value.type.rawValue), KIDs: \(value.kids.count)"
            case .marlin(let value):
                self.provider = nil
                self.kidCount = value.broadbandAssetIdentifier == nil ? 0 : 1
                self.keyIDs =
                    value.broadbandAssetIdentifier
                    .map { [Entry.hex($0.kid)] } ?? []
                self.typedSummary = "Marlin Broadband"
            case .nagra(let value):
                self.provider = nil
                self.kidCount = 0
                self.keyIDs = []
                self.typedSummary = "Nagra opaque (\(value.rawBytes.count) bytes)"
            case .verimatrix(let value):
                self.provider = nil
                self.kidCount = 0
                self.keyIDs = []
                self.typedSummary = "Verimatrix opaque (\(value.rawBytes.count) bytes)"
            case .adobePrimetime(let value):
                self.provider = nil
                self.kidCount = 0
                self.keyIDs = []
                self.typedSummary =
                    "Adobe Primetime (deprecated service) — \(value.rawBytes.count) bytes"
            case .chinaDRM(let value):
                self.provider = nil
                self.kidCount = value.kids.count
                self.keyIDs = value.kids.map(Entry.hex)
                self.typedSummary = "ChinaDRM (\(value.kids.count) KID(s))"
            case .unknown(_, let bytes):
                self.provider = nil
                self.kidCount = 0
                self.keyIDs = []
                self.typedSummary = "Unknown DRM system (\(bytes.count) bytes)"
            }
        }

        private static func hex(_ bytes: Data) -> String {
            TextFormatter.hex(bytes)
        }
    }

    public let psshCount: Int
    public let entries: [Entry]
}

extension DecryptInitReport: TextRenderable {

    internal func renderText() -> String {
        var lines: [String] = []
        lines.append(TextFormatter.header("DRM init data"))
        lines.append(TextFormatter.keyValue("pssh boxes", "\(psshCount)"))
        for entry in entries {
            lines.append("")
            lines.append(TextFormatter.header(entry.systemName))
            lines.append(TextFormatter.keyValue("  systemID", entry.systemID))
            lines.append(TextFormatter.keyValue("  bytes", "\(entry.rawBytesLength)"))
            lines.append(TextFormatter.keyValue("  KIDs", "\(entry.kidCount)"))
            for kid in entry.keyIDs {
                lines.append("    - \(kid)")
            }
            lines.append(TextFormatter.keyValue("  summary", entry.typedSummary))
        }
        return lines.joined(separator: "\n")
    }

    internal func renderTable() -> String {
        let headers = ["system", "systemID", "bytes", "KIDs", "summary"]
        let rows: [[String]] = entries.map { e in
            [
                e.systemName, e.systemID, "\(e.rawBytesLength)",
                "\(e.kidCount)", e.typedSummary
            ]
        }
        return TableFormatter.render(headers: headers, rows: rows)
    }
}
