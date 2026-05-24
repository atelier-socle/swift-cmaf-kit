// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - RFC6381CodecStringBuilder — internal builder + parser helpers
//
// Splits the per-codec string-building helpers, per-codec parsers, and
// per-kind dispatch logic out of the main struct body so SwiftLint's
// `type_body_length` budget is respected and each helper stays within
// `function_parameter_count`. The HEVC builder takes a typed
// ``HEVCProfileDescriptor`` rather than 6 individual parameters; the
// AV1 and VP9 builders take the descriptor case directly.

import Foundation

extension RFC6381CodecStringBuilder {

    // MARK: - Per-kind dispatch (called from `codecString(for: configuration:)`)

    static func videoCodecString(
        for configuration: CMAFTrackConfiguration
    ) throws -> String {
        guard let video = configuration.videoFields else {
            throw RFC6381BuilderError.missingConfiguration(codec: "video")
        }
        let builder = RFC6381CodecStringBuilder()
        switch video.codec {
        case .avc1, .avc3: return try videoAVCString(video, builder: builder)
        case .hvc1, .hev1: return try videoHEVCString(video, builder: builder)
        case .dvh1, .dvhe: return try videoDolbyVisionString(video, builder: builder)
        case .vp08: return builder.codecString(for: .vp8)
        case .vp09: return try videoVP9String(video, builder: builder)
        case .av01: return try videoAV1String(video, builder: builder)
        case .mp4v:
            throw RFC6381BuilderError.unsupportedCodec(
                reason: "mp4v codec string dispatch not implemented in 0.1.1"
            )
        case .hvc2: return try videoMVHEVCString(video, builder: builder)
        }
    }

    static func audioCodecString(
        for configuration: CMAFTrackConfiguration
    ) throws -> String {
        guard let audio = configuration.audioFields else {
            throw RFC6381BuilderError.missingConfiguration(codec: "audio")
        }
        let builder = RFC6381CodecStringBuilder()
        switch audio.codec {
        case .mp4a:
            // The AAC AOT lives inside esds.decoderConfig.decoderSpecificInfo
            // (the parsed `AudioSpecificConfig`). The traversal lands in
            // Session 6 alongside the codec-string wiring for ALAC + PCM.
            throw RFC6381BuilderError.unsupportedCodec(
                reason: "mp4a codecString(for: configuration:) needs Session 6 esds → AOT wiring"
            )
        case .ac3: return builder.codecString(for: .ac3)
        case .ec3:
            // Wire the EC-3 JOC bit from the typed EC3JOCExtension per
            // Session 6. The codec string itself is always "ec-3" —
            // Apple HLS Authoring §2.2.4 signals JOC via the
            // EXT-X-MEDIA CHANNELS attribute, not the codec string;
            // .joc is consumed by HLSKit / DASHKit for manifest-level
            // attribute emission.
            let joc: Bool
            if case let .ec3(specificBox) = audio.codecConfiguration {
                joc = specificBox.carriesDolbyAtmos
            } else {
                joc = false
            }
            return builder.codecString(for: .ec3(joc: joc))
        case .ac4: return builder.codecString(for: .ac4(presentationID: nil))
        case .opus: return builder.codecString(for: .opus)
        case .flac: return builder.codecString(for: .flac)
        case .mpegHMain:
            return builder.codecString(
                for: .mpegH(sampleEntry: .mhm1, profileLevelIndication: 0x0C)
            )
        case .mpegHMultiStream:
            return builder.codecString(
                for: .mpegH(sampleEntry: .mhm2, profileLevelIndication: 0x0C)
            )
        case .alac: return builder.codecString(for: .alac)
        case .ipcm: return builder.codecString(for: .pcmIPCM)
        case .fpcm: return builder.codecString(for: .pcmFPCM)
        case .lpcm: return builder.codecString(for: .pcmLPCM)
        }
    }

