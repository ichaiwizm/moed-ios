//
//  HaftaraSephardic.swift
//  Moed — CalendarEngine module
//
//  Static parasha reading table: transliterated + Hebrew name, Torah portion,
//  Ashkenazi haftara and the SEPHARDIC haftara (which differs for a number of
//  parshiyot). Derived offline from `@hebcal/leyning`.
//
//  hebcal / KosherCocoa cover the Ashkenazi rite; the Sephardic haftara is the
//  documented "table maison" of CONTRACTS §3.1. When the Sephardic reading is
//  identical to the Ashkenazi one, `sephardic` is stored empty and the lookup
//  returns the Ashkenazi reference.
//
//  Keys are the transliterated parasha names produced by the sedra engine
//  (single, e.g. "Bereshit", and combined, e.g. "Matot-Masei").
//
//  Pure static data, offline, deterministic. Foundation only.
//

import Foundation

/// One parasha reading: Hebrew name, Torah portion, Ashkenazi & Sephardic haftara.
struct ParashaReading {
    let he: String
    let torah: String
    let ashkenazi: String
    /// Empty when identical to `ashkenazi`.
    let sephardicRaw: String

    /// Sephardic haftara (falls back to the Ashkenazi reference when identical).
    var sephardic: String { sephardicRaw.isEmpty ? ashkenazi : sephardicRaw }
}

enum HaftaraSephardic {

    private static func R(_ he: String, _ torah: String, _ ashk: String, _ seph: String) -> ParashaReading {
        ParashaReading(he: he, torah: torah, ashkenazi: ashk, sephardicRaw: seph)
    }

