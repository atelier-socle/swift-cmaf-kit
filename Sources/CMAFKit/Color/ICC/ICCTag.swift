// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCTag
//
// Reference: ICC.1:2022 Annex A (tag definitions).
//
// One typed (signature, element) pair, representing an entry in an ICC
// profile's tag table. The element's type signature is validated
// against what ICC.1:2022 prescribes for the tag's signature;
// mismatches cause a precondition failure at construction time.

import Foundation

/// One typed ICC tag.
///
/// `Codable` is intentionally not adopted because the contained
/// ``ICCElement`` carries associated tuple values that cannot be
/// auto-synthesised. Round-trip uses the binary `parse` / `encode`
/// surface instead.
public struct ICCTag: Sendable, Hashable, Equatable {
    public let signature: ICCTagSignature
    public let element: ICCElement

    public init(signature: ICCTagSignature, element: ICCElement) {
        precondition(
            Self.isValidElementType(signature: signature, element: element),
            "ICCTag: element type \(element.signature) does not match what ICC.1:2022 prescribes for tag \(signature)"
        )
        self.signature = signature
        self.element = element
    }

    /// Validates that the element type is permitted for the given tag
    /// signature per ICC.1:2022 Annex A.
    public static func isValidElementType(
        signature: ICCTagSignature,
        element: ICCElement
    ) -> Bool {
        let permitted = permittedElementTypes(for: signature)
        return permitted.contains(element.signature)
    }

    /// The set of element-type signatures permitted by ICC.1:2022 for
    /// the given tag signature. Most tags permit a single element type;
    /// some (notably TRC tags and A2B/B2A LUT tags) permit multiple.
    public static func permittedElementTypes(
        for signature: ICCTagSignature
    ) -> Set<ICCElementTypeSignature> {
        switch signature {
        case .blueMatrixColumn, .greenMatrixColumn, .redMatrixColumn,
            .mediaWhitePoint, .luminance:
            return [.xyz]
        case .blueTRC, .grayTRC, .greenTRC, .redTRC:
            return [.curve, .parametricCurve]
        case .chromaticAdaptation:
            return [.s15Fixed16Array]
        case .chromaticity:
            return [.chromaticity]
        case .colorantOrder:
            return [.colorantOrder]
        case .colorantTable, .colorantTableOut:
            return [.colorantTable]
        case .colorimetricIntentImageState:
            return [.signature]
        case .copyright:
            return [.multiLocalizedUnicode, .text]
        case .deviceMfgDesc, .deviceModelDesc, .profileDescription,
            .viewingCondDesc:
            return [.multiLocalizedUnicode, .textDescription]
        case .aToB0, .aToB1, .aToB2, .preview0, .preview1, .preview2,
            .gamut:
            return [.lut8, .lut16, .lutAToB]
        case .bToA0, .bToA1, .bToA2:
            return [.lut8, .lut16, .lutBToA]
        case .bToD0, .bToD1, .bToD2, .bToD3,
            .dToB0, .dToB1, .dToB2, .dToB3:
            return [.multiProcessElements]
        case .calibrationDateTime:
            return [.dateTime]
        case .charTarget:
            return [.text]
        case .measurement:
            return [.measurement]
        case .namedColor2:
            return [.namedColor2]
        case .outputResponse:
            return [.responseCurveSet16]
        case .perceptualRenderingIntentGamut, .saturationRenderingIntentGamut:
            return [.signature]
        case .technology:
            return [.signature]
        case .viewingConditions:
            return [.viewingConditions]
        case .profileSequenceDesc:
            return [.profileSequenceDesc]
        case .profileSequenceIdentifier:
            return [.profileSequenceIdentifier]
        }
    }
}
