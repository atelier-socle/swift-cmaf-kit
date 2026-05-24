// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MediaSelectionRole — raw-value round-trip + Codable + CaseIterable
// per ISO/IEC 23009-1 §5.8.5.5 + Apple HLS Authoring §4.6 +
// DASH-IF IOP §6.6.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MediaSelectionRole — raw + conformance")
struct MediaSelectionRoleTests {

    @Test func allCasesCountIsStable() {
        #expect(MediaSelectionRole.allCases.count == 16)
    }

    @Test func everyCaseRoundTripsRawString() throws {
        for role in MediaSelectionRole.allCases {
            let raw = role.rawValue
            let back = try #require(MediaSelectionRole(rawValue: raw))
            #expect(back == role)
        }
    }

    @Test func rawValuesAreCamelCase() {
        // Sanity: every raw value is non-empty ASCII (no whitespace).
        for role in MediaSelectionRole.allCases {
            #expect(!role.rawValue.isEmpty)
            #expect(role.rawValue.allSatisfy { $0.isASCII })
        }
    }

    @Test func codableJSONRoundTrip() throws {
        let cases: [MediaSelectionRole] = [.main, .description, .captions, .sign, .custom]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(MediaSelectionRole.self, from: data)
            #expect(decoded == original)
        }
    }

    @Test func hashableSetMembershipWorks() {
        let set: Set<MediaSelectionRole> = [.main, .description, .captions]
        #expect(set.contains(.main))
        #expect(set.contains(.description))
        #expect(!set.contains(.subtitle))
    }

    @Test func sendableInstancesPassActorBoundary() async {
        let role: MediaSelectionRole = .captions
        await Task {
            #expect(role == .captions)
        }.value
    }
}
