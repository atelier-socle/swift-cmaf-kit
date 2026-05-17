// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EncodedFrame
//
// A single encoded media sample, container-ready (length-prefixed for AVC/HEVC,
// raw for AAC, OBU stream for AV1, syncframe for AC-3 / E-AC-3, etc.).

import Foundation

/// A single encoded media sample.
public struct EncodedFrame: Sendable {
    /// Codec that produced this sample.
    public let codec: EncodedCodec

    /// Container-ready bytes (length-prefixed for AVC/HEVC, raw for AAC, OBU
    /// stream for AV1, syncframe for AC-3/E-AC-3, frame for Opus/FLAC).
    public let data: Data

    /// `true` if this sample is a keyframe (IDR for AVC/HEVC, key frame for AV1).
    public let isKeyframe: Bool

    /// Decoding timestamp.
    public let decodingTime: MediaTimestamp

    /// Presentation timestamp (may differ from decoding time due to B-frames).
    public let presentationTime: MediaTimestamp

    /// Duration of this sample.
    public let duration: MediaTimestamp

    /// Optional sample dependency information (sdtp data).
    public let dependencyInfo: SampleDependencyInfo?

    /// Optional HDR metadata attached to this sample.
    public let hdrMetadata: HDRMetadata?

    public init(
        codec: EncodedCodec,
        data: Data,
        isKeyframe: Bool,
        decodingTime: MediaTimestamp,
        presentationTime: MediaTimestamp,
        duration: MediaTimestamp,
        dependencyInfo: SampleDependencyInfo? = nil,
        hdrMetadata: HDRMetadata? = nil
    ) {
        self.codec = codec
        self.data = data
        self.isKeyframe = isKeyframe
        self.decodingTime = decodingTime
        self.presentationTime = presentationTime
        self.duration = duration
        self.dependencyInfo = dependencyInfo
        self.hdrMetadata = hdrMetadata
    }
}