    static func subtitleCodecString(
        for configuration: CMAFTrackConfiguration
    ) throws -> String {
        guard let subtitle = configuration.subtitleFields else {
            throw RFC6381BuilderError.missingConfiguration(codec: "subtitle")
        }
        let builder = RFC6381CodecStringBuilder()
        switch subtitle.codec {
        case .webVTT: return builder.codecString(for: .webVTT)
        case .imsc1Text: return builder.codecString(for: .imsc1Text)
        case .imsc1Image: return builder.codecString(for: .imsc1Image)
        }
    }

    // MARK: - Per-codec video dispatchers (each handles 1 enum case)

    private static func videoAVCString(
        _ video: CMAFTrackConfiguration.VideoFields,
        builder: RFC6381CodecStringBuilder
    ) throws -> String {
        guard case .avc(let record) = video.codecConfiguration else {
            throw RFC6381BuilderError.missingConfiguration(
                codec: video.codec.sampleEntryFourCC.description
            )
        }
        let kind: AVCSampleEntryKind = video.codec == .avc1 ? .avc1 : .avc3
        return builder.codecString(
            for: .avc(
                sampleEntry: kind,
                profile: record.profileIndication.rawValue,
                constraint: record.profileCompatibility.rawValue,
                level: record.levelIndication.rawValue
            )
        )
    }

    private static func videoHEVCString(
        _ video: CMAFTrackConfiguration.VideoFields,
        builder: RFC6381CodecStringBuilder
    ) throws -> String {
        guard case .hevc(let record) = video.codecConfiguration else {
            throw RFC6381BuilderError.missingConfiguration(
                codec: video.codec.sampleEntryFourCC.description
            )
        }
        let kind: HEVCSampleEntryKind = video.codec == .hvc1 ? .hvc1 : .hev1
        return builder.codecString(
            for: .hevc(
                sampleEntry: kind,
                profileSpace: record.profileSpace.rawValue,
                profile: record.profileIDC.rawValue,
                profileCompat: record.profileCompatibilityFlags.rawValue,
                tier: record.tierFlag,
                level: record.levelIDC.rawValue,
                constraintFlags: constraintFlagBytes(record.constraintIndicatorFlags)
            )
        )
    }

    private static func videoDolbyVisionString(
        _ video: CMAFTrackConfiguration.VideoFields,
        builder: RFC6381CodecStringBuilder
    ) throws -> String {
        let kind: DolbyVisionSampleEntryKind
        switch video.codec {
        case .dvh1: kind = .dvh1
        case .dvhe: kind = .dvhe
        default:
            throw RFC6381BuilderError.unsupportedCodec(
                reason: "\(video.codec) not yet wired through dvav / dav1"
            )
        }
        guard let dvcC = video.dolbyVisionConfiguration else {
            throw RFC6381BuilderError.missingConfiguration(codec: kind.rawValue)
        }
        return builder.codecString(
            for: .dolbyVision(
                sampleEntry: kind,
                profile: dvcC.configuration.profile,
                level: dvcC.configuration.level
            )
        )
    }

    private static func videoVP9String(
        _ video: CMAFTrackConfiguration.VideoFields,
        builder: RFC6381CodecStringBuilder
    ) throws -> String {
        guard case .vp(let record) = video.codecConfiguration else {
            throw RFC6381BuilderError.missingConfiguration(codec: "vp09")
        }
        return builder.codecString(
            for: .vp9(
                profile: record.profile.rawValue,
                level: record.level.rawValue,
                bitDepth: record.bitDepth,
                chromaSubsampling: vpChromaSubsampling(record.chromaSubsampling),
                colorPrimaries: record.colourPrimaries.rawValue,
                transferCharacteristics: record.transferCharacteristics.rawValue,
                matrixCoefficients: record.matrixCoefficients.rawValue,
                videoFullRangeFlag: record.videoFullRangeFlag == .full
            )
        )
    }

