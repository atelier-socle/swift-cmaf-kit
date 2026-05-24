// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - IANALanguageSubtagRegistry — ISO 15924 script codes
//
// Reference: ISO 15924 (Codes for the representation of names of
// scripts) — ~200 active 4-character title-case codes. Snapshot
// 2026-05. Codes outside this set pass via the syntax-only validator.

import Foundation

extension IANALanguageSubtagRegistry {

    /// Active ISO 15924 script codes (4-character title-case,
    /// snapshot 2026-05).
    internal static let iso15924Scripts: Set<String> = [
        "Adlm", "Afak", "Aghb", "Ahom", "Arab", "Aran", "Armi", "Armn",
        "Avst",
        "Bali", "Bamu", "Bass", "Batk", "Beng", "Bhks", "Blis", "Bopo",
        "Brah", "Brai", "Bugi", "Buhd",
        "Cakm", "Cans", "Cari", "Cham", "Cher", "Chrs", "Cirt", "Copt",
        "Cpmn", "Cprt", "Cyrl", "Cyrs",
        "Deva", "Diak", "Dogr", "Dsrt", "Dupl",
        "Egyd", "Egyh", "Egyp", "Elba", "Elym", "Ethi",
        "Geok", "Geor", "Glag", "Gong", "Gonm", "Goth", "Gran", "Grek",
        "Gujr", "Guru",
        "Hanb", "Hang", "Hani", "Hano", "Hans", "Hant", "Hatr", "Hebr",
        "Hira", "Hluw", "Hmng", "Hmnp", "Hrkt", "Hung",
        "Inds", "Ital",
        "Jamo", "Java", "Jpan", "Jurc",
        "Kali", "Kana", "Kawi", "Khar", "Khmr", "Khoj", "Kitl", "Kits",
        "Knda", "Kore", "Kpel", "Kthi",
        "Lana", "Laoo", "Latf", "Latg", "Latn", "Leke", "Lepc", "Limb",
        "Lina", "Linb", "Lisu", "Loma", "Lyci", "Lydi",
        "Mahj", "Maka", "Mand", "Mani", "Marc", "Maya", "Medf", "Mend",
        "Merc", "Mero", "Mlym", "Modi", "Mong", "Moon", "Mroo", "Mtei",
        "Mult", "Mymr",
        "Nagm", "Nand", "Narb", "Nbat", "Newa", "Nkdb", "Nkgb", "Nkoo",
        "Nshu",
        "Ogam", "Olck", "Orkh", "Orya", "Osge", "Osma", "Ougr",
        "Palm", "Pauc", "Perm", "Phag", "Phli", "Phlp", "Phlv", "Phnx",
        "Plrd", "Prti",
        "Qaaa", "Qabx",
        "Rjng", "Rohg", "Roro", "Runr",
        "Samr", "Sara", "Sarb", "Saur", "Sgnw", "Shaw", "Shrd", "Sidd",
        "Sind", "Sinh", "Sogd", "Sogo", "Sora", "Soyo", "Sund", "Sylo",
        "Syrc", "Syre", "Syrj", "Syrn",
        "Tagb", "Takr", "Tale", "Talu", "Taml", "Tang", "Tavt", "Telu",
        "Teng", "Tfng", "Tglg", "Thaa", "Thai", "Tibt", "Tirh", "Tnsa",
        "Toto",
        "Ugar",
        "Vaii", "Visp", "Vith",
        "Wara", "Wcho",
        "Xpeo", "Xsux",
        "Yezi", "Yiii",
        "Zanb", "Zinh", "Zmth", "Zsye", "Zsym", "Zxxx", "Zyyy", "Zzzz"
    ]
}
