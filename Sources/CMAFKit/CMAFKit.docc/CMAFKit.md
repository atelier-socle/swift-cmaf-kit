# ``CMAFKit``

A pure-Swift implementation of the Common Media Application Format
(ISO/IEC 23000-19) plus the underlying ISO BMFF box hierarchy.

## Overview

CMAFKit is a complete reader and writer for fragmented MP4 media
segments conformant to ISO/IEC 23000-19, ISO/IEC 14496-12, and the
DASH ISO BMFF profile (ISO/IEC 23009-1 §6.3). It supports the full
CMAF profile matrix (`cmfc`, `cmf2`, `cmff`, `cmfl`, `cmfs`,
`cmfd`, `cmfh`), all four Common Encryption schemes
(`cenc` / `cbc1` / `cens` / `cbcs`), HDR formats (HDR10, HDR10+,
HLG, Dolby Vision Profiles 5/7/8.x/10), every major codec
(AVC, HEVC, AV1, VP8/VP9, AAC, AC-3, E-AC-3, AC-4, Opus, FLAC,
MPEG-H 3D Audio), subtitle tracks (WebVTT, IMSC1 text + image),
metadata tracks (ID3, KLV, URIs), closed captions
(CEA-608, CEA-708 in-band SEI extraction), and Low-Latency HLS
partial chunks per IETF RFC 8216bis-15 §B.

CMAFKit reads, writes, validates, and surfaces typed metadata.
It does not encode, decode, transport bytes over the network,
fetch DRM licences, or generate playlists. Those are the
responsibilities of sibling libraries in the Atelier Socle
streaming ecosystem.

## Topics

### Getting started

- <doc:GettingStarted>
- <doc:Architecture>
- <doc:Ecosystem>

### Writing CMAF content

- ``CMAFInitSegmentWriter``
- ``CMAFMediaSegmentWriter``
- ``CMAFFragmentSegment``
- ``CMAFPartialChunk``
- <doc:WritingCMAFContent>
- <doc:FragmentBoundaries>

### Reading CMAF content

- ``CMAFInitSegmentReader``
- ``CMAFMediaSegmentReader``
- ``CMAFParsedSample``
- ``ParsedInitSegment``
- ``ParsedMediaSegment``
- <doc:ReadingCMAFContent>

### Conformance validators

- ``CMAFConformanceValidator``
- ``DASHConformanceValidator``
- ``LLHLSConformanceValidator``
- ``ISOConformanceValidator``
- ``CENCConformanceValidator``
- ``CMAFValidationReport``
- ``CMAFValidationIssue``
- <doc:ConformanceValidators>
- <doc:ValidatorsHierarchy>

### Encryption

- ``CommonEncryptionScheme``
- ``CMAFEncryptionParameters``
- ``ProtectionSchemeInfoBox``
- ``TrackEncryptionBox``
- ``ProtectionSystemSpecificHeaderBox``
- <doc:EncryptionSupport>

### Closed captions

- ``ClosedCaptionData``
- ``CEA608ByteData``
- ``DTVCCPacket``
- ``DTVCCServiceBlock``
- ``CCService``
- ``ClosedCaptionExtractor``
- <doc:ClosedCaptions>

### Multi-view HEVC and Apple Vision Pro

- ``HEVCParameterSets``
- ``HEVCVPSExtension``
- ``HEVCMultiLayerSPS``
- ``MultiLayerHEVCConfiguration``
- ``MVHEVCSampleEntry``
- ``MVHEVCPackager``
- ``ViewExtendedUsageBox``
- ``StereoInformationBox``
- ``HeroEyeInformationBox``
- <doc:MVHEVCGuide>

### Codec strings (RFC 6381)

- ``RFC6381CodecDescriptor``
- ``RFC6381CodecStringBuilder``
- <doc:CodecStringReference>

### Language tags (BCP 47)

- ``BCP47LanguageTag``
- ``PrimarySubtag``
- ``ISO15924Script``
- ``Region``
- ``BCP47Extension``
- ``IANALanguageSubtagRegistry``
- ``BCP47Error``
- <doc:LanguageTagsReference>

### Accessibility primitives (HLS / DASH cross-format)

- ``MediaSelectionRole``
- ``AccessibilityFeature``
- ``AccessibilityCharacteristic``
- ``AudioPurpose``
- ``AccessibilityMetadata``
- ``AccessibilityError``
- <doc:AccessibilityReference>

### Audio codecs (Atmos / ALAC / PCM)

- ``EC3JOCExtension``
- ``ALACSampleEntry``
- ``ALACSpecificBox``
- ``PCMConfigurationBox``
- ``PCMSampleCodecKind``
- ``IntegerPCMSampleEntry``
- ``FloatingPointPCMSampleEntry``
- ``LegacyPCMSampleEntry``
- <doc:AudioCodecsReference>

### Accessibility & standards

- <doc:AccessibilityAndStandards>
- <doc:StandardsReference>