    private static func videoAV1String(
        _ video: CMAFTrackConfiguration.VideoFields,
        builder: RFC6381CodecStringBuilder
    ) throws -> String {
        guard case .av1(let record) = video.codecConfiguration else {
            throw RFC6381BuilderError.missingConfiguration(codec: "av01")
        }
        // AV1 codec config does not carry colour metadata in the record
        // itself (it lives in the OBU sequence header). For codec-string
        // purposes we emit defaults; consumers needing exact colour info
        // build the descriptor manually.
        return builder.codecString(
            for: .av1(
                profile: record.seqProfile.rawValue,
                level: record.seqLevelIdx0.rawValue,
                tier: record.seqTier0,
                bitDepth: record.highBitdepth ? (record.twelveBit ? 12 : 10) : 8,
                monochrome: record.monochrome,
                chromaSubsampling: av1ChromaSubsampling(record),
                colorPrimaries: 1,
                transferCharacteristics: 1,
                matrixCoefficients: 1,
                videoFullRangeFlag: false
            )
        )
    }

    private static func videoMVHEVCString(
        _ video: CMAFTrackConfiguration.VideoFields,
        builder: RFC6381CodecStringBuilder
    ) throws -> String {
        guard case .mvHEVC(let config, _, _, _) = video.codecConfiguration else {
            throw RFC6381BuilderError.missingConfiguration(codec: "hvc2")
        }
        let base = config.baseLayer
        let baseProfile = HEVCProfileDescriptor(
            profileSpace: base.profileSpace.rawValue,
            profile: base.profileIDC.rawValue,
            profileCompat: base.profileCompatibilityFlags.rawValue,
            tier: base.tierFlag,
            level: base.levelIDC.rawValue,
            constraintFlags: constraintFlagBytes(base.constraintIndicatorFlags)
        )
        return builder.codecString(
            for: .mvHEVC(
                baseProfile: baseProfile,
                extensionProfile: nil,
                viewCount: UInt8(config.layerIDs.count)
            )
        )
    }

    // MARK: - Per-codec string builder helpers

    /// HEVC / MV-HEVC string builder. Takes a typed
    /// ``HEVCProfileDescriptor`` rather than 6 individual parameters so
    /// the signature stays within SwiftLint's `function_parameter_count`
    /// budget.
    static func hevcCodecString(
        fourCC: String,
        profile: HEVCProfileDescriptor
    ) -> String {
        var components: [String] = [fourCC]
        components.append(profileSpaceString(profile.profileSpace) + "\(profile.profile)")
        // Per ISO/IEC 14496-15 §A.5 + Apple HLS Authoring §2.2.1 +
        // ffprobe canonical output: emit `general_profile_compatibility_flags`
        // as 8-hex-digit MSB-first lowercase, strip trailing zero nibbles
        // (minimum 1 hex digit retained).
        //   0x60000000 → "60000000" → "6"   (Main profile compat)
        //   0x40000000 → "40000000" → "4"   (Main 10 compat)
        //   0x6010_0000 → "60100000" → "601"
        //   0x0000_0000 → "00000000" → "0"
        let padded = String(format: "%08x", profile.profileCompat)
        var trimmedHex = padded
        while trimmedHex.count > 1 && trimmedHex.hasSuffix("0") {
            trimmedHex.removeLast()
        }
        components.append(trimmedHex)
        components.append("\(profile.tier.codecStringLetter)\(profile.level)")
        // Constraint flags: trim trailing zero bytes per spec.
        var trimmed = Array(profile.constraintFlags)
        while let last = trimmed.last, last == 0 { trimmed.removeLast() }
        for byte in trimmed {
            components.append(String(format: "%02x", byte))
        }
        return components.joined(separator: ".")
    }

