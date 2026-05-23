# Closed captions

In-band CEA-608 and CEA-708 caption extraction plus the typed
`c608` / `c708` sample entries for out-of-band caption tracks.

## Overview

CMAFKit ships two complementary paths for closed-caption
content:

- **In-band SEI extraction** — CEA-608 byte pairs and CEA-708
  DTVCC packets carried inside AVC / HEVC SEI
  `user_data_registered_itu_t_t35` messages with the ATSC A/72
  signature (country `0xB5`, provider `0x0031`,
  `user_identifier == "GA94"`, `user_data_type_code == 0x03`).
  The ``ClosedCaptionExtractor`` actor consumes
  ``SEIMessage`` instances and surfaces typed
  ``ClosedCaptionData`` values.
- **Out-of-band caption tracks** — typed `c608` and `c708`
  sample entries per ISO/IEC 14496-30 §11.2 / §11.3, used when
  captions live in a dedicated subtitle track rather than
  in-band.

## Typed payloads

- ``CEA608ByteData`` — one byte pair per CTA-608-E.
- ``DTVCCPacket`` + ``DTVCCServiceBlock`` — DTVCC caption-
  channel packet per CTA-708-E §6.2.
- ``CCService`` — 67-case enum carrying both CEA-608 channels
  `cc1..cc4` and CEA-708 services `service1..service63`.

## Extraction example

```swift
import CMAFKit

let extractor = ClosedCaptionExtractor()
let sei: AVCSEIMessage = /* from a parsed video sample */
let captions = await extractor.extract(from: [.avc(sei)])
for caption in captions {
    switch caption {
    case .cea608(let bytes):
        print("CEA-608: \(bytes.count) byte pair(s)")
    case .cea708(let packet):
        print("CEA-708: seq=\(packet.sequenceNumber), services=\(packet.services.count)")
    }
}
```

## Standards covered

- CTA-608-E (CEA-608 caption channels)
- CTA-708-E §6.2 (DTVCC packet layout)
- ATSC A/72 Part 3 (`cea_708` SEI carriage)
- SCTE-128 §8 (closed-caption tunneling)
- ISO/IEC 14496-30 §11.2 / §11.3 (`c608` / `c708` sample
  entries)

## See also

- ``ClosedCaptionData``
- ``ClosedCaptionExtractor``
- ``CCService``
- ``DTVCCPacket``
- ``CEA608ByteData``
- ``CEA708SampleEntry``
- ``CEA608SampleEntry``
