//
//  HebrewDateEngine.swift
//  Moed — CalendarEngine module
//
//  Deterministic Gregorian ⇄ Hebrew conversion, molad, and the low-level Hebrew
//  calendar arithmetic shared by the whole CalendarEngine module.
//
//  The arithmetic (`HebrewCalc`) is a faithful Swift port of the Maimonides /
//  Dershowitz–Reingold "Calendrical Calculations" routines used by `@hebcal/core`
//  (`@hebcal/hdate` `hdateBase.js`, `greg.js`, `molad.js`). Porting hebcal's own
//  functions guarantees bit-for-bit parity with the web engine and the validated
//  reference — the four dehiyot, embolismic (leap) years, long-Cheshvan /
//  short-Kislev, and molad are all handled exactly.
//
//  Month numbering is Nisan-based (NISAN = 1 … TISHREI = 7 … ADAR_II = 13).
//  All integer divisions/moduli use floored semantics (`fdiv` / `fmod`) so the
//  results match JavaScript's `Math.floor` / `%`-on-nonneg exactly.
//
//  100% offline, deterministic, no network. Foundation only.
//

import Foundation

// MARK: - Low-level Hebrew calendar arithmetic (module-internal)

/// Faithful port of `@hebcal/hdate`. R.D. (Rata Die) fixed days: R.D. 1 is the
/// proleptic-Gregorian Monday 1 January 1 CE.
enum HebrewCalc {

    // Nisan-based month constants.
    static let NISAN = 1, IYYAR = 2, SIVAN = 3, TAMUZ = 4, AV = 5, ELUL = 6
    static let TISHREI = 7, CHESHVAN = 8, KISLEV = 9, TEVET = 10, SHVAT = 11
    static let ADAR_I = 12, ADAR_II = 13

    /// R.D. of Hebrew (1, 1, 1) minus 1 (hebcal `EPOCH`).
    static let EPOCH = -1373428
    /// Average Hebrew year length used to seed the year search.
    static let AVG_HEBYEAR_DAYS = 365.24682220597794

    // MARK: Floored integer helpers (match JS Math.floor division / modulo)