    /// Reading keyed by transliterated parasha name (single or combined).
    static let readings: [String: ParashaReading] = [
    "Bereshit": R("בְּרֵאשִׁית", "Genesis 1:1-6:8", "Isaiah 42:5-43:10", "Isaiah 42:5-21"),
    "Noach": R("נֹחַ", "Genesis 6:9-11:32", "Isaiah 54:1-55:5", "Isaiah 54:1-10"),
    "Lech-Lecha": R("לֶךְ־לְךָ", "Genesis 12:1-17:27", "Isaiah 40:27-41:16", ""),
    "Vayera": R("וַיֵּרָא", "Genesis 18:1-22:24", "II Kings 4:1-37", "II Kings 4:1-23"),
    "Chayei Sara": R("חַיֵּי שָֹרָה", "Genesis 23:1-25:18", "I Kings 1:1-31", ""),
    "Toldot": R("תּוֹלְדוֹת", "Genesis 25:19-28:9", "Malachi 1:1-2:7", ""),
    "Vayetzei": R("וַיֵּצֵא", "Genesis 28:10-32:3", "Hosea 12:13-14:10", "Hosea 11:7-12:12"),
    "Vayishlach": R("וַיִּשְׁלַח", "Genesis 32:4-36:43", "Obadiah 1:1-21", ""),
    "Vayeshev": R("וַיֵּשֶׁב", "Genesis 37:1-40:23", "Amos 2:6-3:8", ""),
    "Miketz": R("מִקֵּץ", "Genesis 41:1-44:17", "I Kings 3:15-4:1", ""),
    "Vayigash": R("וַיִּגַּשׁ", "Genesis 44:18-47:27", "Ezekiel 37:15-28", ""),
    "Vayechi": R("וַיְחִי", "Genesis 47:28-50:26", "I Kings 2:1-12", ""),
    "Shemot": R("שְׁמוֹת", "Exodus 1:1-6:1", "Isaiah 27:6-28:13, 29:22-23", "Jeremiah 1:1-2:3"),
    "Vaera": R("וָאֵרָא", "Exodus 6:2-9:35", "Ezekiel 28:25-29:21", ""),
    "Bo": R("בֹּא", "Exodus 10:1-13:16", "Jeremiah 46:13-28", ""),
    "Beshalach": R("בְּשַׁלַּח", "Exodus 13:17-17:16", "Judges 4:4-5:31", "Judges 5:1-31"),
    "Yitro": R("יִתְרוֹ", "Exodus 18:1-20:23", "Isaiah 6:1-7:6, 9:5-6", "Isaiah 6:1-13"),
    "Mishpatim": R("מִשְׁפָּטִים", "Exodus 21:1-24:18", "Jeremiah 34:8-22, 33:25-26", ""),
    "Terumah": R("תְּרוּמָה", "Exodus 25:1-27:19", "I Kings 5:26-6:13", ""),
    "Tetzaveh": R("תְּצַוֶּה", "Exodus 27:20-30:10", "Ezekiel 43:10-27", ""),
    "Ki Tisa": R("כִּי תִשָּׂא", "Exodus 30:11-34:35", "I Kings 18:1-39", "I Kings 18:20-39"),
    "Vayakhel": R("וַיַּקְהֵל", "Exodus 35:1-38:20", "I Kings 7:40-50", "I Kings 7:13-26"),
    "Pekudei": R("פְקוּדֵי", "Exodus 38:21-40:38", "I Kings 7:51-8:21", "I Kings 7:40-50"),
    "Vayikra": R("וַיִּקְרָא", "Leviticus 1:1-5:26", "Isaiah 43:21-44:23", ""),
    "Tzav": R("צַו", "Leviticus 6:1-8:36", "Jeremiah 7:21-8:3, 9:22-23", ""),
    "Shmini": R("שְּׁמִינִי", "Leviticus 9:1-11:47", "II Samuel 6:1-7:17", "II Samuel 6:1-19"),
    "Tazria": R("תַזְרִיעַ", "Leviticus 12:1-13:59", "II Kings 4:42-5:19", ""),
    "Metzora": R("מְצֹרָע", "Leviticus 14:1-15:33", "II Kings 7:3-20", ""),
    "Achrei Mot": R("אַחֲרֵי מוֹת", "Leviticus 16:1-18:30", "Amos 9:7-15", "Ezekiel 22:1-16"),
    "Kedoshim": R("קְדשִׁים", "Leviticus 19:1-20:27", "Ezekiel 22:1-19", "Ezekiel 20:2-20"),
    "Emor": R("אֱמוֹר", "Leviticus 21:1-24:23", "Ezekiel 44:15-31", ""),
    "Behar": R("בְּהַר", "Leviticus 25:1-26:2", "Jeremiah 32:6-27", ""),
    "Bechukotai": R("בְּחֻקֹּתַי", "Leviticus 26:3-27:34", "Jeremiah 16:19-17:14", ""),
    "Bamidbar": R("בְּמִדְבַּר", "Numbers 1:1-4:20", "Hosea 2:1-22", ""),
    "Nasso": R("נָשׂא", "Numbers 4:21-7:89", "Judges 13:2-25", ""),
    "Beha'alotcha": R("בְּהַעֲלֹתְךָ", "Numbers 8:1-12:16", "Zechariah 2:14-4:7", ""),
    "Sh'lach": R("שְׁלַח־לְךָ", "Numbers 13:1-15:41", "Joshua 2:1-24", ""),
    "Korach": R("קֹרַח", "Numbers 16:1-18:32", "I Samuel 11:14-12:22", ""),
    "Chukat": R("חֻקַּת", "Numbers 19:1-22:1", "Judges 11:1-33", ""),
    "Balak": R("בָּלָק", "Numbers 22:2-25:9", "Micah 5:6-6:8", ""),
    "Pinchas": R("פִּינְחָס", "Numbers 25:10-30:1", "I Kings 18:46-19:21", ""),
    "Matot": R("מַטּוֹת", "Numbers 30:2-32:42", "Jeremiah 1:1-2:3", ""),
    "Masei": R("מַסְעֵי", "Numbers 33:1-36:13", "Jeremiah 2:4-28, 3:4", "Jeremiah 2:4-28, 4:1-2"),
    "Devarim": R("דְּבָרִים", "Deuteronomy 1:1-3:22", "Isaiah 1:1-27", ""),
    "Vaetchanan": R("וָאֶתְחַנַּן", "Deuteronomy 3:23-7:11", "Isaiah 40:1-26", ""),
    "Eikev": R("עֵקֶב", "Deuteronomy 7:12-11:25", "Isaiah 49:14-51:3", ""),
    "Re'eh": R("רְאֵה", "Deuteronomy 11:26-16:17", "Isaiah 54:11-55:5", ""),
    "Shoftim": R("שׁוֹפְטִים", "Deuteronomy 16:18-21:9", "Isaiah 51:12-52:12", ""),
    "Ki Teitzei": R("כִּי־תֵצֵא", "Deuteronomy 21:10-25:19", "Isaiah 54:1-10", ""),
    "Ki Tavo": R("כִּי־תָבוֹא", "Deuteronomy 26:1-29:8", "Isaiah 60:1-22", ""),
    "Nitzavim": R("נִצָּבִים", "Deuteronomy 29:9-30:20", "Isaiah 61:10-63:9", ""),
    "Vayeilech": R("וַיֵּלֶךְ", "Deuteronomy 31:1-30", "Isaiah 55:6-56:8", ""),
    "Ha'azinu": R("הַאֲזִינוּ", "Deuteronomy 32:1-52", "II Samuel 22:1-51", ""),
    "Vezot Haberakhah": R("וְזֹאת הַבְּרָכָה", "Deuteronomy 33:1-34:12", "Joshua 1:1-18", "Joshua 1:1-9"),
    "Vayakhel-Pekudei": R("וַיַּקְהֵל-פְקוּדֵי", "Exodus 35:1-40:38", "I Kings 7:51-8:21", "I Kings 7:40-50"),
    "Tazria-Metzora": R("תַזְרִיעַ-מְצֹרָע", "Leviticus 12:1-15:33", "II Kings 7:3-20", ""),
    "Achrei Mot-Kedoshim": R("אַחֲרֵי מוֹת-קְדשִׁים", "Leviticus 16:1-20:27", "Amos 9:7-15", "Ezekiel 20:2-20"),
    "Behar-Bechukotai": R("בְּהַר-בְּחֻקֹּתַי", "Leviticus 25:1-27:34", "Jeremiah 16:19-17:14", ""),
    "Chukat-Balak": R("חֻקַּת-בָּלָק", "Numbers 19:1-25:9", "Micah 5:6-6:8", ""),
    "Matot-Masei": R("מַטּוֹת-מַסְעֵי", "Numbers 30:2-36:13", "Jeremiah 2:4-28, 3:4", "Jeremiah 2:4-28, 4:1-2"),
    "Nitzavim-Vayeilech": R("נִצָּבִים-וַיֵּלֶךְ", "Deuteronomy 29:9-31:30", "Isaiah 61:10-63:9", ""),

    ]

    /// Looks up the reading for a transliterated parasha name (single or combined).
    static func reading(for name: String) -> ParashaReading? { readings[name] }

    /// Sephardic haftara reference for a parasha name, or `nil` if unknown.
    static func haftara(for name: String) -> String? { readings[name]?.sephardic }
}
