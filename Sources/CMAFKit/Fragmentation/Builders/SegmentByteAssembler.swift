// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SegmentByteAssembler
//
// Reference: ISO/IEC 14496-12 §8.8 (MovieFragmentBox group) and
// §8.7.5 (`saio` byte offsets). ISO/IEC 23001-7 §7.2 / §9 for
// `senc` placement and `saio` semantics.
//
// Assembles a complete media-fragment byte stream (`moof` + `mdat`,
// optionally with leading `styp`/`sidx`/`prft`/`emsg`) for one
// single-track fragment. Handles both unencrypted and CENC-encrypted
// tracks. The assembler:
//
//   1. Builds the typed boxes with placeholder `data_offset = 0`
//      inside `trun`.
//   2. Encodes them and measures their byte sizes.
//   3. Computes the final value for `trun.data_offset` (the offset
//      from the start of `moof` to the first sample byte in `mdat`).
//   4. Patches the placeholder using ``OffsetPatcher``.
//   5. For encrypted tracks, emits `senc` + `saiz` + `saio` inside
//      `traf` with deterministic offsets (no patching needed for
//      `saio` because the per-sample-IV positions are known from
//      the layout we just wrote).

import Foundation

internal struct AssembledSegment: Sendable, Equatable {
    let bytes: Data
    let moofByteSize: Int
    let mdatByteSize: Int
}

internal enum SegmentByteAssemblerError: Error, Equatable {
    case ivSizeMismatch(declared: UInt8, actual: UInt8)
    case subsamplePartitionExceedsSampleSize(
        sampleNumber: UInt32,
        partitionTotal: UInt32,
        sampleSize: UInt32
    )
    case sampleMissingEncryptionMetadata(sampleNumber: UInt32)
}

internal enum SegmentByteAssembler {

    /// Assemble a `moof+mdat` byte pair for a single-track fragment.
    ///
    /// - Parameters:
    ///   - trackID: track identifier.
    ///   - sequenceNumber: 1-based fragment sequence number.
    ///   - baseMediaDecodeTime: `tfdt.baseMediaDecodeTime`.
    ///   - samples: per-sample metadata + bytes + optional encryption
    ///     metadata. The encryption metadata MUST be present iff
    ///     `encryption` is non-nil.
    ///   - encryption: track-level encryption parameters. When nil,
    ///     the assembler emits a plain `traf` (no `senc`/`saiz`/`saio`).
    ///   - validateSubsamplePartitions: when true, the assembler
    ///     enforces `sum(clear + protected) == sampleSize` for each
    ///     sample carrying subsample partitions.
    static func emitFragment(
        trackID: UInt32,
        sequenceNumber: UInt32,
        baseMediaDecodeTime: UInt64,
        samples: [WriterSample],
        encryption: CMAFEncryptionParameters?,
        validateSubsamplePartitions: Bool = true
    ) throws -> AssembledSegment {
        // Build the trun-relevant per-sample metadata.
        let metadata = samples.map { $0.metadata }
        let invariance = FragmentInvariance.scan(samples: metadata)

        // Compose the (placeholder data_offset = 0) trun first because
        // we need its encoded size to compute the final data_offset.
        let trun = makeTrackRun(
            samples: metadata,
            invariance: invariance,
            dataOffset: 0
        )
        let trunBytes = encode(trun)

        let mfhd = MovieFragmentHeaderBox(sequenceNumber: sequenceNumber)
        let mfhdBytes = encode(mfhd)

        let tfhd = TrackFragmentHeaderBox(
            trackID: trackID,
            defaultSampleDuration: invariance.defaultSampleDuration,
            defaultSampleSize: invariance.defaultSampleSize,
            defaultSampleFlags: invariance.defaultSampleFlags
        )
        let tfhdBytes = encode(tfhd)

        let tfdt = TrackFragmentDecodeTimeBox(baseMediaDecodeTime: baseMediaDecodeTime)
        let tfdtBytes = encode(tfdt)

        // Encryption auxiliary boxes (senc / saiz / saio).
        //
        // Skipped when every sample's auxiliary-info width is zero
        // (the cbcs + constant-IV + no-subsamples case). Per
        // ISO/IEC 23001-7 §7.2 a `senc` whose entries carry no
        // bytes is informationally empty; per §9 a `saiz`/`saio`
        // pair pointing at zero-width entries is structurally legal
        // but pointless. Skipping keeps the on-wire output minimal
        // and avoids ambiguity in the `saiz.default_sample_info_size`
        // field.
        var sencBytes = Data()
        var saizBytes = Data()
        var saioBytes = Data()
        if let encParams = encryption,
            encryptionAuxiliarySamplesAreNonZero(
                samples: samples,
                ivSize: encParams.defaultPerSampleIVSize.rawValue
            )
        {
            let result = try makeEncryptionAuxiliaryBoxes(
                samples: samples,
                encryption: encParams,
                validateSubsamplePartitions: validateSubsamplePartitions,
                geometry: AuxiliaryGeometry(
                    offsetInMoofToTraf: makeOffsetInMoofToTraf(
                        mfhdSize: mfhdBytes.count
                    ),
                    tfhdSize: tfhdBytes.count,
                    tfdtSize: tfdtBytes.count,
                    trunSize: trunBytes.count
                )
            )
            sencBytes = result.sencBytes
            saizBytes = result.saizBytes
            saioBytes = result.saioBytes
        } else if let encParams = encryption {
            // Still validate sample-level invariants even when we
            // skip emitting the auxiliary boxes.
            try validateEncryptionMetadata(
                samples: samples,
                encryption: encParams,
                validateSubsamplePartitions: validateSubsamplePartitions
            )
        }

        // Assemble `traf` body: tfhd + tfdt + trun + (senc + saiz + saio).
        let trafBody = tfhdBytes + tfdtBytes + trunBytes + sencBytes + saizBytes + saioBytes
        let trafBytes = wrapInBoxHeader(type: "traf", body: trafBody)

        // Assemble `moof` body: mfhd + traf.
        let moofBody = mfhdBytes + trafBytes
        var moofBytes = wrapInBoxHeader(type: "moof", body: moofBody)
        let moofSize = moofBytes.count

        // Patch `trun.data_offset`:
        //
        //   final_data_offset = moofSize + 8 (mdat header size)
        //
        // Position inside `moof` of the data_offset field:
        //   moofHeader(8) + mfhdBytes + trafHeader(8)
        //     + tfhdBytes + tfdtBytes
        //     + trunHeader(8) + version_flags(4) + sample_count(4)
        let dataOffsetPosition =
            8 + mfhdBytes.count + 8
            + tfhdBytes.count + tfdtBytes.count
            + 8 + 4 + 4
        let dataOffsetValue = Int32(moofSize + 8)
        var patcher = OffsetPatcher()
        patcher.record32(at: dataOffsetPosition, value: UInt32(bitPattern: dataOffsetValue))
        patcher.apply(to: &moofBytes)

        // Build `mdat`.
        let mdatBody = samples.reduce(into: Data()) { $0.append($1.bytes) }
        let mdatBytes = wrapInBoxHeader(type: "mdat", body: mdatBody)

        return AssembledSegment(
            bytes: moofBytes + mdatBytes,
            moofByteSize: moofBytes.count,
            mdatByteSize: mdatBytes.count
        )
    }