    /// AV1 string builder. Takes the descriptor enum directly so the
    /// signature stays at 1 parameter. Precondition: `descriptor` must
    /// be a `.av1` case.
    static func av1CodecString(
        descriptor: RFC6381CodecDescriptor
    ) -> String {
        guard
            case .av1(
                let prof, let lev, let tier, let depth,
                let mono, let chroma, let cp, let tc, let mc, let range
            ) = descriptor
        else {
            preconditionFailure("av1CodecString called with non-.av1 descriptor")
        }
        let levelStr = String(format: "%02d", lev)
        let depthStr = String(format: "%02d", depth)
        var base = "av01.\(prof).\(levelStr)\(tier.codecStringLetter).\(depthStr)"
        // Defaults per AOMedia §5
        let extendedNeeded =
            mono
            || chroma != .yuv420
            || cp != 1
            || tc != 1
            || mc != 1
            || range
        if extendedNeeded {
            let monoStr = mono ? "1" : "0"
            let chromaStr = chromaSubsamplingTriple(chroma)
            let cpStr = String(format: "%02d", cp)
            let tcStr = String(format: "%02d", tc)
            let mcStr = String(format: "%02d", mc)
            let rangeStr = range ? "1" : "0"
            base += ".\(monoStr).\(chromaStr).\(cpStr).\(tcStr).\(mcStr).\(rangeStr)"
        }
        return base
    }

    /// VP9 string builder. Takes the descriptor enum directly so the
    /// signature stays at 1 parameter. Precondition: `descriptor` must
    /// be a `.vp9` case.
    static func vp9CodecString(
        descriptor: RFC6381CodecDescriptor
    ) -> String {
        guard
            case .vp9(
                let prof, let lev, let depth, let chroma,
                let cp, let tc, let mc, let range
            ) = descriptor
        else {
            preconditionFailure("vp9CodecString called with non-.vp9 descriptor")
        }
        // VP9 emits every field as 2-digit zero-padded decimal — no
        // default omission per the VP Codec ISO Media File Format Binding.
        let pp = String(format: "%02d", prof)
        let ll = String(format: "%02d", lev)
        let dd = String(format: "%02d", depth)
        let ss = String(format: "%02d", chroma.rawValue)
        let cpStr = String(format: "%02d", cp)
        let tcStr = String(format: "%02d", tc)
        let mcStr = String(format: "%02d", mc)
        let rr = range ? "01" : "00"
        return "vp09.\(pp).\(ll).\(dd).\(ss).\(cpStr).\(tcStr).\(mcStr).\(rr)"
    }

    // MARK: - Number helpers

    static func zeroPadded2Decimal(_ value: UInt8) -> String {
        String(format: "%02d", value)
    }

    static func profileSpaceString(_ space: UInt8) -> String {
        switch space {
        case 1: return "A"
        case 2: return "B"
        case 3: return "C"
        default: return ""
        }
    }

    /// Decode an HEVC profile-compatibility hex token (a 1..8 hex-digit
    /// trimmed representation per ISO/IEC 14496-15 §A.5) back to the
    /// full 32-bit value.
    static func decodeHEVCProfileCompatHex(_ token: String) -> UInt32? {
        guard token.count >= 1 && token.count <= 8 else { return nil }
        let padded = token + String(repeating: "0", count: 8 - token.count)
        return UInt32(padded, radix: 16)
    }

    /// AV1 chroma subsampling triple per AOMedia AV1 ISO Media Format
    /// Binding §5.
    static func chromaSubsamplingTriple(_ chroma: ChromaSubsampling) -> String {
        switch chroma {
        case .yuv420: return "110"
        case .yuv422: return "100"
        case .yuv444: return "000"
        }
    }

    /// Map ``VPChromaSubsampling`` to the codec-string-level
    /// ``ChromaSubsampling`` enum.
    static func vpChromaSubsampling(_ vpChroma: VPChromaSubsampling) -> ChromaSubsampling {
        switch vpChroma {
        case .format420Vertical, .format420Colocated: return .yuv420
        case .format422: return .yuv422
        case .format444: return .yuv444
        }
    }

    static func av1ChromaSubsampling(_ record: AV1CodecConfigurationRecord) -> ChromaSubsampling {
        if record.chromaSubsamplingX && record.chromaSubsamplingY { return .yuv420 }
        if record.chromaSubsamplingX { return .yuv422 }
        return .yuv444
    }

