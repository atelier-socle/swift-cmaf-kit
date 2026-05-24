// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - IANALanguageSubtagRegistry — UN M.49 + grandfathered + extlang
//
// References:
// - UN M.49 — Standard Country or Area Codes for Statistical Use
//   (supra-national and continental numeric region codes).
// - IETF RFC 5646 §2.2.8 — Grandfathered and Redundant Registrations.
// - IETF RFC 5646 §2.2.2 — Extended Language Subtags.
//
// Snapshot 2026-05.

import Foundation

extension IANALanguageSubtagRegistry {

    /// UN M.49 numeric region codes for supra-national / continental
    /// regions (snapshot 2026-05).
    internal static let unM49Regions: Set<UInt16> = [
        1,  // World
        2,  // Africa
        5,  // South America
        9,  // Oceania
        11,  // Western Africa
        13,  // Central America
        14,  // Eastern Africa
        15,  // Northern Africa
        17,  // Middle Africa
        18,  // Southern Africa
        19,  // Americas
        21,  // Northern America
        29,  // Caribbean
        30,  // Eastern Asia
        34,  // Southern Asia
        35,  // South-eastern Asia
        39,  // Southern Europe
        53,  // Australia and New Zealand
        54,  // Melanesia
        57,  // Micronesia
        61,  // Polynesia
        142,  // Asia
        143,  // Central Asia
        145,  // Western Asia
        150,  // Europe
        151,  // Eastern Europe
        154,  // Northern Europe
        155,  // Western Europe
        202,  // Sub-Saharan Africa
        419  // Latin America and the Caribbean
    ]

    /// Grandfathered tags per RFC 5646 §2.2.8. These tags were
    /// registered before RFC 4646 (RFC 5646's predecessor) and don't
    /// fit modern syntax; they are retained for backward compatibility.
    /// Stored lowercase for canonical comparison.
    internal static let grandfatheredTags: Set<String> = [
        "art-lojban", "cel-gaulish", "en-gb-oed",
        "i-ami", "i-bnn", "i-default", "i-enochian", "i-hak",
        "i-klingon", "i-lux", "i-mingo", "i-navajo", "i-pwn",
        "i-tao", "i-tay", "i-tsu",
        "no-bok", "no-nyn",
        "sgn-be-fr", "sgn-be-nl", "sgn-ch-de",
        "zh-guoyu", "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang"
    ]

    /// Extended-language subtags per RFC 5646 §2.2.2. Each subtag is
    /// 3 lowercase letters and follows its prefix primary language
    /// (typically `zh` for Chinese topolects, `ar` for Arabic
    /// macrolanguage members, signing for sign languages).
    internal static let extendedLanguageSubtags: Set<String> = [
        // Chinese topolects (prefix `zh`)
        "yue", "cmn", "nan", "hak", "wuu", "gan", "hsn", "cdo", "cpx",
        "czh", "czo", "mnp", "lzh",
        // Arabic varieties (prefix `ar`)
        "aao", "abh", "abv", "acm", "acq", "acw", "acx", "acy", "adf",
        "aeb", "aec", "afb", "ajp", "apc", "apd", "arb", "arq", "ars",
        "ary", "arz", "auz", "avl", "ayh", "ayl", "ayn", "ayp", "bbz",
        "pga", "shu", "ssh",
        // Malay varieties (prefix `ms`)
        "bjn", "btj", "bve", "bvu", "coa", "dup", "hji", "jak", "jax",
        "kvb", "kvr", "kxd", "lce", "lcf", "liw", "max", "meo", "mfa",
        "mfb", "min", "mqg", "msi", "mui", "orn", "ors", "pel", "pse",
        "tmw", "urk", "vkk", "vkt", "xmm", "xmy", "zlm", "zmi", "zsm",
        // Sign languages
        "ase", "bfi", "bfk", "bog", "bqn", "bqy", "csl", "csn", "csq",
        "csr", "esl", "esn", "eso", "eth", "fcs", "fse", "fsl", "fss",
        "gse", "gsg", "gsm", "gss", "gus", "hab", "haf", "hds", "hks",
        "hos", "hps", "hsh", "hsl", "icl", "iks", "ils", "inl", "ins",
        "ise", "isg", "isr", "jcs", "jhs", "jls", "jos", "jsl", "jus",
        "kgi", "kvk", "lbs", "lls", "lsg", "lsl", "lso", "lsp", "lst",
        "lsy", "mdl", "mfs", "mre", "msd", "msr", "mzc", "mzg", "mzy",
        "nbs", "ncs", "nsi", "nsl", "nsp", "nsr", "nzs", "okl", "pks",
        "prl", "prz", "psc", "psd", "pse", "psg", "psl", "pso", "psp",
        "psr", "pys", "rms", "rsi", "rsl", "rsm", "sdl", "sfb", "sfs",
        "sgg", "sgx", "shu", "slf", "sls", "sqs", "ssp", "ssr", "svk",
        "swc", "swh", "swl", "syy", "szs", "tmh", "tse", "tsm", "tsq",
        "tss", "tsy", "tza", "ugn", "ugy", "ukl", "uks", "vgt", "vsi",
        "vsl", "vsv", "wbs", "wuu", "xki", "xml", "xmm", "xms", "yds",
        "ygs", "yhs", "ysl", "ysm", "zib", "zlm", "zmi", "zsl", "zsm"
    ]
}
