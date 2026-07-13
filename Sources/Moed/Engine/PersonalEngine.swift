//
//  PersonalEngine.swift
//  Moed — CalendarEngine module
//
//  Recurring personal Hebrew dates: yahrzeit and Hebrew birthdays/anniversaries.
//
//  Faithful port of `@hebcal/hdate` `anniversary.js` (`getYahrzeit`,
//  `getBirthdayOrAnniversary`) — implementing the "Calendrical Calculations"
//  halakhic rules, including the tricky Cheshvan 30 / Kislev 30 / Adar I 30 /
//  Adar II cases in leap vs. common years.
//
//  The Hebrew day begins at sunset: `PersonRecord.afterSunset` advances the
//  anchor Hebrew date by one day. Enumeration walks Hebrew year by Hebrew year
//  from the year of `from`, with the contract anti-loop guard of `count + 200`.
//
//  100% offline, deterministic. Foundation only.
//

import Foundation

public enum PersonalEngine {

    /// Upcoming occurrences of a personal recurring Hebrew date (yahrzeit or
    /// birthday), strictly on/after `from` (compared by calendar day).
    ///
    /// - Parameters:
    ///   - person: the record (type, original Gregorian date, after-sunset flag).
    ///   - from: search start (occurrences on/after this civil day are returned).
    ///   - count: number of occurrences to return.
    ///   - geo: location (its time zone anchors the original & `from` civil days).
    ///   - lang: unused for computation; occurrences carry localized Hebrew names.
    public static func occurrences(of person: PersonRecord,
                                   from: Date,
                                   count: Int,
                                   geo: GeoContext,
                                   lang: Lang) -> [Occurrence] {
        guard count > 0 else { return [] }
        let tz = TimeZone(identifier: geo.timeZone) ?? TimeZone(identifier: "UTC")!

        // Hebrew anchor date (after-sunset aware).
        var anchorAbs = HebrewDateEngine.absFrom(date: person.date, timeZone: tz)
        if person.afterSunset { anchorAbs += 1 }
        let anchor = HebrewCalc.abs2hebrew(anchorAbs)

        // Compare occurrences by calendar day (ignore time-of-day).
        let fromAbs = HebrewDateEngine.absFrom(date: from, timeZone: tz)
        let fromHebrew = HebrewCalc.abs2hebrew(fromAbs)

        var out: [Occurrence] = []
        let maxYears = count + 200
        var hyear = fromHebrew.year
        var i = 0
        while i < maxYears && out.count < count {
            defer { i += 1; hyear += 1 }
            let occ: (year: Int, month: Int, day: Int)?
            switch person.type {
            case .yahrzeit:
                occ = yahrzeit(hyear: hyear, anchor: anchor)
            case .birthday:
                occ = birthday(hyear: hyear, anchor: anchor)
            }
            guard let occ else { continue }   // undefined when hyear <= original year
            let occAbs = HebrewCalc.hebrew2abs(occ.year, occ.month, occ.day)
            if occAbs >= fromAbs {
                let g = HebrewCalc.abs2greg(occAbs)
                out.append(Occurrence(
                    gregorian: gregorianNoonUTC(g),
                    hebrew: HebrewDateEngine.describe(abs: occAbs),
                    hebrewYear: hyear
                ))
            }
        }
        return out
    }

    // MARK: - Yahrzeit rules (anniversary.js `getYahrzeitHD`)

    /// Returns the yahrzeit Hebrew date in `hyear`, or `nil` if `hyear` is on/before
    /// the original year.
    private static func yahrzeit(hyear: Int, anchor: (year: Int, month: Int, day: Int))
        -> (year: Int, month: Int, day: Int)? {
        if hyear <= anchor.year { return nil }

        var mm = anchor.month
        var dd = anchor.day

        if anchor.month == HebrewCalc.CHESHVAN && anchor.day == 30 && !HebrewCalc.longCheshvan(anchor.year + 1) {
            // Cheshvan 30: if the first anniversary was not Cheshvan 30, use the
            // day before Kislev 1.
            let h = HebrewCalc.abs2hebrew(HebrewCalc.hebrew2abs(hyear, HebrewCalc.KISLEV, 1) - 1)
            mm = h.month; dd = h.day
        } else if anchor.month == HebrewCalc.KISLEV && anchor.day == 30 && HebrewCalc.shortKislev(anchor.year + 1) {
            // Kislev 30: use the day before Tevet 1.
            let h = HebrewCalc.abs2hebrew(HebrewCalc.hebrew2abs(hyear, HebrewCalc.TEVET, 1) - 1)
            mm = h.month; dd = h.day
        } else if anchor.month == HebrewCalc.ADAR_II {
            // Adar II: use the same day in the last month of the year.
            mm = HebrewCalc.monthsInYear(hyear)
        } else if anchor.month == HebrewCalc.ADAR_I && anchor.day == 30 && !HebrewCalc.isLeapYear(hyear) {
            // Adar I 30 in a common year (Adar has 29 days): last day of Shevat.
            dd = 30; mm = HebrewCalc.SHVAT
        }

        // In all other cases, use the normal anniversary; advance to Rosh Chodesh
        // when the 30th does not exist this year.
        if mm == HebrewCalc.CHESHVAN && dd == 30 && !HebrewCalc.longCheshvan(hyear) {
            mm = HebrewCalc.KISLEV; dd = 1
        } else if mm == HebrewCalc.KISLEV && dd == 30 && HebrewCalc.shortKislev(hyear) {
            mm = HebrewCalc.TEVET; dd = 1
        }
        return (year: hyear, month: mm, day: dd)
    }

    // MARK: - Birthday / anniversary rules (anniversary.js `getBirthdayHD`)

    private static func birthday(hyear: Int, anchor: (year: Int, month: Int, day: Int))
        -> (year: Int, month: Int, day: Int)? {
        if hyear == anchor.year { return anchor }
        if hyear < anchor.year { return nil }

        let isOrigLeap = HebrewCalc.isLeapYear(anchor.year)
        var month = anchor.month
        var day = anchor.day

        if (month == HebrewCalc.ADAR_I && !isOrigLeap) || (month == HebrewCalc.ADAR_II && isOrigLeap) {
            month = HebrewCalc.monthsInYear(hyear)
        } else if month == HebrewCalc.CHESHVAN && day == 30 && !HebrewCalc.longCheshvan(hyear) {
            month = HebrewCalc.KISLEV; day = 1
        } else if month == HebrewCalc.KISLEV && day == 30 && HebrewCalc.shortKislev(hyear) {
            month = HebrewCalc.TEVET; day = 1
        } else if month == HebrewCalc.ADAR_I && day == 30 && isOrigLeap && !HebrewCalc.isLeapYear(hyear) {
            month = HebrewCalc.NISAN; day = 1
        }
        return (year: hyear, month: month, day: day)
    }

    // MARK: - Helpers

    private static func gregorianNoonUTC(_ g: (year: Int, month: Int, day: Int)) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = g.year; comps.month = g.month; comps.day = g.day
        comps.hour = 12; comps.minute = 0; comps.second = 0
        return cal.date(from: comps) ?? Date(timeIntervalSince1970: 0)
    }
}
