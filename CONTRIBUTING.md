# Contributing to swift-cmaf-kit

Thank you for your interest in contributing. This document explains the process and expectations.

## Standards discipline

**Standards-first.** Every implementation file that touches a box, codec, or scheme MUST name the ISO/RFC section it implements in a file-header doc comment. Every test MUST reference the section it validates. Pull requests changing standards-implementing code without a citation in the doc comment will be rejected.

When in doubt, the spec wins — never the implementer's intuition. The primary spec is `swift-cmaf-kit-spec.md`; the addendum `swift-cmaf-kit-spec-addendum-0_1_0.md` supersedes the primary spec on every conflict.

## How to Contribute

1. **Fork** the repository on GitHub
2. **Create a branch** from `main` for your changes (`feat/my-feature`, `fix/my-fix`)
3. **Make your changes** following the guidelines below
4. **Push** your branch to your fork
5. **Open a Pull Request** against `main`

## Development Setup

### Requirements

- **Swift 6.2+** (Xcode 26.2 or later)
- **macOS 14+** or **Ubuntu 22.04+**
- **SwiftLint** — `brew install swiftlint`
- **swift-format** — `brew install swift-format`

### Build and Test

```bash
# Build
swift build

# Run all tests
swift test

# Run tests with coverage
swift test --enable-code-coverage
```

### Lint

The CI enforces linting before build. Run these locally to catch issues early:

```bash
# SwiftLint — must pass with zero violations in strict mode
swiftlint lint --strict

# swift-format — must pass with zero violations
swift-format lint -r Sources/ Tests/
```

Configuration files are included in the repository (`.swiftlint.yml` and `.swift-format`).

## Code Style

- **4 spaces** indentation, **150 character** max line width
- Explicit access control on all public API (`public`, `package` for cross-module internal)
- Prefer `struct` over `class`
- `///` doc comments on all public API with `Parameters`, `Returns`, and `Throws` sections
- No force unwraps (`!`), no `try!`, no `as!`, no `fatalError(`
- No `@preconcurrency` imports, no `nonisolated(unsafe)`, no `Task.detached`
- All public types must be `Sendable`
- SPDX header on every `.swift` file:
  ```swift
  // SPDX-License-Identifier: Apache-2.0
  // Copyright 2026 Atelier Socle SAS
  ```

## Testing Requirements

- All tests must pass: `swift test` with zero failures
- Code coverage must not decrease — new code should include tests (target ≥ 97 %)
- Use **Swift Testing** (`import Testing`) for all new tests, not XCTest
- Test files go in `Tests/CMAFKitTests/`
- Use `#expect` and `#require` for assertions

## Adding a new ISOBMFF box, codec sample entry, or codec parser

1. Locate the relevant section in `swift-cmaf-kit-spec.md` and the addendum.
2. Place the new file in the correct module folder (per the spec §7 layer rules).
3. Add a file-header doc comment naming the ISO/RFC section being implemented.
4. Implement the round-trip contract: `parse(encode(value)) == value` byte-for-byte.
5. Write round-trip tests in `Tests/CMAFKitTests/<Module>Tests/`. Minimum 3 tests:
   - Round-trip equality
   - Error on truncated input
   - Error on invalid FourCC / structural mismatch
6. Run `swift test` and `swift test --enable-code-coverage`; new code must hit ≥ 97 % coverage.

## Building documentation

CMAFKit ships two DocC catalogs: one for the library (`Sources/CMAFKit/CMAFKit.docc/`) and one for the CLI (`Sources/CMAFKitCLI/CMAFKitCLI.docc/`). The script `Scripts/generate-docs.sh` generates per-target `.doccarchive` bundles and merges them into a single `swift-cmaf-kit.doccarchive` for GitHub Pages deployment:

```bash
./Scripts/generate-docs.sh
# Output: ./docs/swift-cmaf-kit.doccarchive
```

The merge step requires `xcrun docc merge` (macOS only); Linux CI generates the per-target archives but skips the merge.

## Pull Request Guidelines

- **Clear title** describing the change (e.g., "Add Opus sample entry parser")
- **Description** explaining what changed and why, with a citation of the relevant ISO/RFC section if applicable
- **Tests** for new features and bug fixes
- **One concern per PR** — avoid mixing unrelated changes
- PRs must pass CI (lint + build + test on macOS + Linux + Apple platform simulators)
- Follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `perf:`, `chore:`

## Reporting Issues

Open an issue on GitHub with:

- A clear, descriptive title
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- Swift version and platform
- Minimal code sample or media file if applicable

## Project Structure

- `Sources/CMAFKit/` — core library (11 layered modules: BinaryIO, Media, ISOBMFF, Color, CodecSampleEntries, CodecBitstream, Encryption, Fragmentation, CMAFProfiles, Reader, Validator)
- `Sources/CMAFKitCLI/` — command-line tool (`cmafkit-cli` binary, built with swift-argument-parser)
- `Tests/CMAFKitTests/` — unit, integration, and showcase tests
- `Tests/CMAFKitTests/Fixtures/` — license-cleared test media files (with `.provenance.md` sidecars)

## License

By contributing to this project, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
