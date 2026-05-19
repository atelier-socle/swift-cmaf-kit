// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFEncryptionParameters
//
// Reference: ISO/IEC 23001-7 §8 (Common Encryption protection
// signalling) and §10 (the four protection schemes).
//
// One value bundles every track-level encryption parameter the
// writer needs to compose `sinf`/`schm`/`schi`/`tenc` and to emit
// `pssh` boxes at the `moov` level.

import Foundation

/// Track-level encryption configuration handed to the writer.
public struct CMAFEncryptionParameters: Sendable, Equatable, Hashable {
    /// Common Encryption scheme per ISO/IEC 23001-7 §10.
    public let scheme: CommonEncryptionScheme
    /// Default key identifier emitted in `tenc.default_KID`.
    public let defaultKID: KeyIdentifier
    /// Per-sample IV size emitted in `tenc.default_Per_Sample_IV_Size`.
    public let defaultPerSampleIVSize: TrackEncryptionBox.PerSampleIVSize
    /// Constant IV emitted in `tenc.default_constant_IV` when
    /// ``defaultPerSampleIVSize`` is ``TrackEncryptionBox/PerSampleIVSize/zero``.
    public let defaultConstantIV: ConstantIV?
    /// `default_crypt_byte_block` for pattern schemes (`cens`,`cbcs`).
    public let defaultCryptByteBlock: UInt8
    /// `default_skip_byte_block` for pattern schemes (`cens`,`cbcs`).
    public let defaultSkipByteBlock: UInt8
    /// Protection-system-specific headers emitted at the `moov`
    /// level, one entry per DRM provider (Widevine, PlayReady,
    /// FairPlay, ClearKey, ...).
    public let psshBoxes: [ProtectionSystemSpecificHeaderBox]

    public init(
        scheme: CommonEncryptionScheme,
        defaultKID: KeyIdentifier,
        defaultPerSampleIVSize: TrackEncryptionBox.PerSampleIVSize,
        defaultConstantIV: ConstantIV? = nil,
        defaultCryptByteBlock: UInt8 = 0,
        defaultSkipByteBlock: UInt8 = 0,
        psshBoxes: [ProtectionSystemSpecificHeaderBox] = []
    ) {
        self.scheme = scheme
        self.defaultKID = defaultKID
        self.defaultPerSampleIVSize = defaultPerSampleIVSize
        self.defaultConstantIV = defaultConstantIV
        self.defaultCryptByteBlock = defaultCryptByteBlock
        self.defaultSkipByteBlock = defaultSkipByteBlock
        self.psshBoxes = psshBoxes
    }

    /// Compose the track-level ``TrackEncryptionBox`` from these
    /// parameters, picking the correct `tenc.version` based on
    /// whether the scheme uses block-level pattern encryption.
    public func makeTrackEncryptionBox() -> TrackEncryptionBox {
        let version: UInt8 = scheme.usesPattern ? 1 : 0
        return TrackEncryptionBox(
            version: version,
            defaultCryptByteBlock: defaultCryptByteBlock,
            defaultSkipByteBlock: defaultSkipByteBlock,
            defaultIsProtected: true,
            defaultPerSampleIVSize: defaultPerSampleIVSize,
            defaultKID: defaultKID,
            defaultConstantIV: defaultConstantIV
        )
    }

    /// Compose the track-level ``ProtectionSchemeInfoBox`` whose
    /// `frma` carries the *original* (unprotected) sample-entry
    /// FourCC.
    public func makeProtectionSchemeInfoBox(
        originalFormat: FourCC
    ) -> ProtectionSchemeInfoBox {
        ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: originalFormat),
            schemeType: SchemeTypeBox(schemeType: scheme),
            schemeInformation: SchemeInformationBox(
                trackEncryption: makeTrackEncryptionBox()
            )
        )
    }
}