    @inline(__always) static func fdiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b, r = a % b
        return (r != 0 && (r < 0) != (b < 0)) ? q - 1 : q
    }

    @inline(__always) static func fmod(_ a: Int, _ b: Int) -> Int {
        let r = a % b
        return (r != 0 && (r < 0) != (b < 0)) ? r + b : r
    }

    // MARK: Year structure

    /// True if the Hebrew year is embolismic (13 months).
    static func isLeapYear(_ year: Int) -> Bool {
        fmod(1 + year * 7, 19) < 7
    }

    /// Months in the Hebrew year (12 or 13).
    static func monthsInYear(_ year: Int) -> Int {
        12 + (isLeapYear(year) ? 1 : 0)
    }

    /// Days in a Hebrew month (29 or 30) for a given year.
    static func daysInMonth(_ month: Int, _ year: Int) -> Int {
        switch month {
        case IYYAR, TAMUZ, ELUL, TEVET, ADAR_II:
            return 29
        default:
            break
        }
        if (month == ADAR_I && !isLeapYear(year)) ||
            (month == CHESHVAN && !longCheshvan(year)) ||
            (month == KISLEV && shortKislev(year)) {
            return 29
        }
        return 30
    }

    /// Days from the Sunday prior to the calendar's start to the mean conjunction
    /// (molad) of Tishrei of `year`, after applying the four dehiyot.
    static func elapsedDays(_ year: Int) -> Int {
        let prevYear = year - 1
        let mElapsed = 235 * fdiv(prevYear, 19)
            + 12 * fmod(prevYear, 19)
            + fdiv(fmod(prevYear, 19) * 7 + 1, 19)
        let pElapsed = 204 + 793 * fmod(mElapsed, 1080)
        let hElapsed = 5
            + 12 * mElapsed
            + 793 * fdiv(mElapsed, 1080)
            + fdiv(pElapsed, 1080)
        let parts = fmod(pElapsed, 1080) + 1080 * fmod(hElapsed, 24)
        let day = 1 + 29 * mElapsed + fdiv(hElapsed, 24)

        var altDay = day
        if parts >= 19440
            || (fmod(day, 7) == 2 && parts >= 9924 && !isLeapYear(year))
            || (fmod(day, 7) == 1 && parts >= 16789 && isLeapYear(prevYear)) {
            altDay += 1
        }
        let mod7 = fmod(altDay, 7)
        if mod7 == 0 || mod7 == 3 || mod7 == 5 {
            return altDay + 1
        }
        return altDay
    }

    /// R.D. of the start (1 Tishrei) of the Hebrew `year`.
    static func newYear(_ year: Int) -> Int { EPOCH + elapsedDays(year) }

    /// Number of days in the Hebrew year (353–355 common, 383–385 leap).
    static func daysInYear(_ year: Int) -> Int { elapsedDays(year + 1) - elapsedDays(year) }

    static func longCheshvan(_ year: Int) -> Bool { fmod(daysInYear(year), 10) == 5 }
    static func shortKislev(_ year: Int) -> Bool { fmod(daysInYear(year), 10) == 3 }

    // MARK: Hebrew ⇄ R.D.

    /// Converts a Hebrew date to R.D. fixed days.
    static func hebrew2abs(_ year: Int, _ month: Int, _ day: Int) -> Int {
        var tempabs = day
        if month < TISHREI {
            var m = TISHREI
            let last = monthsInYear(year)
            while m <= last { tempabs += daysInMonth(m, year); m += 1 }
            m = NISAN
            while m < month { tempabs += daysInMonth(m, year); m += 1 }
        } else {
            var m = TISHREI
            while m < month { tempabs += daysInMonth(m, year); m += 1 }
        }
        return EPOCH + elapsedDays(year) + tempabs - 1
    }

    /// Converts R.D. fixed days to a Hebrew (year, month, day).
    static func abs2hebrew(_ abs: Int) -> (year: Int, month: Int, day: Int) {
        var year = Int((Double(abs - EPOCH) / AVG_HEBYEAR_DAYS).rounded(.down))
        while newYear(year) <= abs { year += 1 }
        year -= 1
        var month = abs < hebrew2abs(year, NISAN, 1) ? TISHREI : NISAN
        while abs > hebrew2abs(year, month, daysInMonth(month, year)) { month += 1 }
        let day = 1 + abs - hebrew2abs(year, month, 1)
        return (year, month, day)
    }

    // MARK: Gregorian ⇄ R.D. (proleptic Gregorian)

    static func isGregLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0)
    }

    /// R.D. of a proleptic-Gregorian (year, month 1-12, day).
    static func greg2abs(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let py = year - 1
        return 365 * py
            + fdiv(py, 4) - fdiv(py, 100) + fdiv(py, 400)
            + fdiv(367 * month - 362, 12)
            + (month <= 2 ? 0 : (isGregLeapYear(year) ? -1 : -2))
            + day
    }

    private static func yearFromFixed(_ abs: Int) -> Int {
        let l0 = abs - 1
        let n400 = fdiv(l0, 146097)
        let d1 = fmod(l0, 146097)
        let n100 = fdiv(d1, 36524)
        let d2 = fmod(d1, 36524)
        let n4 = fdiv(d2, 1461)
        let d3 = fmod(d2, 1461)
        let n1 = fdiv(d3, 365)
        let year = 400 * n400 + 100 * n100 + 4 * n4 + n1
        return (n100 != 4 && n1 != 4) ? year + 1 : year
    }

    /// Converts R.D. fixed days to a proleptic-Gregorian (year, month, day) —
    /// the daytime portion of the date.
    static func abs2greg(_ abs: Int) -> (year: Int, month: Int, day: Int) {
        let year = yearFromFixed(abs)
        let priorDays = abs - greg2abs(year, 1, 1)
        let correction = abs < greg2abs(year, 3, 1) ? 0 : (isGregLeapYear(year) ? 1 : 2)
        let month = fdiv(12 * (priorDays + correction) + 373, 367)
        let day = abs - greg2abs(year, month, 1) + 1
        return (year, month, day)
    }

    // MARK: Weekday

    /// Day of week for an R.D. day: 0 = Sunday … 6 = Saturday.
    static func dayOfWeek(_ abs: Int) -> Int { fmod(abs, 7) }

    /// R.D. of the latest `dayOfWeek` (0=Sun … 6=Sat) that is ≤ `abs`.
    static func dayOnOrBefore(_ dow: Int, _ abs: Int) -> Int {
        abs - fmod(abs - dow, 7)
    }

    // MARK: Molad

    /// Mean lunar conjunction of a Hebrew month (ported from `molad.js`).
    /// `dayOfWeek` 0=Sun; `hour` 0-23; `chalakim` 0-17 (1080 chalakim / hour).
    static func molad(_ year: Int, _ month: Int)
        -> (rd: Int, dayOfWeek: Int, hour: Int, minutes: Int, chalakim: Int) {
        var mAdj = month - 7
        if mAdj < 0 { mAdj += monthsInYear(year) }
        let mElapsed = 235 * fdiv(year - 1, 19)
            + 12 * fmod(year - 1, 19)
            + fdiv(7 * fmod(year - 1, 19) + 1, 19)
            + mAdj
        let pElapsed = 204 + 793 * fmod(mElapsed, 1080)
        let hElapsed = 5
            + 12 * mElapsed
            + 793 * fdiv(mElapsed, 1080)
            + fdiv(pElapsed, 1080)
            - 6
        let parts = fmod(pElapsed, 1080) + 1080 * fmod(hElapsed, 24)
        let chalakim = fmod(parts, 1080)
        let day = 1 + 29 * mElapsed + fdiv(hElapsed, 24)
        return (rd: EPOCH + day,
                dayOfWeek: fmod(day, 7),
                hour: fmod(hElapsed, 24),
                minutes: fdiv(chalakim, 18),
                chalakim: fmod(chalakim, 18))
    }
}

