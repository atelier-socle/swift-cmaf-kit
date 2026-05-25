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

## Structural box examples

### ProtectionSchemeInfoBox (`sinf`)

The `sinf` container groups the original codec fourCC, the scheme
identifier, and the scheme-specific information. A `cenc` (AES-CTR
full-sample) example:

```swift
import CMAFKit

let tenc = TrackEncryptionBox(
    version: 0,
    defaultIsProtected: true,
    defaultPerSampleIVSize: .eight,
    defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0x33, count: 16))
)
let sinf = ProtectionSchemeInfoBox(
    originalFormat: OriginalFormatBox(dataFormat: "avc1"),
    schemeType: SchemeTypeBox(schemeType: .cenc),
    schemeInformation: SchemeInformationBox(trackEncryption: tenc)
)
```

### TrackEncryptionBox (`tenc`) v0

`tenc` v0 carries the protection flag, the default per-sample IV
size, and the default 16-byte key identifier:

```swift
import CMAFKit

let tenc = TrackEncryptionBox(
    version: 0,
    defaultIsProtected: true,
    defaultPerSampleIVSize: .eight,
    defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0x33, count: 16))
)
// tenc.defaultIsProtected == true
// tenc.defaultPerSampleIVSize == .eight
```

### SampleEncryptionBox (`senc`)

`senc` carries the per-sample initialisation vectors (and optional
subsample partitions for tracks that mix protected and clear
regions inside a single sample):

```swift
import Foundation
import CMAFKit

let iv = Data(repeating: 0x77, count: 8)
let senc = SampleEncryptionBox(samples: [
    SampleEncryptionBox.SampleEncryptionEntry(initializationVector: iv),
    SampleEncryptionBox.SampleEncryptionEntry(initializationVector: iv)
])
// senc.samples.count == 2
```

### CBCS pattern encryption

The `cbcs` scheme (HLS FairPlay) uses CBC mode plus a 1:9 crypt-block /
skip-block pattern and a constant IV. The `tenc` carries the pattern
counts and the IV via ``ConstantIV``:

```swift
import CMAFKit

let constantIV = try ConstantIV(rawBytes: Data(repeating: 0x55, count: 16))
let cbcsTenc = TrackEncryptionBox(
    version: 1,
    defaultCryptByteBlock: 1,
    defaultSkipByteBlock: 9,
    defaultIsProtected: true,
    defaultPerSampleIVSize: .zero,
    defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0x44, count: 16)),
    defaultConstantIV: constantIV
)
let cbcsSinf = ProtectionSchemeInfoBox(
    originalFormat: OriginalFormatBox(dataFormat: "avc1"),
    schemeType: SchemeTypeBox(schemeType: .cbcs),
    schemeInformation: SchemeInformationBox(trackEncryption: cbcsTenc)
)
```

The CMAF-wide CENC conformance rules (C1–C8) live on
``CENCConformanceValidator`` — see <doc:ValidatorsHierarchy>.

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