    // MARK: - Helpers

    /// One sample as the byte assembler sees it: metadata + bytes +
    /// optional CENC metadata.
    internal struct WriterSample: Sendable, Equatable {
        let metadata: FragmentSampleMetadata
        let bytes: Data
        let encryption: CMAFSampleInput.EncryptionMetadata?
    }

    /// Offset (in bytes) from the start of `moof` to the start of
    /// `traf` body (i.e., just after the `traf` header).
    private static func makeOffsetInMoofToTraf(mfhdSize: Int) -> Int {
        // moofHeader(8) + mfhd + trafHeader(8).
        8 + mfhdSize + 8
    }

    /// Geometry of the boxes surrounding senc inside the parent moof,
    /// needed to compute `saio` offsets without re-encoding.
    private struct AuxiliaryGeometry {
        let offsetInMoofToTraf: Int
        let tfhdSize: Int
        let tfdtSize: Int
        let trunSize: Int
    }

    /// Build `senc` + `saiz` + `saio` bytes plus the metadata needed
    /// to write the saio offsets.
    private static func makeEncryptionAuxiliaryBoxes(
        samples: [WriterSample],
        encryption: CMAFEncryptionParameters,
        validateSubsamplePartitions: Bool,
        geometry: AuxiliaryGeometry
    ) throws -> (sencBytes: Data, saizBytes: Data, saioBytes: Data) {
        let ivSize = encryption.defaultPerSampleIVSize.rawValue
        var sencEntries: [SampleEncryptionBox.SampleEncryptionEntry] = []
        var auxSizes: [UInt8] = []
        var useSubsamples = false

        for (index, sample) in samples.enumerated() {
            guard let meta = sample.encryption else {
                throw SegmentByteAssemblerError.sampleMissingEncryptionMetadata(
                    sampleNumber: UInt32(index)
                )
            }
            guard meta.initializationVector.count == Int(ivSize) else {
                throw SegmentByteAssemblerError.ivSizeMismatch(
                    declared: ivSize,
                    actual: UInt8(meta.initializationVector.count)
                )
            }
            if let partitions = meta.subsamples {
                useSubsamples = true
                if validateSubsamplePartitions {
                    let total = partitions.reduce(into: UInt64(0)) { acc, p in
                        acc += UInt64(p.bytesOfClearData) + UInt64(p.bytesOfProtectedData)
                    }
                    if total != UInt64(sample.metadata.sampleSize) {
                        throw
                            SegmentByteAssemblerError
                            .subsamplePartitionExceedsSampleSize(
                                sampleNumber: UInt32(index),
                                partitionTotal: UInt32(clamping: total),
                                sampleSize: sample.metadata.sampleSize
                            )
                    }
                }
            }
            sencEntries.append(
                SampleEncryptionBox.SampleEncryptionEntry(
                    initializationVector: meta.initializationVector,
                    subsamples: meta.subsamples
                ))
            auxSizes.append(
                perSampleAuxInfoSize(
                    ivSize: ivSize,
                    subsampleCount: meta.subsamples?.count ?? 0
                ))
        }

        let sencFlags: UInt32 = useSubsamples ? SampleEncryptionBox.flagUseSubsamples : 0
        let senc = SampleEncryptionBox(flags: sencFlags, samples: sencEntries)
        let sencBytes = encode(senc)

        // saiz: per-sample auxiliary-info sizes.
        let allSameSize = auxSizes.allSatisfy { $0 == auxSizes.first }
        let saiz: SampleAuxiliaryInformationSizesBox
        if allSameSize, let first = auxSizes.first {
            saiz = SampleAuxiliaryInformationSizesBox(
                flags: SampleAuxiliaryInformationSizesBox.flagInfoTypePresent,
                auxInfoType: "cenc",
                auxInfoTypeParameter: 0,
                constantSize: first,
                sampleCount: UInt32(auxSizes.count),
                perSampleSizes: SampleInfoSizeTable(sizes: [])
            )
        } else {
            saiz = SampleAuxiliaryInformationSizesBox(
                flags: SampleAuxiliaryInformationSizesBox.flagInfoTypePresent,
                auxInfoType: "cenc",
                auxInfoTypeParameter: 0,
                constantSize: nil,
                sampleCount: UInt32(auxSizes.count),
                perSampleSizes: SampleInfoSizeTable(sizes: auxSizes)
            )
        }
        let saizBytes = encode(saiz)

        // saio: per-sample auxiliary-info absolute offsets relative
        // to the start of `moof` (because tfhd.defaultBaseIsMoof=1).
        //
        // The first per-sample IV in senc sits at:
        //   offsetInMoofToTraf + tfhdSize + tfdtSize + trunSize
        //     + senc header (8) + version_flags (4) + sample_count (4)
        //
        // Subsequent samples are offset by their auxiliary-info width.
        let saioBaseOffset =
            geometry.offsetInMoofToTraf
            + geometry.tfhdSize + geometry.tfdtSize + geometry.trunSize
            + 8 + 4 + 4
        var offsets: [UInt64] = []
        offsets.reserveCapacity(auxSizes.count)
        var running = UInt64(saioBaseOffset)
        for size in auxSizes {
            offsets.append(running)
            running += UInt64(size)
        }
        let saio = SampleAuxiliaryInformationOffsetsBox(
            version: 1,
            flags: SampleAuxiliaryInformationOffsetsBox.flagInfoTypePresent,
            auxInfoType: "cenc",
            auxInfoTypeParameter: 0,
            table: AuxInfoOffsetsTable(offsets: offsets, version: 1)
        )
        let saioBytes = encode(saio)

        return (sencBytes, saizBytes, saioBytes)
    }