// MARK: - Public engine (CONTRACTS §3.2)

public enum HebrewDateEngine {

    /// Calendars keyed by IANA identifier (built once; thread-safe reuse).
    private static func gregorianCalendar(_ timeZone: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    private static let utc = TimeZone(identifier: "UTC")!
    private static let jerusalem = TimeZone(identifier: "Asia/Jerusalem") ?? TimeZone(identifier: "UTC")!

    /// Converts a Gregorian instant to its Hebrew date, in the location's time
    /// zone. When `afterSunset` is true the Hebrew day is advanced by one
    /// (the Hebrew day begins at sunset).
    public static func convert(_ date: Date, afterSunset: Bool, geo: GeoContext, lang: Lang) -> HebrewDateResult {
        let tz = TimeZone(identifier: geo.timeZone) ?? utc
        let comps = gregorianCalendar(tz).dateComponents([.year, .month, .day], from: date)
        let g = greg2absComponents(comps)
        var abs = HebrewCalc.greg2abs(g.year, g.month, g.day)
        if afterSunset { abs += 1 }
        return describe(abs: abs)
    }

    /// Converts a Hebrew date to its Gregorian `Date` (daytime portion, noon UTC).
    /// Returns `nil` when the (day, month, year) triple is out of range.
    public static func toGregorian(year: Int, month: Int, day: Int) -> Date? {
        guard year >= 1, month >= 1, month <= HebrewCalc.monthsInYear(year) else { return nil }
        guard day >= 1, day <= HebrewCalc.daysInMonth(month, year) else { return nil }
        let abs = HebrewCalc.hebrew2abs(year, month, day)
        let g = HebrewCalc.abs2greg(abs)
        var comps = DateComponents()
        comps.year = g.year; comps.month = g.month; comps.day = g.day
        comps.hour = 12; comps.minute = 0; comps.second = 0
        return gregorianCalendar(utc).date(from: comps)
    }

    /// Mean molad (conjunction) of a Hebrew month, as an absolute instant on the
    /// Jerusalem civil clock (the traditional reference for the molad).
    public static func molad(year: Int, month: Int) -> Date {
        let m = HebrewCalc.molad(year, month)
        let g = HebrewCalc.abs2greg(m.rd)
        var comps = DateComponents()
        comps.year = g.year; comps.month = g.month; comps.day = g.day
        comps.hour = m.hour; comps.minute = m.minutes; comps.second = 0
        return gregorianCalendar(jerusalem).date(from: comps)
            ?? Date(timeIntervalSince1970: 0)
    }

    // MARK: Internal helpers (shared with CalendarEngine / PersonalEngine)

    /// Builds a `HebrewDateResult` from an R.D. day.
    static func describe(abs: Int) -> HebrewDateResult {
        let h = HebrewCalc.abs2hebrew(abs)
        let leap = HebrewCalc.isLeapYear(h.year)
        let dow0 = HebrewCalc.dayOfWeek(abs)          // 0 = Sunday
        return HebrewDateResult(
            year: h.year,
            month: h.month,
            day: h.day,
            dayOfWeek: dow0 + 1,                       // contract: 1 = Sunday … 7 = Saturday
            isLeapYear: leap,
            monthName: HebrewMonthTables.monthName(h.month, isLeapYear: leap),
            weekdayName: HebrewMonthTables.weekdayName(dow0),
            yearHebrew: HebrewNumerals.gematriya(h.year),
            dayHebrew: HebrewNumerals.gematriya(h.day)
        )
    }

    /// R.D. day for a Gregorian instant, in a given time zone.
    static func absFrom(date: Date, timeZone: TimeZone) -> Int {
        let comps = gregorianCalendar(timeZone).dateComponents([.year, .month, .day], from: date)
        let g = greg2absComponents(comps)
        return HebrewCalc.greg2abs(g.year, g.month, g.day)
    }

    private static func greg2absComponents(_ comps: DateComponents) -> (year: Int, month: Int, day: Int) {
        (year: comps.year ?? 1970, month: comps.month ?? 1, day: comps.day ?? 1)
    }
}
