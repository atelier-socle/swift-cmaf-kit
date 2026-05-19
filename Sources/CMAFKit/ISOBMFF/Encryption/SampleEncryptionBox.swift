// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleEncryptionBox (senc)
//
// Reference: ISO/IEC 23001-7 §7.2 (SampleEncryptionBox).
//
// Full box carrying per-sample IVs and optional subsample partitions.
// The per-sample IV byte width is **not** carried inside `senc` itself;
// it lives in the track's `TrackEncryptionBox` (`tenc`). Parsing
// `senc` therefore requires an external IV-size context.
//
// As a result, `senc` is intentionally NOT registered in
// ``BoxRegistry``'s shared default parser map: the registry has no
// way to discover the IV size without traversing the track structure
// first. Callers parse `senc` explicitly via the typed entry point
// ``SampleEncryptionBox/parse(reader:header:registry:ivSize:)`` once
// they have resolved the per-track encryption context (typically via
// the high-level reader delivered in a later module).

import Foundation

/// Sample encryption box (`senc`) per ISO/IEC 23001-7 §7.2.
public struct SampleEncryptionBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "senc"

    /// Flag bit signalling presence of subsample partitions on each
    /// sample (the `use_subsamples` bit per §7.2).
    public static let flagUseSubsamples: UInt32 = 0x0000_0002

    /// One subsample partition entry.
    public struct SubsamplePartition: Sendable, Hashable, Equatable, Codable {
        public let bytesOfClearData: UInt16
        public let bytesOfProtectedData: UInt32

        public init(bytesOfClearData: UInt16, bytesOfProtectedData: UInt32) {
            self.bytesOfClearData = bytesOfClearData
            self.bytesOfProtectedData = bytesOfProtectedData
        }
    }

    /// One per-sample encryption entry.
    public struct SampleEncryptionEntry: Sendable, Equatable, Hashable {
        /// Per-sample initialisation vector. Length matches the
        /// associated `tenc.defaultPerSampleIVSize`.
        public let initializationVector: Data
        /// Subsample partitions; present iff the box's flags carry
        /// ``SampleEncryptionBox/flagUseSubsamples``.
        public let subsamples: [SubsamplePartition]?

        public init(initializationVector: Data, subsamples: [SubsamplePartition]? = nil) {
            self.initializationVector = initializationVector
            self.subsamples = subsamples
        }
    }

    public let version: UInt8
    public let flags: UInt32
    public let samples: [SampleEncryptionEntry]

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        samples: [SampleEncryptionEntry]
    ) {
        precondition(version == 0, "senc version must be 0")
        self.version = version
        self.flags = flags
        self.samples = samples
    }

    /// Parse a `senc` box body using an externally-supplied per-sample
    /// IV size. Throws if the IV size is ``TrackEncryptionBox/PerSampleIVSize/zero``
    /// (which has no per-sample IV on the wire) but the box is non-empty.
    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry,
        ivSize: TrackEncryptionBox.PerSampleIVSize
    ) async throws -> SampleEncryptionBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        guard version == 0 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "senc version must be 0; got \(version)"
            )
        }
        let sampleCount = try reader.readUInt32()
        let useSubsamples = (flags & flagUseSubsamples) != 0
        var entries: [SampleEncryptionEntry] = []
        entries.reserveCapacity(Int(sampleCount))
        let ivLength = Int(ivSize.rawValue)
        for _ in 0..<sampleCount {
            let iv: Data =
                ivLength > 0
                ? try reader.readData(count: ivLength)
                : Data()
            var subsamples: [SubsamplePartition]?
            if useSubsamples {
                let count = try reader.readUInt16()
                var list: [SubsamplePartition] = []
                list.reserveCapacity(Int(count))
                for _ in 0..<count {
                    let clear = try reader.readUInt16()
                    let protected = try reader.readUInt32()
                    list.append(
                        SubsamplePartition(
                            bytesOfClearData: clear,
                            bytesOfProtectedData: protected
                        )
                    )
                }
                subsamples = list
            }
            entries.append(
                SampleEncryptionEntry(
                    initializationVector: iv,
                    subsamples: subsamples
                )
            )
        }
        return SampleEncryptionBox(version: version, flags: flags, samples: entries)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(UInt32(samples.count))
            let useSubsamples = (flags & Self.flagUseSubsamples) != 0
            for entry in samples {
                body.writeData(entry.initializationVector)
                if useSubsamples {
                    let subs = entry.subsamples ?? []
                    body.writeUInt16(UInt16(subs.count))
                    for sub in subs {
                        body.writeUInt16(sub.bytesOfClearData)
                        body.writeUInt32(sub.bytesOfProtectedData)
                    }
                }
            }
        }
    }
}
