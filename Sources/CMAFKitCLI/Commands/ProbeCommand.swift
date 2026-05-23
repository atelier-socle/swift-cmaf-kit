// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProbeCommand
//
// Reference: cmafkit-cli `probe` subcommand. Reads the init
// segment of an ISOBMFF / CMAF file and reports per-track
// metadata: track ID, kind, codec, encryption scheme, language,
// profile, ftyp brands. Read-only; never modifies the input.

import ArgumentParser
import CMAFKit
import Foundation

/// `cmafkit-cli probe` — report per-track metadata for a CMAF
/// init segment.
public struct ProbeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "probe",
        abstract: "Print per-track metadata for a CMAF init segment.",
        discussion: """
            Reads the first init segment (`ftyp` + `moov`) in the supplied
            file and reports per-track summary: trackID, kind, codec,
            encryption scheme, language, profile.

            Examples:
              cmafkit-cli probe init.mp4
              cmafkit-cli probe init.mp4 --output json
            """
    )

    @Argument(help: "Path to a CMAF init segment file (or `-` to read stdin).")
    public var input: String

    @Option(name: .long, help: "Output format (text/json/table).")
    public var output: OutputFormat = .defaultFormat

    @Flag(name: .long, help: "Emit verbose diagnostics on stderr.")
    public var verbose: Bool = false

    public init() {}

    public func run() async throws {
        let bytes = try await CLIInput.read(path: input)
        let reader: CMAFInitSegmentReader
        do {
            reader = try await CMAFInitSegmentReader(bytes: bytes)
        } catch {
            throw CLIError.invalidInput(reason: "\(error)")
        }
        let tracks = reader.tracks()
        let report = ProbeReport(
            majorBrand: reader.majorBrand().description,
            compatibleBrands: reader.compatibleBrands().map(\.description),
            movieTimescale: reader.movieTimescale(),
            trackCount: tracks.count,
            tracks: tracks.map(ProbeReport.TrackSummary.init(from:))
        )
        try CLIWrite.render(report: report, format: output)
    }
}

/// Typed value rendered by `probe`.
public struct ProbeReport: Sendable, Equatable, Codable {

    /// Per-track summary line.
    public struct TrackSummary: Sendable, Equatable, Codable {
        public let trackID: UInt32
        public let kind: String
        public let codec: String
        public let language: String
        public let profile: String
        public let encryption: String?

        public init(from config: CMAFTrackConfiguration) {
            self.trackID = config.trackID
            self.kind = "\(config.kind)"
            if let video = config.videoFields {
                self.codec = "\(video.codec)"
            } else if let audio = config.audioFields {
                self.codec = "\(audio.codec)"
            } else if let subtitle = config.subtitleFields {
                self.codec = "\(subtitle.codec)"
            } else if config.metadataFields != nil {
                self.codec = "meta"
            } else {
                self.codec = "(none)"
            }
            self.language = config.language
            self.profile = "\(config.profile)"
            self.encryption = config.encryptionParameters.map { "\($0.scheme)" }
        }
    }

    public let majorBrand: String
    public let compatibleBrands: [String]
    public let movieTimescale: UInt32
    public let trackCount: Int
    public let tracks: [TrackSummary]
}

extension ProbeReport: TextRenderable {

    internal func renderText() -> String {
        var lines: [String] = []
        lines.append(TextFormatter.header("CMAF init segment"))
        lines.append(TextFormatter.keyValue("major brand", majorBrand))
        lines.append(
            TextFormatter.keyValue(
                "compatible brands", TextFormatter.list(compatibleBrands)
            )
        )
        lines.append(TextFormatter.keyValue("movie timescale", "\(movieTimescale)"))
        lines.append(TextFormatter.keyValue("track count", "\(trackCount)"))
        for track in tracks {
            lines.append("")
            lines.append(TextFormatter.header("track \(track.trackID)"))
            lines.append(TextFormatter.keyValue("  kind", track.kind))
            lines.append(TextFormatter.keyValue("  codec", track.codec))
            lines.append(TextFormatter.keyValue("  language", track.language))
            lines.append(TextFormatter.keyValue("  profile", track.profile))
            lines.append(
                TextFormatter.keyValue("  encryption", track.encryption ?? "(none)")
            )
        }
        return lines.joined(separator: "\n")
    }

    internal func renderTable() -> String {
        let headers = ["trackID", "kind", "codec", "language", "profile", "encryption"]
        let rows: [[String]] = tracks.map { t in
            [
                "\(t.trackID)", t.kind, t.codec, t.language, t.profile,
                t.encryption ?? "(none)"
            ]
        }
        return TableFormatter.render(headers: headers, rows: rows)
    }
}
