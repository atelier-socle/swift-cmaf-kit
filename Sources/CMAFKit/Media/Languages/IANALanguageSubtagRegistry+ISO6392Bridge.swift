// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - IANALanguageSubtagRegistry — ISO 639-2 bridge tables
//
// Reference: ISO 639-2 (Bibliographic /B vs Terminologic /T variants)
// + ISO 639-1 ↔ ISO 639-3 down-/up-conversion for canonicalisation
// per RFC 5646 §4.5 (shortest valid form preferred).
//
// The ISOBMFF `mdhd` box (ISO/IEC 14496-12 §8.4.2.3) historically
// allowed either /B or /T 3-character codes; encoders are inconsistent.
// The bridge normalises /B → /T then prefers the ISO 639-1 2-character
// form when available.

import Foundation

extension IANALanguageSubtagRegistry {

    /// ISO 639-2 Bibliographic (/B) → Terminologic (/T) disambiguation
    /// map. Every ISO 639-2 code with a distinct /B and /T form is
    /// included (20 entries per the ISO 639-2 standard).
    internal static let iso639_2BToTMapping: [String: String] = [
        "alb": "sqi",  // Albanian
        "arm": "hye",  // Armenian
        "baq": "eus",  // Basque
        "bur": "mya",  // Burmese
        "chi": "zho",  // Chinese
        "cze": "ces",  // Czech
        "dut": "nld",  // Dutch
        "fre": "fra",  // French
        "geo": "kat",  // Georgian
        "ger": "deu",  // German
        "gre": "ell",  // Greek (modern)
        "ice": "isl",  // Icelandic
        "mac": "mkd",  // Macedonian
        "may": "msa",  // Malay
        "mao": "mri",  // Maori
        "per": "fas",  // Persian
        "rum": "ron",  // Romanian
        "slo": "slk",  // Slovak
        "tib": "bod",  // Tibetan
        "wel": "cym"  // Welsh
    ]

    /// ISO 639-2/3 Terminologic (/T) → ISO 639-1 (alpha-2) down-conversion.
    /// Used by `BCP47LanguageTag.fromISO6392T(_:)` to prefer the
    /// shortest canonical form per RFC 5646 §4.5.
    internal static let iso639_3To1Mapping: [String: String] = [
        "aar": "aa", "abk": "ab", "ave": "ae", "afr": "af", "aka": "ak",
        "amh": "am", "arg": "an", "ara": "ar", "asm": "as", "ava": "av",
        "aym": "ay", "aze": "az",
        "bak": "ba", "bel": "be", "bul": "bg", "bih": "bh", "bis": "bi",
        "bam": "bm", "ben": "bn", "bod": "bo", "bre": "br", "bos": "bs",
        "cat": "ca", "che": "ce", "cha": "ch", "cos": "co", "cre": "cr",
        "ces": "cs", "chu": "cu", "chv": "cv", "cym": "cy",
        "dan": "da", "deu": "de", "div": "dv", "dzo": "dz",
        "ewe": "ee", "ell": "el", "eng": "en", "epo": "eo", "spa": "es",
        "est": "et", "eus": "eu",
        "fas": "fa", "ful": "ff", "fin": "fi", "fij": "fj", "fao": "fo",
        "fra": "fr", "fry": "fy",
        "gle": "ga", "gla": "gd", "glg": "gl", "grn": "gn", "guj": "gu",
        "glv": "gv",
        "hau": "ha", "heb": "he", "hin": "hi", "hmo": "ho", "hrv": "hr",
        "hat": "ht", "hun": "hu", "hye": "hy", "her": "hz",
        "ina": "ia", "ind": "id", "ile": "ie", "ibo": "ig", "iii": "ii",
        "ipk": "ik", "ido": "io", "isl": "is", "ita": "it", "iku": "iu",
        "jpn": "ja", "jav": "jv",
        "kat": "ka", "kon": "kg", "kik": "ki", "kua": "kj", "kaz": "kk",
        "kal": "kl", "khm": "km", "kan": "kn", "kor": "ko", "kau": "kr",
        "kas": "ks", "kur": "ku", "kom": "kv", "cor": "kw", "kir": "ky",
        "lat": "la", "ltz": "lb", "lug": "lg", "lim": "li", "lin": "ln",
        "lao": "lo", "lit": "lt", "lub": "lu", "lav": "lv",
        "mlg": "mg", "mah": "mh", "mri": "mi", "mkd": "mk", "mal": "ml",
        "mon": "mn", "mar": "mr", "msa": "ms", "mlt": "mt", "mya": "my",
        "nau": "na", "nob": "nb", "nde": "nd", "nep": "ne", "ndo": "ng",
        "nld": "nl", "nno": "nn", "nor": "no", "nbl": "nr", "nav": "nv",
        "nya": "ny",
        "oci": "oc", "oji": "oj", "orm": "om", "ori": "or", "oss": "os",
        "pan": "pa", "pli": "pi", "pol": "pl", "pus": "ps", "por": "pt",
        "que": "qu",
        "roh": "rm", "run": "rn", "ron": "ro", "rus": "ru", "kin": "rw",
        "san": "sa", "srd": "sc", "snd": "sd", "sme": "se", "sag": "sg",
        "sin": "si", "slk": "sk", "slv": "sl", "smo": "sm", "sna": "sn",
        "som": "so", "sqi": "sq", "srp": "sr", "ssw": "ss", "sot": "st",
        "sun": "su", "swe": "sv", "swa": "sw",
        "tam": "ta", "tel": "te", "tgk": "tg", "tha": "th", "tir": "ti",
        "tuk": "tk", "tgl": "tl", "tsn": "tn", "ton": "to", "tur": "tr",
        "tso": "ts", "tat": "tt", "twi": "tw", "tah": "ty",
        "uig": "ug", "ukr": "uk", "urd": "ur", "uzb": "uz",
        "ven": "ve", "vie": "vi", "vol": "vo",
        "wln": "wa", "wol": "wo",
        "xho": "xh",
        "yid": "yi", "yor": "yo",
        "zha": "za", "zho": "zh", "zul": "zu"
    ]
}
