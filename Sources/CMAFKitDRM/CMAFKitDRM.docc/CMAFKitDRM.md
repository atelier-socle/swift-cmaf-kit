# ``CMAFKitDRM``

Typed DRM init-data decoding for the nine publicly-registered
Common Encryption system identifiers, layered on top of
CMAFKit.

## Overview

`CMAFKitDRM` is an opt-in companion target that lifts the
opaque `pssh.data` bytes carried by ``CMAFKit/ProtectionSystemSpecificHeaderBox``
into provider-specific typed shapes. Four of the nine providers
publish a wire-format specification that CMAFKitDRM parses
fully (Widevine, PlayReady, FairPlay, ClearKey); the fifth
(Marlin) is partially documented and CMAFKitDRM types the
publicly-known portion (BBA URN); the remaining three
providers without a public specification (Nagra, Verimatrix,
Adobe Primetime) ship as byte-perfect opaque wrappers with the
closed-spec / deprecated-service status documented in the
file header of each type.

CMAFKitDRM never handles decryption keys or content. It only
decodes the typed `pssh.data` shape so consumers can route,
inspect, and forward the init data without losing any field.

## Topics

### Getting started

- <doc:GettingStartedWithDRM>
- <doc:KnownDRMSystems>

### Major providers (fully typed)

- ``WidevineInitData``
- ``PlayReadyInitData``
- ``FairPlayInitData``
- ``ClearKeyInitData``
- <doc:WidevineSupport>
- <doc:PlayReadySupport>
- <doc:FairPlayAndClearKey>

### Secondary providers

- ``MarlinInitData``
- ``ChinaDRMInitData``
- ``NagraInitData``
- ``VerimatrixInitData``
- ``AdobePrimetimeInitData``
- <doc:ClosedSpecProviders>

### Common types

- ``KnownDRMSystemID``
- ``DRMInitDataParsing``
- ``DRMSystemError``
- ``TypedDRMInitData``
