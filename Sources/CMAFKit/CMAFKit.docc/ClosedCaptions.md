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

## Lower-level SEI payload decode

``ClosedCaptionDecoder/decode(seiPayload:)`` is the stateless static
that the ``ClosedCaptionExtractor`` actor wraps. It recognises the
ATSC A/72 `GA94` user-data signature and yields a typed
``ClosedCaptionData`` value, or `nil` for any other payload shape.

Decoding a CEA-608 byte pair carried in an SEI payload:

```swift
import Foundation
import CMAFKit

let payload = Data([
    0xB5, 0x00, 0x31,           // ATSC A/72 itu_t_t35
    0x47, 0x41, 0x39, 0x34,     // "GA94"
    0x03, 0x81, 0xFF,           // CEA-608, 1 pair, marker
    0xFC, 0x41, 0x42            // field 1, byte 0x41 0x42
])
let decoded = ClosedCaptionDecoder.decode(seiPayload: payload)
// .cea608([CEA608ByteData(field: .field1, byte1: 0x41, byte2: 0x42)])
```

The CEA-708 path unwraps the DTVCC packet into typed
``DTVCCServiceBlock`` instances keyed by ``CCService``:

```swift
import Foundation
import CMAFKit

let payload = Data([
    0xB5, 0x00, 0x31,
    0x47, 0x41, 0x39, 0x34,
    0x03, 0x84, 0xFF,
    0xFE, 0x03, 0x24,           // DTVCC packet header + length
    0xFF, 0x41, 0x42,
    0xFF, 0x43, 0x44,
    0xFF, 0x00, 0xFF            // padding
])
let decoded = ClosedCaptionDecoder.decode(seiPayload: payload)
// .cea708(DTVCCPacket(sequenceNumber: 0, services: [
//     DTVCCServiceBlock(serviceNumber: .service1, serviceData: Data([0x41, 0x42, 0x43, 0x44]))
// ]))
```

## SEI `closedCaptions` convenience

Both ``AVCSEIMessage`` and ``HEVCSEIMessage`` expose a typed
``AVCSEIMessage/closedCaptions`` computed property that decodes
payload-type-4 messages in one step:

```swift
import Foundation
import CMAFKit

let message = AVCSEIMessage(
    payloadType: 4,
    payloadSize: 13,
    payload: Data([
        0xB5, 0x00, 0x31,
        0x47, 0x41, 0x39, 0x34,
        0x03, 0x81, 0xFF,
        0xFC, 0x41, 0x42
    ])
)
let captions = message.closedCaptions  // ClosedCaptionData?
```

## Out-of-band sample entries

The ``CEA708SampleEntry`` (`c708`) and ``CEA608SampleEntry`` (`c608`)
carry caption tracks that live outside the video bitstream. The 708
entry enumerates which ``CCService`` channels it carries:

```swift
import CMAFKit

let entry = CEA708SampleEntry(
    services: [.service1, .service2, .service63]
)
// entry.services == [.service1, .service2, .service63]
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
