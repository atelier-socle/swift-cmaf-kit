// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackFragmentBox typed accessors for sample-group and
// sample-auxiliary children
//
// Reference: ISO/IEC 14496-12 §8.7.8–§8.7.9 (sample auxiliary
// information), §8.9.2–§8.9.3 (sample to group / group description).
//
// These accessors live in a separate file from the `traf` declaration to
// keep the box's primary file free of forward references to types
// declared later in the source tree.

import Foundation

extension TrackFragmentBox {

    /// All `saiz` boxes carried by this fragment.
    ///
    /// A fragment may carry multiple `saiz` boxes — typically one per
    /// `aux_info_type` (for example `"cenc"` and `"cbcs"` when both
    /// schemes ride together).
    public var sampleAuxiliaryInformationSizes: [SampleAuxiliaryInformationSizesBox] {
        findChildren(SampleAuxiliaryInformationSizesBox.self)
    }

    /// All `saio` boxes carried by this fragment. Pairs with
    /// ``sampleAuxiliaryInformationSizes``.
    public var sampleAuxiliaryInformationOffsets: [SampleAuxiliaryInformationOffsetsBox] {
        findChildren(SampleAuxiliaryInformationOffsetsBox.self)
    }

    /// All `sbgp` boxes carried by this fragment. A fragment may carry
    /// one `sbgp` per grouping type.
    public var sampleToGroups: [SampleToGroupBox] {
        findChildren(SampleToGroupBox.self)
    }

    /// All `sgpd` boxes carried by this fragment. A fragment may carry
    /// one `sgpd` per grouping type.
    public var sampleGroupDescriptions: [SampleGroupDescriptionBox] {
        findChildren(SampleGroupDescriptionBox.self)
    }
}
