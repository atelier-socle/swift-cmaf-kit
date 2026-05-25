# ``CMAFKitCommands``

The `cmafkit-cli` companion executable for the CMAFKit and
CMAFKitDRM libraries — a read-only inspection and validation tool
for CMAF media segments.

## Overview

`cmafkit-cli` provides four subcommands for working with CMAF
files without writing Swift code:

- **`probe`** — print per-track metadata (codec, profile,
  encryption scheme, language, brands, movie timescale).
- **`validate`** — run the typed CMAF / DASH / LL-HLS conformance
  validator and produce a structured report.
- **`dump-tree`** — print the ISO BMFF box hierarchy with sizes
  and types, useful for debugging container structure.
- **`decrypt-init`** — parse and print typed DRM init data for
  every `pssh` box in a CMAF init segment, dispatching to the
  typed `CMAFKitDRM` provider parsers (no key material is
  handled).

Three output formats are supported across all subcommands:
`text` (human-readable, default), `json` (machine-readable
structured output), `table` (terminal-friendly tabular layout).

The CLI is read-only by default and never modifies the input
file. The `decrypt-init` subcommand parses and prints
initialisation data only — it never decrypts content.

## Exit codes

Stable exit codes per failure class (see ``CLIError``):

| Code | Class |
|------|-------|
| 0 | Success |
| 2 | Input file unreadable |
| 3 | Invalid CMAF / ISOBMFF input |
| 4 | Conformance validator reported errors |
| 5 | Unknown DRM system identifier |
| 6 | DRM provider parser failure |
| 7 | Output file already exists (use `--force` to overwrite) |

## Topics

### Root command
- ``CMAFKitCommand``

### Subcommands
- ``ProbeCommand``
- ``ValidateCommand``
- ``DumpTreeCommand``
- ``DecryptInitCommand``

### Output formats
- ``OutputFormat``
- ``JSONFormatter``
- ``TextFormatter``
- ``TableFormatter``

### Typed reports
- ``ProbeReport``
- ``ValidationReport``
- ``DumpTreeReport``
- ``DecryptInitReport``

### Errors
- ``CLIError``
- ``ValidationProfile``
