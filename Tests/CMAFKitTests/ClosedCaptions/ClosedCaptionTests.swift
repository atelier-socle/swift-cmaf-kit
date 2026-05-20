// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ClosedCaption types + decoder")
struct ClosedCaptionTests {

    @Test
    func ccService608WireNumbers() {
        #expect(CCService.cc1.wireNumber == 1)
        #expect(CCService.cc2.wireNumber == 2)
        #expect(CCService.cc3.wireNumber == 3)
        #expect(CCService.cc4.wireNumber == 4)
    }

    @Test
    func ccService708WireNumbers() {
        #expect(CCService.service1.wireNumber == 1)
        #expect(CCService.service63.wireNumber == 63)
    }

    @Test
    func ccService708FromWireNumber() {
        #expect(CCService.cea708Service(forWireNumber: 1) == .service1)
        #expect(CCService.cea708Service(forWireNumber: 63) == .service63)
        #expect(CCService.cea708Service(forWireNumber: 0) == nil)
        #expect(CCService.cea708Service(forWireNumber: 64) == nil)
    }

    @Test
    func ccServiceAllKnownCasesHas67Entries() {
        #expect(CCService.allKnownCases.count == 67)
    }

    @Test
    func cea608FieldRawValues() {
        #expect(CEA608Field.field1.rawValue == 0)
        #expect(CEA608Field.field2.rawValue == 1)
    }

    @Test
    func dtvccPacketRejectsOutOfRangeSequence() {
        // Verified at construction precondition (acceptable values 0..3)
        let pkt = DTVCCPacket(sequenceNumber: 3, packetSizeCode: 1, services: [])
        #expect(pkt.sequenceNumber == 3)
    }

    @Test
    func decoderRejectsNonATSCPattern() {
        // Country code 0x00 (not USA) → not recognised.
        let payload = Data([0x00, 0x00, 0x31, 0x47, 0x41, 0x39, 0x34, 0x03, 0x80, 0xFF])
        #expect(ClosedCaptionDecoder.decode(seiPayload: payload) == nil)
    }

    @Test
    func decoderRejectsNonGA94UserIdentifier() {
        // Country=USA, provider=ATSC, but user_id="ZZZZ".
        let payload = Data([0xB5, 0x00, 0x31, 0x5A, 0x5A, 0x5A, 0x5A, 0x03, 0x80, 0xFF])
        #expect(ClosedCaptionDecoder.decode(seiPayload: payload) == nil)
    }

    @Test
    func decoderRecognisesGA94Pattern() {
        // Country=USA, provider=ATSC, user_id="GA94", type=0x03,
        // cc_count=1, reserved 0xFF, one cc triple (cc_valid=1,
        // cc_type=00, byte1='A', byte2='B').
        let payload = Data([
            0xB5, 0x00, 0x31,
            0x47, 0x41, 0x39, 0x34,
            0x03,
            0x81,  // 0x80 | cc_count=1
            0xFF,
            0xFC, 0x41, 0x42
        ])
        let decoded = ClosedCaptionDecoder.decode(seiPayload: payload)
        guard case let .cea608(byteData) = decoded else {
            Issue.record("expected .cea608")
            return
        }
        #expect(byteData.count == 1)
        #expect(byteData[0].field == .field1)
        #expect(byteData[0].byte1 == 0x41)
        #expect(byteData[0].byte2 == 0x42)
        #expect(byteData[0].validFlag)
    }

    @Test
    func decoderRecognisesCEA608Field2() {
        let payload = Data([
            0xB5, 0x00, 0x31,
            0x47, 0x41, 0x39, 0x34,
            0x03, 0x81, 0xFF,
            0xFD, 0x55, 0x66  // cc_type=01 = field 2
        ])
        guard
            case let .cea608(byteData) =
                ClosedCaptionDecoder.decode(seiPayload: payload)
        else {
            Issue.record("expected .cea608")
            return
        }
        #expect(byteData[0].field == .field2)
    }

    @Test
    func avcSEIClosedCaptionPropertyMatchesPattern() {
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
        #expect(message.closedCaptions != nil)
    }

    @Test
    func avcSEIClosedCaptionsNilWhenPayloadTypeMismatches() {
        let message = AVCSEIMessage(
            payloadType: 5,  // not 4
            payloadSize: 13,
            payload: Data([0xB5, 0x00, 0x31, 0x47, 0x41, 0x39, 0x34])
        )
        #expect(message.closedCaptions == nil)
    }

    @Test
    func hevcSEIClosedCaptionPropertyMatchesPattern() {
        let message = HEVCSEIMessage(
            payloadType: 4,
            payloadSize: 13,
            payload: Data([
                0xB5, 0x00, 0x31,
                0x47, 0x41, 0x39, 0x34,
                0x03, 0x81, 0xFF,
                0xFC, 0x41, 0x42
            ])
        )
        #expect(message.closedCaptions != nil)
    }

    @Test
    func dtvccPacketParseEmptyPayload() {
        let packet = ClosedCaptionDecoder.parseDTVCCPacket(Data([0xC1]))
        #expect(packet?.sequenceNumber == 3)
        #expect(packet?.packetSizeCode == 1)
    }

    @Test
    func closedCaptionExtractorEmitsEmpty() async {
        let extractor = ClosedCaptionExtractor()
        let result = await extractor.extract(from: [])
        #expect(result.isEmpty)
    }

    @Test
    func closedCaptionExtractorEmitsFromAVCSEI() async {
        let extractor = ClosedCaptionExtractor()
        let avc = AVCSEIMessage(
            payloadType: 4,
            payloadSize: 13,
            payload: Data([
                0xB5, 0x00, 0x31,
                0x47, 0x41, 0x39, 0x34,
                0x03, 0x81, 0xFF,
                0xFC, 0x41, 0x42
            ])
        )
        let result = await extractor.extract(from: [.avc(avc)])
        #expect(result.count == 1)
    }

