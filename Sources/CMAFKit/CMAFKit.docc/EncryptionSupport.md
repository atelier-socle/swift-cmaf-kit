# Encryption support

CMAFKit's Common Encryption surface: the four CENC schemes,
the typed encryption parameter values, and the box hierarchy
the writer emits and the reader recovers.

## Overview

CMAFKit implements every scheme defined by ISO/IEC 23001-7
(Common Encryption in ISO Base Media File Format):

| Scheme | Mode | Pattern | Reference |
|---|---|---|---|
| ``CommonEncryptionScheme/cenc`` | AES-128 CTR | full sample | §10.1 |
| ``CommonEncryptionScheme/cbc1`` | AES-128 CBC | full sample | §10.2 |
| ``CommonEncryptionScheme/cens`` | AES-128 CTR | block pattern | §10.3 |
| ``CommonEncryptionScheme/cbcs`` | AES-128 CBC | block pattern (HLS FairPlay) | §10.4 |

## Encryption parameters

``CMAFEncryptionParameters`` carries the configuration for one
encrypted track: scheme, default key identifier, per-sample IV
size, optional constant IV (for `cbcs` with `ivSize == 0`),
pattern block counts (`cryptByteBlock` / `skipByteBlock`), and
the `pssh` boxes attached at the moov level.

Attach an instance to ``CMAFTrackConfiguration/encryptionParameters``
and the writer:
- rewrites the sample entry to `encv` (video) or `enca` (audio)
- emits a `sinf` container with `frma` (original format), `schm`
  (scheme type), `schi` (scheme info) containing `tenc`
- emits the supplied `pssh` boxes inside the `moov`
- accepts per-sample encryption metadata via
  ``CMAFSampleInput/EncryptionMetadata`` and serialises a
  `senc` box inside each `traf`

## Per-sample encryption metadata

For each encrypted sample, supply a
``CMAFSampleInput/EncryptionMetadata`` value with:
- ``CMAFSampleInput/EncryptionMetadata/initializationVector``
  — IV bytes (8 or 16 for `cenc` / `cens`; empty for `cbcs`
  with constant IV)
- ``CMAFSampleInput/EncryptionMetadata/subsamples`` — optional
  subsample partitions per ISO/IEC 23001-7 §7.2

## Recovery on the read side

``CMAFMediaSegmentReader`` resolves each `senc` entry using the
init segment's `tenc` context. The recovered
``CMAFParsedSample/encryption`` matches the value originally
supplied to the writer.

## Topics

### Schemes
- ``CommonEncryptionScheme``

### Parameter values
- ``CMAFEncryptionParameters``
- ``KeyIdentifier``
- ``ConstantIV``

### Container boxes
- ``ProtectionSchemeInfoBox``
- ``SchemeTypeBox``
- ``TrackEncryptionBox``
- ``ProtectionSystemSpecificHeaderBox``
- ``SampleEncryptionBox``

## DRM-specific typing

The `CMAFKitDRM` opt-in target adds typed `pssh.data` decoding
for nine DRM providers (Widevine, PlayReady, FairPlay,
ClearKey, Marlin, Nagra, Verimatrix, Adobe Primetime, and
ChinaDRM).