    /// Extract the first 6 bytes of constraint-flag information from
    /// the typed ``HEVCConstraintIndicatorFlags`` value per ISO/IEC
    /// 14496-15 §A.5.
    static func constraintFlagBytes(_ flags: HEVCConstraintIndicatorFlags) -> Data {
        let raw = flags.rawValueBigEndian
        var bytes = Data()
        for i in (0..<6).reversed() {
            bytes.append(UInt8((raw >> (i * 8)) & 0xFF))
        }
        return bytes
    }

    // MARK: - Parser dispatch

    static func parseSingleSegment(
        _ segment: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        // Constants first.
        switch segment {
        case "vp08": return .vp8
        case "ac-3": return .ac3
        case "ec-3": return .ec3(joc: false)
        case "ac-4": return .ac4(presentationID: nil)
        case "Opus": return .opus
        case "fLaC": return .flac
        case "alac": return .alac
        case "ipcm": return .pcmIPCM
        case "fpcm": return .pcmFPCM
        case "lpcm": return .pcmLPCM
        case "wvtt": return .webVTT
        case "stpp.ttml.im1t": return .imsc1Text
        case "stpp.ttml.im1i": return .imsc1Image
        default: break
        }
        guard let firstDot = segment.firstIndex(of: ".") else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "unknown codec segment '\(segment)' (no dot, no known constant)"
            )
        }
        let prefix = String(segment[..<firstDot])
        let suffix = String(segment[segment.index(after: firstDot)...])
        return try dispatchParsingByPrefix(
            prefix: prefix, suffix: suffix, segment: segment, fullInput: fullInput
        )
    }

    private static func dispatchParsingByPrefix(
        prefix: String, suffix: String, segment: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        switch prefix {
        case "avc1": return try parseAVC(.avc1, suffix: suffix, fullInput: fullInput)
        case "avc3": return try parseAVC(.avc3, suffix: suffix, fullInput: fullInput)
        case "hvc1": return try parseHEVC(.hvc1, suffix: suffix, fullInput: fullInput)
        case "hev1": return try parseHEVC(.hev1, suffix: suffix, fullInput: fullInput)
        case "hvc2": return try parseMVHEVC(suffix: suffix, fullInput: fullInput)
        case "av01": return try parseAV1(suffix: suffix, fullInput: fullInput)
        case "vp09": return try parseVP9(suffix: suffix, fullInput: fullInput)
        case "dvh1": return try parseDolbyVision(.dvh1, suffix: suffix, fullInput: fullInput)
        case "dvhe": return try parseDolbyVision(.dvhe, suffix: suffix, fullInput: fullInput)
        case "dvav": return try parseDolbyVision(.dvav, suffix: suffix, fullInput: fullInput)
        case "dav1": return try parseDolbyVision(.dav1, suffix: suffix, fullInput: fullInput)
        case "mp4a": return try parseAAC(suffix: suffix, fullInput: fullInput)
        case "ac-4": return try parseAC4(suffix: suffix, fullInput: fullInput)
        case "mhm1": return try parseMPEGH(.mhm1, suffix: suffix, fullInput: fullInput)
        case "mhm2": return try parseMPEGH(.mhm2, suffix: suffix, fullInput: fullInput)
        default:
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "unknown codec prefix '\(prefix)' in segment '\(segment)'"
            )
        }
    }

    // MARK: - Per-codec parsers

    private static func parseAVC(
        _ kind: AVCSampleEntryKind, suffix: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        guard suffix.count == 6, let raw = UInt32(suffix, radix: 16) else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "AVC suffix must be 6 hex digits; got '\(suffix)'"
            )
        }
        return .avc(
            sampleEntry: kind,
            profile: UInt8((raw >> 16) & 0xFF),
            constraint: UInt8((raw >> 8) & 0xFF),
            level: UInt8(raw & 0xFF)
        )
    }

    private static func parseHEVC(
        _ kind: HEVCSampleEntryKind, suffix: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        let parts = suffix.split(separator: ".").map(String.init)
        guard parts.count >= 3 else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "HEVC suffix needs at least 3 dot-separated parts; got '\(suffix)'"
            )
        }
        let (space, profile) = try parseHEVCProfileSpaceAndProfile(parts[0], fullInput: fullInput)
        guard let compat = decodeHEVCProfileCompatHex(parts[1]) else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "HEVC profileCompat hex parse failed for '\(parts[1])'"
            )
        }
        let (tier, level) = try parseHEVCTierAndLevel(parts[2], fullInput: fullInput)
        var constraintBytes = Data()
        for i in 3..<min(9, parts.count) {
            guard let byte = UInt8(parts[i], radix: 16) else {
                throw RFC6381BuilderError.malformedCodecString(
                    input: fullInput,
                    reason: "HEVC constraint flag byte parse failed for '\(parts[i])'"
                )
            }
            constraintBytes.append(byte)
        }
        while constraintBytes.count < 6 { constraintBytes.append(0) }
        return .hevc(
            sampleEntry: kind, profileSpace: space, profile: profile,
            profileCompat: compat, tier: tier, level: level,
            constraintFlags: constraintBytes
        )
    }

    private static func parseHEVCProfileSpaceAndProfile(
        _ token: String, fullInput: String
    ) throws -> (UInt8, UInt8) {
        guard let first = token.first else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput, reason: "HEVC profile token empty"
            )
        }
        let space: UInt8
        let profileToken: String
        switch first {
        case "A":
            space = 1
            profileToken = String(token.dropFirst())
        case "B":
            space = 2
            profileToken = String(token.dropFirst())
        case "C":
            space = 3
            profileToken = String(token.dropFirst())
        default:
            space = 0
            profileToken = token
        }
        guard let profile = UInt8(profileToken) else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "HEVC profile decimal parse failed for '\(profileToken)'"
            )
        }
        return (space, profile)
    }

    private static func parseHEVCTierAndLevel(
        _ token: String, fullInput: String
    ) throws -> (HEVCTier, UInt8) {
        guard let first = token.first else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput, reason: "HEVC tier+level token empty"
            )
        }
        let tier: HEVCTier
        switch first {
        case "L": tier = .main
        case "H": tier = .high
        default:
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "HEVC tier letter must be L or H; got '\(first)'"
            )
        }
        guard let level = UInt8(token.dropFirst()) else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "HEVC level decimal parse failed for '\(token.dropFirst())'"
            )
        }
        return (tier, level)
    }

    private static func parseMVHEVC(
        suffix: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        let asHEVC = try parseHEVC(.hvc1, suffix: suffix, fullInput: fullInput)
        guard
            case .hevc(_, let space, let profile, let compat, let tier, let level, let flags) = asHEVC
        else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "internal: hvc2 reparse did not yield .hevc"
            )
        }
        return .mvHEVC(
            baseProfile: HEVCProfileDescriptor(
                profileSpace: space, profile: profile, profileCompat: compat,
                tier: tier, level: level, constraintFlags: flags
            ),
            extensionProfile: nil,
            viewCount: 2  // canonical for Apple Vision Pro stereo
        )
    }

    private static func parseAV1(
        suffix: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        let parts = suffix.split(separator: ".").map(String.init)
        guard parts.count >= 3 else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "AV1 suffix needs at least 3 parts; got '\(suffix)'"
            )
        }
        guard let profile = UInt8(parts[0]) else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput, reason: "AV1 profile parse failed for '\(parts[0])'"
            )
        }
        let levelTierToken = parts[1]
        guard let tierChar = levelTierToken.last else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput, reason: "AV1 level+tier token empty"
            )
        }
        let tier: AV1Tier
        switch tierChar {
        case "M": tier = .main
        case "H": tier = .high
        default:
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "AV1 tier must be M or H; got '\(tierChar)'"
            )
        }
        guard let level = UInt8(levelTierToken.dropLast()) else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "AV1 level decimal parse failed for '\(levelTierToken.dropLast())'"
            )
        }
        guard let depth = UInt8(parts[2]) else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput, reason: "AV1 bit depth parse failed for '\(parts[2])'"
            )
        }
        var mono = false
        var chroma = ChromaSubsampling.yuv420
        var cp: UInt8 = 1
        var tc: UInt8 = 1
        var mc: UInt8 = 1
        var range = false
        if parts.count >= 9 {
            mono = parts[3] == "1"
            chroma = parseAV1ChromaTriple(parts[4]) ?? .yuv420
            cp = UInt8(parts[5]) ?? 1
            tc = UInt8(parts[6]) ?? 1
            mc = UInt8(parts[7]) ?? 1
            range = parts[8] == "1"
        }
        return .av1(
            profile: profile, level: level, tier: tier, bitDepth: depth,
            monochrome: mono, chromaSubsampling: chroma,
            colorPrimaries: cp, transferCharacteristics: tc,
            matrixCoefficients: mc, videoFullRangeFlag: range
        )
    }

    private static func parseAV1ChromaTriple(_ token: String) -> ChromaSubsampling? {
        switch token {
        case "110": return .yuv420
        case "100": return .yuv422
        case "000": return .yuv444
        default: return nil
        }
    }

    private static func parseVP9(
        suffix: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        let parts = suffix.split(separator: ".").map(String.init)
        guard parts.count == 8 else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "vp09 suffix needs 8 dot-separated parts; got \(parts.count)"
            )
        }
        let raws = try parts.map { (token: String) -> UInt8 in
            guard let value = UInt8(token) else {
                throw RFC6381BuilderError.malformedCodecString(
                    input: fullInput,
                    reason: "vp09 decimal parse failed for '\(token)'"
                )
            }
            return value
        }
        return .vp9(
            profile: raws[0], level: raws[1], bitDepth: raws[2],
            chromaSubsampling: ChromaSubsampling(rawValue: raws[3]) ?? .yuv420,
            colorPrimaries: raws[4], transferCharacteristics: raws[5],
            matrixCoefficients: raws[6], videoFullRangeFlag: raws[7] != 0
        )
    }

    private static func parseDolbyVision(
        _ kind: DolbyVisionSampleEntryKind, suffix: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        let parts = suffix.split(separator: ".").map(String.init)
        guard
            parts.count == 2,
            let profileNum = UInt8(parts[0]),
            let level = UInt8(parts[1]),
            let levelEnum = DolbyVisionLevel(rawValue: level)
        else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "Dolby Vision suffix must be 'PP.LL' decimal; got '\(suffix)'"
            )
        }
        let profile: DolbyVisionProfile
        do {
            profile = try DolbyVisionProfile.make(
                wireProfileNumber: profileNum,
                compatibilityID: .hdr10Compatible
            )
        } catch {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "Dolby Vision profile number \(profileNum) is not recognised"
            )
        }
        return .dolbyVision(sampleEntry: kind, profile: profile, level: levelEnum)
    }

    private static func parseAAC(
        suffix: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        let parts = suffix.split(separator: ".").map(String.init)
        guard
            parts.count == 2,
            parts[0] == "40",
            let aot = UInt8(parts[1]),
            let profile = AACProfile(rawValue: aot)
        else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "AAC suffix must be '40.<AOT>' with known AOT; got '\(suffix)'"
            )
        }
        return .aac(audioObjectType: profile)
    }

    private static func parseAC4(
        suffix: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        guard let id = UInt8(suffix) else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "AC-4 presentation ID parse failed for '\(suffix)'"
            )
        }
        return .ac4(presentationID: id)
    }

    private static func parseMPEGH(
        _ kind: MPEGHSampleEntryKind, suffix: String, fullInput: String
    ) throws -> RFC6381CodecDescriptor {
        guard suffix.hasPrefix("0x") else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "MPEG-H PLI must be prefixed with '0x'; got '\(suffix)'"
            )
        }
        let hex = String(suffix.dropFirst(2))
        guard let pli = UInt8(hex, radix: 16) else {
            throw RFC6381BuilderError.malformedCodecString(
                input: fullInput,
                reason: "MPEG-H PLI hex parse failed for '\(hex)'"
            )
        }
        return .mpegH(sampleEntry: kind, profileLevelIndication: pli)
    }
}
