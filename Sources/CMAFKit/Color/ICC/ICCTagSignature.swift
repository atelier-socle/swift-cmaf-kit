// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCTagSignature
//
// Reference: ICC.1:2022 Annex A (registered tag signatures).
//
// Every tag standardised by ICC.1:2022 has its signature listed here.
// Encountering an unrecognised signature on the wire throws a parse
// error; CMAFKit supports every standardised tag per the complete-
// coverage guarantee of this 0.1.0 release.

import Foundation

/// Tag signature per ICC.1:2022 Annex A.
public enum ICCTagSignature: UInt32, Sendable, Hashable, CaseIterable, Codable {
    /// AToB0 ('A2B0').
    case aToB0 = 0x4132_4230
    /// AToB1 ('A2B1').
    case aToB1 = 0x4132_4231
    /// AToB2 ('A2B2').
    case aToB2 = 0x4132_4232
    /// Blue matrix column ('bXYZ').
    case blueMatrixColumn = 0x6258_595A
    /// Blue TRC ('bTRC').
    case blueTRC = 0x6254_5243
    /// BToA0 ('B2A0').
    case bToA0 = 0x4232_4130
    /// BToA1 ('B2A1').
    case bToA1 = 0x4232_4131
    /// BToA2 ('B2A2').
    case bToA2 = 0x4232_4132
    /// BToD0 ('B2D0').
    case bToD0 = 0x4232_4430
    /// BToD1 ('B2D1').
    case bToD1 = 0x4232_4431
    /// BToD2 ('B2D2').
    case bToD2 = 0x4232_4432
    /// BToD3 ('B2D3').
    case bToD3 = 0x4232_4433
    /// Calibration date time ('calt').
    case calibrationDateTime = 0x6361_6C74
    /// Char target ('targ').
    case charTarget = 0x7461_7267
    /// Chromatic adaptation ('chad').
    case chromaticAdaptation = 0x6368_6164
    /// Chromaticity ('chrm').
    case chromaticity = 0x6368_726D
    /// Colorimetric intent image state ('ciis').
    case colorimetricIntentImageState = 0x6369_6973
    /// Colorant order ('clro').
    case colorantOrder = 0x636C_726F
    /// Colorant table ('clrt').
    case colorantTable = 0x636C_7274
    /// Colorant table out ('clot').
    case colorantTableOut = 0x636C_6F74
    /// Copyright ('cprt').
    case copyright = 0x6370_7274
    /// Device mfg desc ('dmnd').
    case deviceMfgDesc = 0x646D_6E64
    /// Device model desc ('dmdd').
    case deviceModelDesc = 0x646D_6464
    /// DToB0 ('D2B0').
    case dToB0 = 0x4432_4230
    /// DToB1 ('D2B1').
    case dToB1 = 0x4432_4231
    /// DToB2 ('D2B2').
    case dToB2 = 0x4432_4232
    /// DToB3 ('D2B3').
    case dToB3 = 0x4432_4233
    /// Gamut ('gamt').
    case gamut = 0x6761_6D74
    /// Gray TRC ('kTRC').
    case grayTRC = 0x6B54_5243
    /// Green matrix column ('gXYZ').
    case greenMatrixColumn = 0x6758_595A
    /// Green TRC ('gTRC').
    case greenTRC = 0x6754_5243
    /// Luminance ('lumi').
    case luminance = 0x6C75_6D69
    /// Measurement ('meas').
    case measurement = 0x6D65_6173
    /// Media white point ('wtpt').
    case mediaWhitePoint = 0x7774_7074
    /// Named color 2 ('ncl2').
    case namedColor2 = 0x6E63_6C32
    /// Output response ('resp').
    case outputResponse = 0x7265_7370
    /// Perceptual rendering intent gamut ('rig0').
    case perceptualRenderingIntentGamut = 0x7269_6730
    /// Preview 0 ('pre0').
    case preview0 = 0x7072_6530
    /// Preview 1 ('pre1').
    case preview1 = 0x7072_6531
    /// Preview 2 ('pre2').
    case preview2 = 0x7072_6532
    /// Profile description ('desc').
    case profileDescription = 0x6465_7363
    /// Profile sequence desc ('pseq').
    case profileSequenceDesc = 0x7073_6571
    /// Profile sequence identifier ('psid').
    case profileSequenceIdentifier = 0x7073_6964
    /// Red matrix column ('rXYZ').
    case redMatrixColumn = 0x7258_595A
    /// Red TRC ('rTRC').
    case redTRC = 0x7254_5243
    /// Saturation rendering intent gamut ('rig2').
    case saturationRenderingIntentGamut = 0x7269_6732
    /// Technology ('tech').
    case technology = 0x7465_6368
    /// Viewing cond desc ('vued').
    case viewingCondDesc = 0x7675_6564
    /// Viewing conditions ('view').
    case viewingConditions = 0x7669_6577
}
