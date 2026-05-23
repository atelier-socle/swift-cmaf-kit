# Closed-spec & deprecated-service providers

Honest treatment for Nagra, Verimatrix, and Adobe Primetime —
the three DRM systems whose `pssh.data` wire format is not
publicly documented.

## Overview

The DASH-IF "DRM System Identifiers" registry assigns UUIDs
for nine production DRM systems. Six of them publish wire-
format specifications that CMAFKitDRM decodes into typed
fields. The remaining three — **Nagra Connect**, **Verimatrix
Multi-DRM**, and **Adobe Primetime** — do not.

CMAFKitDRM ships those three as **opaque wrappers**:
``NagraInitData``, ``VerimatrixInitData``,
``AdobePrimetimeInitData``. Each carries a public
`rawBytes: Data` property containing the original `pssh.data`
bytes verbatim. The static `parse(_:)` entry point constructs
the wrapper without attempting to decode the payload; the
static `encode(_:)` entry point returns the preserved bytes
unchanged. Round-trip is byte-perfect on arbitrary input.

This is not a limitation that CMAFKitDRM will overcome in a
future release of the same library — it is an honest reflection
of the public-spec ecosystem. If and when these vendors
publish their wire format, those wrappers can be expanded with
typed accessors without breaking source compatibility
(`rawBytes` remains available as the canonical wire form).

## Why opaque is correct here

The alternative — inventing field names and offsets based on
reverse-engineering — would produce typed values that cannot
be validated against the spec, would diverge from the vendor's
actual behaviour as their format evolves, and would lull
consumers into trusting incorrect decoding. The container
layer of CMAFKit preserves these bytes byte-perfectly without
needing to interpret them; that is enough for archival,
forwarding, and routing.

## Status note per provider

- **Nagra Connect** — wire format proprietary, distributed
  under NDA to certified Nagra licensees.
- **Verimatrix Multi-DRM** — wire format proprietary,
  distributed under commercial agreement.
- **Adobe Primetime** — service discontinued by Adobe in 2020;
  the historical wire format is partially documented in
  archived Adobe specifications but is no longer maintained.

## See also

- ``NagraInitData``
- ``VerimatrixInitData``
- ``AdobePrimetimeInitData``
- <doc:KnownDRMSystems>