    /// Width in bytes of one sample's auxiliary information inside
    /// `senc` (per-sample IV + optional subsample partitions).
    private static func perSampleAuxInfoSize(
        ivSize: UInt8,
        subsampleCount: Int
    ) -> UInt8 {
        var total = UInt(ivSize)
        if subsampleCount > 0 {
            total += 2  // subsample_count UInt16
            total += UInt(subsampleCount) * 6  // (UInt16 + UInt32) per partition
        }
        return UInt8(clamping: total)
    }

    /// `true` when at least one sample carries non-zero auxiliary
    /// info (either a per-sample IV or any subsample partition).
    private static func encryptionAuxiliarySamplesAreNonZero(
        samples: [WriterSample],
        ivSize: UInt8
    ) -> Bool {
        if ivSize > 0 { return true }
        return samples.contains { sample in
            (sample.encryption?.subsamples?.isEmpty == false)
        }
    }

    /// Sample-level invariant check used when the assembler skips
    /// the auxiliary-info boxes.
    private static func validateEncryptionMetadata(
        samples: [WriterSample],
        encryption: CMAFEncryptionParameters,
        validateSubsamplePartitions: Bool
    ) throws {
        let ivSize = encryption.defaultPerSampleIVSize.rawValue
        for (index, sample) in samples.enumerated() {
            guard let meta = sample.encryption else {
                throw SegmentByteAssemblerError.sampleMissingEncryptionMetadata(
                    sampleNumber: UInt32(index)
                )
            }
            guard meta.initializationVector.count == Int(ivSize) else {
                throw SegmentByteAssemblerError.ivSizeMismatch(
                    declared: ivSize,
                    actual: UInt8(meta.initializationVector.count)
                )
            }
            if validateSubsamplePartitions, let partitions = meta.subsamples {
                let total = partitions.reduce(into: UInt64(0)) { acc, partition in
                    acc +=
                        UInt64(partition.bytesOfClearData)
                        + UInt64(partition.bytesOfProtectedData)
                }
                if total != UInt64(sample.metadata.sampleSize) {
                    throw
                        SegmentByteAssemblerError
                        .subsamplePartitionExceedsSampleSize(
                            sampleNumber: UInt32(index),
                            partitionTotal: UInt32(clamping: total),
                            sampleSize: sample.metadata.sampleSize
                        )
                }
            }
        }
    }

