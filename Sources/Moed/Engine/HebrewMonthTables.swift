//
//  HebrewMonthTables.swift
//  Moed — CalendarEngine module
//
//  Local trilingual name tables (he / fr / en) for Hebrew months and weekdays,
//  plus Hebrew-letter numeral rendering (gematriya) for years and days.
//
//  hebcal / KosherJava only know `en` / `he` — **never** derive a French
//  rendering from a library. All month/weekday names and the year/day
//  Hebrew-letter strings are produced here (ported 1:1 from the web engine
//  `mvp-moed/src/lib/engine/hebrewDate.ts` and `@hebcal/hdate` `gematriya.ts`).
//
//  Month numbering is Nisan-based (hebcal convention): 1 = Nisan … 7 = Tishrei …
//  12 = Adar (Adar I in a leap year), 13 = Adar II.
//
//  Pure, deterministic, offline. Foundation only.
//

import Foundation

enum HebrewMonthTables {

    // MARK: - Month names (Nisan-based, 1..13)

    /// Nisan-based months 1..11 (Nisan … Sh'vat). Adar variants are resolved by
    /// `monthName(_:isLeapYear:)` because month 12/13 depends on the leap year.
    private static let baseMonths: [Int: LocalizedText] = [
        1:  LocalizedText(he: "נִיסָן",   fr: "Nissan", en: "Nisan"),
        2:  LocalizedText(he: "אִיָּיר",   fr: "Iyar",   en: "Iyar"),
        3:  LocalizedText(he: "סִיוָן",    fr: "Sivan",  en: "Sivan"),
        4:  LocalizedText(he: "תַּמּוּז",   fr: "Tamouz", en: "Tammuz"),
        5:  LocalizedText(he: "אָב",       fr: "Av",     en: "Av"),
        6:  LocalizedText(he: "אֱלוּל",    fr: "Eloul",  en: "Elul"),
        7:  LocalizedText(he: "תִּשְׁרֵי",  fr: "Tichri", en: "Tishrei"),
        8:  LocalizedText(he: "חֶשְׁוָן",   fr: "Hechvan", en: "Cheshvan"),
        9:  LocalizedText(he: "כִּסְלֵו",   fr: "Kislev", en: "Kislev"),
        10: LocalizedText(he: "טֵבֵת",     fr: "Tevet",  en: "Tevet"),
        11: LocalizedText(he: "שְׁבָט",    fr: "Chevat", en: "Sh'vat"),
    ]

    private static let adar   = LocalizedText(he: "אֲדָר",     fr: "Adar",   en: "Adar")
    private static let adarI  = LocalizedText(he: "אֲדָר א׳", fr: "Adar I", en: "Adar I")
    private static let adarII = LocalizedText(he: "אֲדָר ב׳", fr: "Adar II", en: "Adar II")

    /// Localized month name for a Nisan-based month number in a given year type.
    /// Month 12 renders "Adar" in a common year and "Adar I" in a leap year;
    /// month 13 is always "Adar II".
    static func monthName(_ month: Int, isLeapYear: Bool) -> LocalizedText {
        switch month {
        case 12: return isLeapYear ? adarI : adar
        case 13: return adarII
        default: return baseMonths[month] ?? adar
        }
    }

    // MARK: - Weekday names (index 0 = Sunday … 6 = Saturday)

    static let weekdays: [LocalizedText] = [
        LocalizedText(he: "רִאשׁוֹן",  fr: "Dimanche", en: "Sunday"),
        LocalizedText(he: "שֵׁנִי",    fr: "Lundi",    en: "Monday"),
        LocalizedText(he: "שְׁלִישִׁי", fr: "Mardi",    en: "Tuesday"),
        LocalizedText(he: "רְבִיעִי",  fr: "Mercredi", en: "Wednesday"),
        LocalizedText(he: "חֲמִישִׁי",  fr: "Jeudi",    en: "Thursday"),
        LocalizedText(he: "שִׁשִּׁי",   fr: "Vendredi", en: "Friday"),
        LocalizedText(he: "שַׁבָּת",    fr: "Chabbat",  en: "Shabbat"),
    ]

    /// Weekday name for index 0 (Sunday) … 6 (Saturday).
    static func weekdayName(_ index: Int) -> LocalizedText {
        let i = ((index % 7) + 7) % 7
        return weekdays[i]
    }
}

// MARK: - Hebrew numeral rendering (gematriya)

/// Renders integers as Hebrew letters with geresh / gershayim, omitting the
/// thousands digit for present-millennium years (ported from `@hebcal/hdate`
/// `gematriya.ts`). Example: `5785` → `"תשפ״ה"`, `15` → `"ט״ו"`.
enum HebrewNumerals {

    private static let geresh = "׳"
    private static let gershayim = "״"

    private static let num2heb: [Int: String] = [
        1: "א", 2: "ב", 3: "ג", 4: "ד", 5: "ה", 6: "ו", 7: "ז", 8: "ח", 9: "ט",
        10: "י", 20: "כ", 30: "ל", 40: "מ", 50: "נ", 60: "ס", 70: "ע", 80: "פ",
        90: "צ", 100: "ק", 200: "ר", 300: "ש", 400: "ת",
    ]

    /// Decomposes a number (< 1000) into descending Hebrew numeral components,
    /// treating 15/16 specially (ט״ו / ט״ז) to avoid spelling a Divine name.
    private static func num2digits(_ n: Int) -> [Int] {
        var num = n
        var digits: [Int] = []
        while num > 0 {
            if num == 15 || num == 16 {
                digits.append(9)
                digits.append(num - 9)
                break
            }
            var incr = 100
            var i = 400
            while i > num {
                if i == incr { incr = incr / 10 }
                i -= incr
            }
            digits.append(i)
            num -= i
        }
        return digits
    }

    /// Hebrew-letter representation. Thousands are shown with a geresh unless the
    /// thousands digit is 5 (the present millennium, omitted by convention).
    static func gematriya(_ number: Int) -> String {
        guard number > 0 else { return "" }
        var str = ""
        let thousands = number / 1000
        if thousands > 0 && thousands != 5 {
            for tdig in num2digits(thousands) {
                str += num2heb[tdig] ?? ""
            }
            str += geresh
        }
        let digits = num2digits(number % 1000)
        if digits.count == 1 {
            return str + (num2heb[digits[0]] ?? "") + geresh
        }
        for i in 0..<digits.count {
            if i + 1 == digits.count { str += gershayim }
            str += num2heb[digits[i]] ?? ""
        }
        return str
    }
}
