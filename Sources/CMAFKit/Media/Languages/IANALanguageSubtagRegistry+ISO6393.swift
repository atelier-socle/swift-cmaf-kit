// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - IANALanguageSubtagRegistry — ISO 639-2/3 terminologic codes
//
// Reference: ISO 639-2 (alpha-3) / ISO 639-3 (alpha-3, comprehensive).
// Embedded subset (~300 entries) covering all ISO 639-1 equivalents
// (terminologic /T form) plus the most common 639-3-only codes used
// in streaming media (Chinese topolects, sign languages, regional
// minorities) and the ISO 639-2 special-purpose codes.
//
// Snapshot date: 2026-05. The full ISO 639-3 registry has ~7,800
// codes; codes outside this embedded set pass via the syntax-only
// validator (`isWellFormedISO639_3`).

import Foundation

extension IANALanguageSubtagRegistry {

    /// Active ISO 639-2/3 terminologic 3-character codes (embedded
    /// subset — snapshot 2026-05).
    internal static let iso639_3Codes: Set<String> = [
        // Special-purpose codes (ISO 639-2 §3)
        "und", "mul", "zxx", "mis",

        // 639-1 equivalents (terminologic /T form)
        "aar", "abk", "ave", "afr", "aka", "amh", "arg", "ara", "asm", "ava",
        "aym", "aze",
        "bak", "bel", "bul", "bih", "bis", "bam", "ben", "bod", "bre", "bos",
        "cat", "che", "cha", "cos", "cre", "ces", "chu", "chv", "cym",
        "dan", "deu", "div", "dzo",
        "ewe", "ell", "eng", "epo", "spa", "est", "eus",
        "fas", "ful", "fin", "fij", "fao", "fra", "fry",
        "gle", "gla", "glg", "grn", "guj", "glv",
        "hau", "heb", "hin", "hmo", "hrv", "hat", "hun", "hye", "her",
        "ina", "ind", "ile", "ibo", "iii", "ipk", "ido", "isl", "ita", "iku",
        "jpn", "jav",
        "kat", "kon", "kik", "kua", "kaz", "kal", "khm", "kan", "kor", "kau",
        "kas", "kur", "kom", "cor", "kir",
        "lat", "ltz", "lug", "lim", "lin", "lao", "lit", "lub", "lav",
        "mlg", "mah", "mri", "mkd", "mal", "mon", "mar", "msa", "mlt", "mya",
        "nau", "nob", "nde", "nep", "ndo", "nld", "nno", "nor", "nbl", "nav",
        "nya",
        "oci", "oji", "orm", "ori", "oss",
        "pan", "pli", "pol", "pus", "por",
        "que",
        "roh", "run", "ron", "rus", "kin",
        "san", "srd", "snd", "sme", "sag", "sin", "slk", "slv", "smo", "sna",
        "som", "sqi", "srp", "ssw", "sot", "sun", "swe", "swa",
        "tam", "tel", "tgk", "tha", "tir", "tuk", "tgl", "tsn", "ton", "tur",
        "tso", "tat", "twi", "tah",
        "uig", "ukr", "urd", "uzb",
        "ven", "vie", "vol",
        "wln", "wol",
        "xho",
        "yid", "yor",
        "zha", "zho", "zul",

        // 639-3-only common codes used in streaming media
        // Chinese topolects (per RFC 5646 §2.2.2 extlangs)
        "yue", "cmn", "nan", "hak", "wuu", "gan", "hsn", "cdo", "cpx", "czh",
        "czo", "mnp", "lzh",
        // Filipino / regional
        "fil", "ceb", "ilo", "war", "pag", "pam", "bik", "hil",
        // Latin American indigenous
        "grn", "ayr",
        // Sign languages (common in HLS accessibility tracks)
        "ase", "bfi", "fsl", "gsg", "ins", "jsl", "csn", "csl", "rsl",
        // Constructed
        "tlh", "jbo", "lfn",
        // Other common minorities
        "ast", "scn", "vec", "lij", "lmo", "nap", "srd", "sco", "kab"
    ]
}
