# Audio codecs in CMAFKit

CMAFKit's audio surface spans AAC, AC-3, E-AC-3 (with Dolby Atmos
JOC), AC-4, MPEG-H 3D Audio, Opus, FLAC, Apple Lossless (ALAC), and
the CMAF uncompressed-audio profile (`ipcm` / `fpcm` / `lpcm`). This
article focuses on the 0.1.1 additions: typed E-AC-3 JOC signalling,
ALAC, and the three PCM forms.

## E-AC-3 with Dolby Atmos JOC

ETSI TS 102 366 Annex H defines the Joint Object Coding extension
that carries Dolby Atmos bed-and-objects data inside E-AC-3
dependent substreams. The presence and complexity index are
signalled by the `ec3_extension_type_a` byte in the `dec3` trailer
per Annex F.6.

CMAFKit 0.1.1 adds a typed accessor on the existing
``EC3SpecificBox`` (the 0.1.0 box is unchanged):

- ``EC3JOCExtension`` — 5-case typed enum (`.none`,
  `.objectBased(complexityIndex:)`, `.channelBased(complexityIndex:)`,
  `.bedAndObjects(complexityIndex:)`,
  `.programmaticExtension(rawBytes:)`).
- ``EC3SpecificBox/jocExtension`` — derives the typed value from the
  existing `ec3ExtensionTypeA: UInt8?` field; a non-zero low-5-bit
  complexity yields `.bedAndObjects(complexityIndex:)` with the
  Apple canonical value being 16 (the value reflected in the HLS
  `CHANNELS="16/JOC"` attribute per Apple HLS Authoring §2.2.4).
- ``EC3SpecificBox/carriesDolbyAtmos`` — convenience flag equivalent
  to `jocExtension.isPresent`.

The RFC 6381 codec string remains `"ec-3"` — JOC is out-of-stream
signalling. The ``RFC6381CodecStringBuilder`` reads
`carriesDolbyAtmos` to set the `joc: Bool` on the descriptor. See
<doc:CodecStringReference>.

## Apple Lossless (ALAC)

The Apple ALAC public specification (open-sourced 2011) defines a
24-byte `ALACSpecificConfig` magic cookie that lives inside the
`alac` child box of an ALAC sample entry. CMAFKit ships:

- ``ALACSpecificBox`` — typed wrapper for the magic cookie
  (`frameLength`, `compatibleVersion=0`, `bitDepth ∈ {16,20,24,32}`,
  `pb=40`, `mb=10`, `kb=14`, `numChannels ∈ 1..8`, `maxRun`,
  `maxFrameBytes`, `avgBitRate`, `sampleRate`). The
  ``ALACSpecificBox/validate()`` helper enforces the spec
  constraints (bit depth set, channel count range, compatible
  version is zero, sample rate non-zero) and ``ALACSpecificBoxError``
  carries the typed rejection reasons.
- ``ALACSampleEntry`` — the `alac` sample entry box combining the
  standard ``AudioSampleEntryFields`` + the magic cookie + the
  ``AudioSampleEntryExtensions`` (`chnl` / `srat` / `btrt`).

### fourCC collision resolution

The `alac` fourCC is shared by the sample entry AND its child
magic-cookie box. CMAFKit resolves the collision by NOT registering
``ALACSpecificBox`` at the global ``BoxRegistry`` level —
``ALACSampleEntry/parse(reader:header:registry:)`` reads the inner
`alac` child manually, mirroring the FLACSampleEntry / `dfLa`
pattern adapted for same-fourCC ALAC.

## CMAF uncompressed PCM

ISO/IEC 23003-5 §4 defines two CMAF uncompressed audio sample
entries that share the ``PCMConfigurationBox`` (`pcmC`) child:

- ``IntegerPCMSampleEntry`` (`ipcm`) — bit depths 8 / 16 / 24 / 32.
- ``FloatingPointPCMSampleEntry`` (`fpcm`) — IEEE 754 binary32 / 64.

Both use the version 0 ``AudioSampleEntryFields`` with the `pcmC`
child carrying endianness (`format_flags` bit 0: 0 = big, 1 =
little) and the PCM sample size. The
``PCMConfigurationBox/validate(codecKind:)`` helper enforces the
per-codec bit-depth constraints — rejects 64-bit on integer entries,
rejects 16-bit on float entries (IEEE 754 binary16 is not a
CMAF-standard form).

``LegacyPCMSampleEntry`` (`lpcm`) per ISO/IEC 14496-12 §12.2.3 +
§12.2.3.2 uses the version 1 ``AudioSampleEntryFields`` with the
QuickTime-legacy V1 fields inline (`outChannelCount`,
`outSampleSize`, `outSampleRate`, `constBytesPerAudioSample`,
`samplesPerFrame`). No separate config box.

> Out of scope for 0.1.1: `sowt` (signed-int 16-bit little-endian)
> and `twos` (signed-int 16-bit big-endian) — QuickTime-only legacy
> fourCC variants. ``LegacyPCMSampleEntry`` (`lpcm`) covers all
> bit-depths uniformly.

## CMAF brands `cup1` / `cup2`

Per CMAF (ISO/IEC 23000-19) §7.5.2, the CMAF uncompressed-audio
profile carries the compatibility brand `cup1` (for `ipcm` / `fpcm`)
or `cup2` (for `lpcm`). CMAFKit emits these brands in `ftyp` / `styp`
via the existing brand composer when an uncompressed audio track is
declared.

## Standards covered (0.1.1 additions)

- **ETSI TS 102 366 V1.4.1 Annex F.6** — `dec3` trailer byte
- **ETSI TS 102 366 V1.4.1 Annex H** — JOC syntax + complexity
- **DASH-IF Implementation Guidelines v5.0+ §6.3.4** — Atmos DASH
- **Apple HLS Authoring §2.2.4** — Atmos / EC-3 with JOC delivery
- **Apple ALAC public specification** — 24-byte `ALACSpecificConfig`
- **ISO/IEC 14496-12 §12.2** — AudioSampleEntry parent (v0)
- **ISO/IEC 14496-12 §12.2.3 + §12.2.3.2** — V1 audio sample entry
  used by `lpcm`
- **ISO/IEC 23003-5 §4** — `ipcm` / `fpcm` sample entries
- **ISO/IEC 23003-5 §5** — `PCMConfigurationBox` (`pcmC`)
- **CMAF (ISO/IEC 23000-19) §7.5.2** — uncompressed audio profile +
  `cup1` / `cup2` brands
- **DASH-IF Implementation Guidelines v5.0+ §6.3.7** — DASH
  uncompressed audio bindings

## See also

- <doc:CodecStringReference>
- <doc:AccessibilityReference>
- ``EC3JOCExtension``
- ``EC3SpecificBox``
- ``ALACSampleEntry``
- ``ALACSpecificBox``
- ``ALACSpecificBoxError``
- ``PCMConfigurationBox``
- ``PCMSampleCodecKind``
- ``IntegerPCMSampleEntry``
- ``FloatingPointPCMSampleEntry``
- ``LegacyPCMSampleEntry``