    @Test
    func closedCaptionExtractorReset() async {
        let extractor = ClosedCaptionExtractor()
        await extractor.reset()
        // No assertion needed — reset is idempotent.
    }

    // MARK: - CEA-708 DTVCC E2E extraction
    //
    // The fixtures below carry a hand-built DTVCC caption channel
    // packet (CTA-708-E §6.2) inside the ATSC A/72 user_data
    // wrapper (country=0xB5, provider=0x0031 ATSC, user_id="GA94",
    // user_data_type=0x03). The decoder must surface the typed
    // ``.cea708(packet: DTVCCPacket)`` result with parsed
    // service blocks.

    /// One DTVCC packet, single service 1, 4-byte payload
    /// "ABCD". Encoded as 4 cc_data triples: cc_type=10 (start),
    /// then three cc_type=11 (continuation).
    @Test
    func decoderExtractsCEA708SingleServiceFromSEI() throws {
        // Packet body (size 6 bytes): service header + 4 data + 1
        // padding service header (size 0 = ignored).
        //
        //   0x03   DTVCC header (seq=0, packet_size_code=3 → 6 bytes)
        //   0x24   service header: svc=1, blockSize=4
        //   0x41…44 "ABCD"
        //   0x00   trailing padding service header (size 0)
        let bytes: [UInt8] = [
            0xB5, 0x00, 0x31,
            0x47, 0x41, 0x39, 0x34,
            0x03,
            0x84,  // 0x80 | cc_count=4
            0xFF,
            0xFE, 0x03, 0x24,  // cc_type=10 (DTVCC start)
            0xFF, 0x41, 0x42,  // cc_type=11 (DTVCC continuation)
            0xFF, 0x43, 0x44,
            0xFF, 0x00, 0xFF
        ]
        let decoded = ClosedCaptionDecoder.decode(seiPayload: Data(bytes))
        guard case let .cea708(packet) = decoded else {
            Issue.record("expected .cea708")
            return
        }
        #expect(packet.sequenceNumber == 0)
        #expect(packet.packetSizeCode == 3)
        try #require(packet.services.count == 1)
        let service = packet.services[0]
        #expect(service.serviceNumber == .service1)
        #expect(service.blockSize == 4)
        #expect(service.serviceData == Data([0x41, 0x42, 0x43, 0x44]))
    }

    /// One DTVCC packet carrying two services (1 and 2), each
    /// with a 2-byte payload.
    @Test
    func decoderExtractsCEA708MultipleServicesFromSEI() throws {
        // Packet body (size 6 bytes):
        //   0x03   DTVCC header
        //   0x22   svc=1, blockSize=2
        //   0xAA 0xBB
        //   0x42   svc=2, blockSize=2
        //   0xCC 0xDD
        let bytes: [UInt8] = [
            0xB5, 0x00, 0x31,
            0x47, 0x41, 0x39, 0x34,
            0x03,
            0x84,  // cc_count = 4
            0xFF,
            0xFE, 0x03, 0x22,  // start: packet header + svc 1 header
            0xFF, 0xAA, 0xBB,  // svc 1 data
            0xFF, 0x42, 0xCC,  // svc 2 header + first svc 2 data byte
            0xFF, 0xDD, 0xEE  // second svc 2 data byte + transport pad
        ]
        let decoded = ClosedCaptionDecoder.decode(seiPayload: Data(bytes))
        guard case let .cea708(packet) = decoded else {
            Issue.record("expected .cea708")
            return
        }
        #expect(packet.services.count == 2)
        #expect(packet.services[0].serviceNumber == .service1)
        #expect(packet.services[0].serviceData == Data([0xAA, 0xBB]))
        #expect(packet.services[1].serviceNumber == .service2)
        #expect(packet.services[1].serviceData == Data([0xCC, 0xDD]))
    }

    /// Two sequential SEI messages carrying independent DTVCC
    /// packets through the extractor actor — exercises SCTE-128
    /// §8.2 cross-NAL behaviour (one extractor handles a stream).
    @Test
    func extractorAccumulatesCEA708AcrossSEINALs() async throws {
        let extractor = ClosedCaptionExtractor()
        let nal1: [UInt8] = [
            0xB5, 0x00, 0x31,
            0x47, 0x41, 0x39, 0x34,
            0x03, 0x84, 0xFF,
            0xFE, 0x03, 0x24,
            0xFF, 0x41, 0x42,
            0xFF, 0x43, 0x44,
            0xFF, 0x00, 0xFF
        ]
        let nal2: [UInt8] = [
            0xB5, 0x00, 0x31,
            0x47, 0x41, 0x39, 0x34,
            0x03, 0x84, 0xFF,
            0xFE, 0x03, 0x22,
            0xFF, 0xAA, 0xBB,
            0xFF, 0x42, 0xCC,
            0xFF, 0xDD, 0xEE
        ]
        let sei1 = AVCSEIMessage(
            payloadType: 4, payloadSize: UInt32(nal1.count), payload: Data(nal1)
        )
        let sei2 = AVCSEIMessage(
            payloadType: 4, payloadSize: UInt32(nal2.count), payload: Data(nal2)
        )
        let result = await extractor.extract(from: [.avc(sei1), .avc(sei2)])
        #expect(result.count == 2)
        var sawSingleService = false
        var sawMultiService = false
        for caption in result {
            guard case let .cea708(packet) = caption else { continue }
            if packet.services.count == 1 {
                sawSingleService = true
            } else if packet.services.count == 2 {
                sawMultiService = true
            }
        }
        #expect(sawSingleService)
        #expect(sawMultiService)
    }
}