    /// Build a TrackRunBox with the supplied placeholder data_offset.
    private static func makeTrackRun(
        samples: [FragmentSampleMetadata],
        invariance: FragmentInvariance,
        dataOffset: Int32
    ) -> TrackRunBox {
        var perSampleFlags: UInt32 = 0
        if invariance.defaultSampleDuration == nil {
            perSampleFlags |= TrackRunTable.flagSampleDuration
        }
        if invariance.defaultSampleSize == nil {
            perSampleFlags |= TrackRunTable.flagSampleSize
        }
        let needsPerSampleFlags =
            invariance.defaultSampleFlags == nil && !invariance.firstSampleFlagsDiffer
        if needsPerSampleFlags {
            perSampleFlags |= TrackRunTable.flagSampleFlags
        }
        if invariance.anyCompositionOffsetNonZero {
            perSampleFlags |= TrackRunTable.flagSampleCompositionTimeOffsets
        }
        let version: UInt8 = invariance.anyCompositionOffsetNegative ? 1 : 0

        var entries: [TrackRunEntry] = []
        entries.reserveCapacity(samples.count)
        for sample in samples {
            entries.append(
                TrackRunEntry(
                    sampleDuration: invariance.defaultSampleDuration == nil
                        ? sample.durationInTimescale : nil,
                    sampleSize: invariance.defaultSampleSize == nil
                        ? sample.sampleSize : nil,
                    sampleFlags: needsPerSampleFlags ? sample.flags.rawValue : nil,
                    sampleCompositionTimeOffset: invariance.anyCompositionOffsetNonZero
                        ? Int64(sample.compositionTimeOffset) : nil
                ))
        }
        return TrackRunBox(
            version: version,
            dataOffset: dataOffset,
            firstSampleFlags: invariance.firstSampleFlagsDiffer
                ? invariance.firstSampleFlags : nil,
            table: TrackRunTable(
                entries: entries,
                perSampleFlags: perSampleFlags,
                version: version
            )
        )
    }

    /// Encode a typed `ISOBox` to bytes.
    private static func encode<B: ISOBox>(_ box: B) -> Data {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        return writer.data
    }

    /// Wrap a body in an 8-byte ISO BMFF box header (size + type).
    private static func wrapInBoxHeader(type: FourCC, body: Data) -> Data {
        var result = Data()
        result.reserveCapacity(8 + body.count)
        let totalSize = UInt32(8 + body.count)
        result.append(UInt8((totalSize >> 24) & 0xFF))
        result.append(UInt8((totalSize >> 16) & 0xFF))
        result.append(UInt8((totalSize >> 8) & 0xFF))
        result.append(UInt8(totalSize & 0xFF))
        let raw = type.rawValue
        result.append(UInt8((raw >> 24) & 0xFF))
        result.append(UInt8((raw >> 16) & 0xFF))
        result.append(UInt8((raw >> 8) & 0xFF))
        result.append(UInt8(raw & 0xFF))
        result.append(body)
        return result
    }
}
