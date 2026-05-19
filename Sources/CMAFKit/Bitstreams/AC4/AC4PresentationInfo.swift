// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AC4PresentationInfo / AC4SubstreamGroup
//
// Reference: ETSI TS 103 190-1 §6.2.1.1 (ac4_presentation_v0_info) +
// §6.2.1.2 (substream_group_info) + §6.2.1.4 (ac4_substream_info) +
// §6.2.1.5 (ac4_metadata_substream_info).

import Foundation

/// One AC-4 presentation entry per ETSI TS 103 190-1 §6.2.1.1.
public struct AC4PresentationInfo: Sendable, Hashable, Equatable {
    /// 5-bit `presentation_config`.
    public let presentationConfig: UInt8
    /// 5-bit `presentation_version`.
    public let presentationVersion: UInt8
    /// `b_add_emdf_substreams` flag.
    public let addEmdfSubstreamsFlag: Bool
    /// `mdcompat` field — 3 bits.
    public let mdcompat: UInt8
    /// `presentation_group_index` — 5 bits.
    public let presentationGroupIndex: UInt8
    /// `dsi_frame_rate_multiply_info` — 2 bits.
    public let frameRateMultiplyInfo: UInt8?
    /// `dsi_frame_rate_fractions_info` — 2 bits.
    public let frameRateFractionsInfo: UInt8?
    /// Substream group descriptors referenced by this presentation.
    public let substreamGroups: [AC4SubstreamGroup]

    public init(
        presentationConfig: UInt8,
        presentationVersion: UInt8,
        addEmdfSubstreamsFlag: Bool,
        mdcompat: UInt8,
        presentationGroupIndex: UInt8,
        frameRateMultiplyInfo: UInt8? = nil,
        frameRateFractionsInfo: UInt8? = nil,
        substreamGroups: [AC4SubstreamGroup] = []
    ) {
        precondition(presentationConfig <= 0x1F, "presentationConfig must fit 5 bits")
        precondition(presentationVersion <= 0x1F, "presentationVersion must fit 5 bits")
        precondition(mdcompat <= 0x07, "mdcompat must fit 3 bits")
        precondition(presentationGroupIndex <= 0x1F, "presentationGroupIndex must fit 5 bits")
        self.presentationConfig = presentationConfig
        self.presentationVersion = presentationVersion
        self.addEmdfSubstreamsFlag = addEmdfSubstreamsFlag
        self.mdcompat = mdcompat
        self.presentationGroupIndex = presentationGroupIndex
        self.frameRateMultiplyInfo = frameRateMultiplyInfo
        self.frameRateFractionsInfo = frameRateFractionsInfo
        self.substreamGroups = substreamGroups
    }
}

/// One AC-4 substream group descriptor per ETSI TS 103 190-1 §6.2.1.2.
public struct AC4SubstreamGroup: Sendable, Hashable, Equatable {

    /// One substream entry within a substream group.
    public struct Substream: Sendable, Hashable, Equatable {
        public let codec: AC4SubstreamCodec
        /// Channel mode for audio substreams, `nil` for metadata.
        public let channelMode: AC4ChannelMode?
        /// `b_dialog_enhancement_enabled` per §6.2.1.4.
        public let dialogEnhancementEnabled: Bool

        public init(
            codec: AC4SubstreamCodec,
            channelMode: AC4ChannelMode? = nil,
            dialogEnhancementEnabled: Bool = false
        ) {
            self.codec = codec
            self.channelMode = channelMode
            self.dialogEnhancementEnabled = dialogEnhancementEnabled
        }
    }

    /// Content classifier metadata.
    public struct ContentInfo: Sendable, Hashable, Equatable {
        public let contentType: AC4ContentType
        /// Optional language tag, present iff `b_language_indicator`.
        /// Up to 63 bytes per the standard.
        public let languageTag: String?

        public init(contentType: AC4ContentType, languageTag: String? = nil) {
            self.contentType = contentType
            self.languageTag = languageTag
        }
    }

    /// Index referenced by the enclosing presentation.
    public let substreamGroupIndex: UInt8
    /// `b_substreams_present` per §6.2.1.2.
    public let substreamsPresent: Bool
    /// `b_hsf_ext` flag.
    public let hsfExtension: Bool
    /// `b_channel_coded` flag.
    public let channelCoded: Bool
    /// Number of substreams in this group.
    public let numSubstreams: UInt8
    /// One descriptor per substream.
    public let substreams: [Substream]
    /// Content classifier info, present iff `b_content_type`.
    public let contentInfo: ContentInfo?
    /// 7-bit `pres_ndot` value, present iff `b_pres_ndot`.
    public let presentationNonDot: UInt8?

    public init(
        substreamGroupIndex: UInt8,
        substreamsPresent: Bool = false,
        hsfExtension: Bool = false,
        channelCoded: Bool = true,
        numSubstreams: UInt8 = 1,
        substreams: [Substream] = [],
        contentInfo: ContentInfo? = nil,
        presentationNonDot: UInt8? = nil
    ) {
        precondition(
            presentationNonDot.map { $0 <= 0x7F } ?? true,
            "presentationNonDot must fit 7 bits")
        self.substreamGroupIndex = substreamGroupIndex
        self.substreamsPresent = substreamsPresent
        self.hsfExtension = hsfExtension
        self.channelCoded = channelCoded
        self.numSubstreams = numSubstreams
        self.substreams = substreams
        self.contentInfo = contentInfo
        self.presentationNonDot = presentationNonDot
    }
}
