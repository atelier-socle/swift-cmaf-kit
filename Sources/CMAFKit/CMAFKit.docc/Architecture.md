# Architecture

The eleven-module layered design of CMAFKit.

## Overview

CMAFKit follows a strict layered architecture. The dependency rules are documented inline in each module.
 The layers are:

- Layer 0 — BinaryIO
- Layer 1 — Media
- Layer 2 — ISOBMFF
- Layer 3 — Color, CodecSampleEntries, CodecBitstream
- Layer 4 — Encryption, Fragmentation
- Layer 5 — CMAFProfiles, Reader, Validator

> Important: this article is a stub. Session 12 expands it with diagrams and
> rationale.
