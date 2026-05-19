// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AV1OperatingPoint
//
// Reference: AOMedia AV1 Bitstream §5.5.1 (operating points loop).

import Foundation

/// One AV1 operating point entry from the sequence header OBU.
public struct AV1OperatingPoint: Sendable, Hashable, Equatable {
    public let operatingPointIDC: UInt16
    public let seqLevelIDX: AV1Level
    /// Present iff `seqLevelIDX.rawValue > 7`.
    public let seqTier: AV1Tier?
    /// Per-OP decoder-model parameters per AOMedia AV1 §5.5.3. Present
    /// iff the sequence header's `decoder_model_info_present_flag == 1`
    /// AND this operating point's `decoder_model_present_for_this_op == 1`.
    public let operatingParametersInfo: AV1OperatingParametersInfo?
    /// Initial display delay value
    /// (`initial_display_delay_present_flag`-gated).
    public let initialDisplayDelayMinus1: UInt8?

    public init(
        operatingPointIDC: UInt16,
        seqLevelIDX: AV1Level,
        seqTier: AV1Tier? = nil,
        operatingParametersInfo: AV1OperatingParametersInfo? = nil,
        initialDisplayDelayMinus1: UInt8? = nil
    ) {
        precondition(operatingPointIDC <= 0x0FFF, "operatingPointIDC must fit 12 bits")
        self.operatingPointIDC = operatingPointIDC
        self.seqLevelIDX = seqLevelIDX
        self.seqTier = seqTier
        self.operatingParametersInfo = operatingParametersInfo
        self.initialDisplayDelayMinus1 = initialDisplayDelayMinus1
    }
}
