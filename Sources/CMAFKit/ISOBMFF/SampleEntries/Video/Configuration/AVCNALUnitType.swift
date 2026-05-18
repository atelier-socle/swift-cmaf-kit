// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCNALUnitType
//
// Reference: ISO/IEC 14496-10 §7.4.1 Table 7-1 (NAL unit type codes).

import Foundation

/// AVC NAL unit type codes per ISO/IEC 14496-10 §7.4.1 Table 7-1.
public enum AVCNALUnitType: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case unspecified0 = 0
    /// Coded slice of a non-IDR picture.
    case codedSliceNonIDR = 1
    /// Coded slice data partition A.
    case codedSliceDataPartitionA = 2
    /// Coded slice data partition B.
    case codedSliceDataPartitionB = 3
    /// Coded slice data partition C.
    case codedSliceDataPartitionC = 4
    /// Coded slice of an IDR picture.
    case codedSliceIDR = 5
    /// Supplemental enhancement information (SEI).
    case sei = 6
    /// Sequence parameter set (SPS).
    case sequenceParameterSet = 7
    /// Picture parameter set (PPS).
    case pictureParameterSet = 8
    /// Access unit delimiter.
    case accessUnitDelimiter = 9
    /// End of sequence.
    case endOfSequence = 10
    /// End of stream.
    case endOfStream = 11
    /// Filler data.
    case fillerData = 12
    /// Sequence parameter set extension.
    case sequenceParameterSetExtension = 13
    /// Prefix NAL unit.
    case prefixNALUnit = 14
    /// Subset sequence parameter set (SVC/MVC).
    case subsetSequenceParameterSet = 15
    /// Depth parameter set (3D-AVC).
    case depthParameterSet = 16
    case reserved17 = 17
    case reserved18 = 18
    /// Auxiliary coded picture without partitioning.
    case auxiliaryCodedPictureSlice = 19
    /// Coded slice extension (SVC/MVC).
    case codedSliceExtension = 20
    /// Coded slice extension for depth view (3D-AVC).
    case codedSliceDepthExtension = 21
    case reserved22 = 22
    case reserved23 = 23
    case unspecified24 = 24
    case unspecified25 = 25
    case unspecified26 = 26
    case unspecified27 = 27
    case unspecified28 = 28
    case unspecified29 = 29
    case unspecified30 = 30
    case unspecified31 = 31
}
