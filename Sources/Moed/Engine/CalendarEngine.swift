//
//  CalendarEngine.swift
//  Moed — CalendarEngine module
//
//  Jewish calendar events for a day or a range: holidays / Yom Tov (Israel vs.
//  Diaspora), fasts (with zmanim-derived start/end), Rosh Chodesh, Sefirat
//  HaOmer, Chanukah, the weekly parasha + haftara, and Daf Yomi.
//
//  Determinism & parity:
//   • The weekly sedra is a faithful port of `@hebcal/core` `sedra.ts` (the
//     14-kevia table + `lookup`), so Israel/Diaspora divergence and doubled
//     parshiyot are exactly the web engine's.
//   • Daf Yomi is a faithful port of `@hebcal/learning` `dafYomiBase.js`
//     (old cycle from 11 Sep 1923, new numbering from 24 Jun 1975, short
//     Shekalim for cycles ≤ 7).
//   • Holidays / fasts / Omer / Rosh Chodesh are computed directly from the
//     deterministic Hebrew date arithmetic (`HebrewCalc`), with the standard
//     Shabbat-postponement rules for fasts and the Israeli modern-holiday rules.
//   • Fast start/end, candle lighting and havdalah come from the sibling zmanim
//     engines (`ZmanimEngine` / `CandleEngine`, KosherCocoa/NOAA) so DST is
//     correct via IANA identifiers — never duplicated solar math.
//
//  100% offline, deterministic, no network.
//

import Foundation

public enum CalendarEngine {

    // MARK: - Public API (CONTRACTS §3.2)

    /// Every calendar detail for a single civil date at a location.
    public static func day(_ date: Date, geo: GeoContext, region: Region, lang: Lang) -> CalendarDay {
        let tz = TimeZone(identifier: geo.timeZone) ?? TimeZone(identifier: "UTC")!
        let abs = HebrewDateEngine.absFrom(date: date, timeZone: tz)
        let hebrew = HebrewDateEngine.describe(abs: abs)
        let il = inIsrael(region, geo)
        let leap = hebrew.isLeapYear

        // Raw events (holidays / fasts / Rosh Chodesh), then enrich fasts with
        // zmanim-derived timing.
        let raws = rawEvents(year: hebrew.year, month: hebrew.month, day: hebrew.day, leap: leap, il: il, abs: abs)
        let events: [CalEvent] = raws.map { raw in
            let fast: FastTiming? = raw.fastKind == .none ? nil
                : fastTiming(kind: raw.fastKind, date: date, geo: geo, tz: tz)
            return CalEvent(desc: raw.desc, category: raw.category,
                            title: LocalizedText(he: raw.he, fr: raw.fr, en: raw.en),
                            emoji: raw.emoji, isYomTov: raw.yomTov, fast: fast)
        }

        // Omer count (1..49) or nil.
        let omer = omerDay(month: hebrew.month, day: hebrew.day)

        // Daf Yomi (same R.D. day as the Hebrew date).
        let daf = dafYomiInfo(abs: abs)

        // Parasha only on Shabbat.
        let dow0 = HebrewCalc.dayOfWeek(abs)   // 0=Sun … 6=Sat
        let weeklyParasha: ParashaInfo? = dow0 == 6 ? CalendarEngine.parasha(week: date, region: region) : nil

        // Candle lighting / havdalah.
        let (candle, havdalah) = shabbatTimes(abs: abs, dow0: dow0, date: date, geo: geo, il: il, tz: tz)

        return CalendarDay(date: date, hebrew: hebrew, events: events, omer: omer,
                           dafYomi: daf, parasha: weeklyParasha,
                           candleLighting: candle, havdalah: havdalah)
    }

    /// Calendar details for each civil day in the inclusive `[start, end]` range.
    public static func range(start: Date, end: Date, geo: GeoContext, region: Region, lang: Lang) -> [CalendarDay] {
        let tz = TimeZone(identifier: geo.timeZone) ?? TimeZone(identifier: "UTC")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        // Anchor both bounds to noon to avoid DST midnight edge cases when stepping.
        guard var cur = noon(cal, start), let last = noon(cal, end) else { return [] }
        var out: [CalendarDay] = []
        while cur <= last {
            out.append(day(cur, geo: geo, region: region, lang: lang))
            guard let next = cal.date(byAdding: .day, value: 1, to: cur) else { break }
            cur = next
        }
        return out
    }

    /// Parasha + haftara for the Shabbat of the given week (Israel / Diaspora).
    /// Returns `nil` when that Shabbat carries a festival reading (no weekly parsha).
    public static func parasha(week of: Date, region: Region) -> ParashaInfo? {
        let tz = TimeZone(identifier: "UTC")!   // parasha is date-based, tz-agnostic here
        let abs = HebrewDateEngine.absFrom(date: of, timeZone: tz)
        let il = region == .il
        let saturday = HebrewCalc.dayOnOrBefore(6, abs + 6)
        guard let item = Sedra.lookup(abs: saturday, il: il) else { return nil }
        return parashaInfo(from: item)
    }

    /// Daf Yomi for a civil date (worldwide Bavli cycle).
    public static func dafYomi(_ date: Date) -> DafYomiInfo {
        let abs = HebrewDateEngine.absFrom(date: date, timeZone: TimeZone.current)
        return dafYomiInfo(abs: abs)
    }

    // MARK: - Region resolution

    private static func inIsrael(_ region: Region, _ geo: GeoContext) -> Bool {
        switch region {
        case .il: return true
        case .diaspora: return false
        case .auto: return geo.timeZone == "Asia/Jerusalem"
        }
    }

    // MARK: - Omer

    /// Day of the Omer (1..49) for a Nisan-based (month, day), else nil.
    /// 16 Nisan = 1 … 5 Sivan = 49.
    static func omerDay(month: Int, day: Int) -> Int? {
        switch month {
        case HebrewCalc.NISAN where day >= 16: return day - 15          // 16..30 → 1..15
        case HebrewCalc.IYYAR:                 return 15 + day          // 1..29  → 16..44
        case HebrewCalc.SIVAN where day <= 5:  return 44 + day          // 1..5   → 45..49
        default: return nil
        }
    }

    // MARK: - Candle lighting / havdalah

    private static func shabbatTimes(abs: Int, dow0: Int, date: Date, geo: GeoContext, il: Bool, tz: TimeZone)
        -> (candle: Date?, havdalah: Date?) {
        let todayYT = assurBemelacha(abs: abs, il: il)
        let tomorrowYT = assurBemelacha(abs: abs + 1, il: il)

        var candle: Date? = nil
        var havdalah: Date? = nil

        // Erev Shabbat (Friday) or an erev Yom Tov (not itself on Shabbat).
        if dow0 == 5 || (tomorrowYT && dow0 != 6) {
            candle = CandleEngine.candleLighting(date: date, geo: geo, candle: .auto,
                                                 cityMinutes: CandleEngine.defaultCandleMinutes)
        }
        // Motzaei Shabbat (Saturday) or a day Yom Tov ends (not into Shabbat).
        if dow0 == 6 || (todayYT && !tomorrowYT && dow0 != 5) {
            havdalah = CandleEngine.havdalah(date: date, geo: geo, tzeit: .degrees)
        }
        return (candle, havdalah)
    }

    // MARK: - Fast timing (zmanim-derived)

    private static func fastTiming(kind: FastKind, date: Date, geo: GeoContext, tz: TimeZone) -> FastTiming {
        let z = ZmanimEngine.zmanim(date: date, geo: geo, settings: Settings())
        let end = z.byKey[ZmanKey.tzeitHakochavim.rawValue]?.date
        let start: Date?
        if kind == .major25 {
            var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
            let prev = cal.date(byAdding: .day, value: -1, to: date) ?? date
            start = ZmanimEngine.zmanim(date: prev, geo: geo, settings: Settings())
                .byKey[ZmanKey.shkiaHachama.rawValue]?.date
        } else {
            start = z.byKey[ZmanKey.alotHashachar.rawValue]?.date
        }
        return FastTiming(start: start, end: end, is25Hour: kind == .major25)
    }

    // MARK: - Daf Yomi (port of @hebcal/learning dafYomiBase.js)

    private static let dafOsday = HebrewCalc.greg2abs(1923, 9, 11)   // 11 Sep 1923
    private static let dafNsday = HebrewCalc.greg2abs(1975, 6, 24)   // 24 Jun 1975

    /// Masechta (English, Hebrew, blatt) in Daf Yomi order (`bavli.json`).
    private static let shas: [(en: String, he: String, blatt: Int)] = [
        ("Berachot", "ברכות", 64), ("Shabbat", "שַׁבָּת", 157), ("Eruvin", "עירובין", 105),
        ("Pesachim", "פסחים", 121), ("Shekalim", "שקלים", 22), ("Yoma", "יומא", 88),
        ("Sukkah", "סוכה", 56), ("Beitzah", "ביצה", 40), ("Rosh Hashana", "רֹאשׁ הַשָּׁנָה", 35),
        ("Taanit", "תענית", 31), ("Megillah", "מגילה", 32), ("Moed Katan", "מועד קטן", 29),
        ("Chagigah", "חגיגה", 27), ("Yevamot", "יבמות", 122), ("Ketubot", "כתובות", 112),
        ("Nedarim", "נדרים", 91), ("Nazir", "נזיר", 66), ("Sotah", "סוטה", 49),
        ("Gitin", "גיטין", 90), ("Kiddushin", "קידושין", 82), ("Baba Kamma", "בבא קמא", 119),
        ("Baba Metzia", "בבא מציעא", 119), ("Baba Batra", "בבא בתרא", 176), ("Sanhedrin", "סנהדרין", 113),
        ("Makkot", "מכות", 24), ("Shevuot", "שבועות", 49), ("Avodah Zarah", "עבודה זרה", 76),
        ("Horayot", "הוריות", 14), ("Zevachim", "זבחים", 120), ("Menachot", "מנחות", 110),
        ("Chullin", "חולין", 142), ("Bechorot", "בכורות", 61), ("Arachin", "ערכין", 34),
        ("Temurah", "תמורה", 34), ("Keritot", "כריתות", 28), ("Meilah", "מעילה", 22),
        ("Kinnim", "קינים", 4), ("Tamid", "תמיד", 9), ("Midot", "מדות", 5), ("Niddah", "נדה", 73),
    ]

    static func dafYomiInfo(abs: Int) -> DafYomiInfo {
        // Guard against dates before the first cycle (11 Sep 1923).
        if abs < dafOsday {
            return DafYomiInfo(masechet: shas[0].en, daf: "1",
                               render: (en: "\(shas[0].en) 1", he: "\(shas[0].he) דף \(HebrewNumerals.gematriya(1))"))
        }
        let cno: Int
        let dno: Int
        if abs >= dafNsday {
            cno = 8 + HebrewCalc.fdiv(abs - dafNsday, 2711)
            dno = HebrewCalc.fmod(abs - dafNsday, 2711)
        } else {
            cno = 1 + HebrewCalc.fdiv(abs - dafOsday, 2702)
            dno = HebrewCalc.fmod(abs - dafOsday, 2702)
        }
        // Shekalim was 13 blatt for cycles ≤ 7.
        var blattTable = shas.map { $0.blatt }
        if cno <= 7 { blattTable[4] = 13 }

        var total = 0
        var blatt = 0
        var count = -1
        var j = 0
        let dafcnt = 40
        while j < dafcnt {
            count += 1
            total += blattTable[j] - 1
            if dno < total {
                blatt = blattTable[j] + 1 - (total - dno)
                switch count {
                case 36: blatt += 21   // Kinnim
                case 37: blatt += 24   // Tamid
                case 38: blatt += 32   // Midot
                default: break
                }
                j = 1 + dafcnt
            }
            j += 1
        }
        let m = shas[count]
        return DafYomiInfo(
            masechet: m.en,
            daf: String(blatt),
            render: (en: "\(m.en) \(blatt)", he: "\(m.he) דף \(HebrewNumerals.gematriya(blatt))")
        )
    }

    // MARK: - Parasha assembly

    /// 54 parshiyot (transliterated), index-aligned with the sedra engine.
    static let parshiot: [String] = [
        "Bereshit", "Noach", "Lech-Lecha", "Vayera", "Chayei Sara", "Toldot", "Vayetzei",
        "Vayishlach", "Vayeshev", "Miketz", "Vayigash", "Vayechi", "Shemot", "Vaera", "Bo",
        "Beshalach", "Yitro", "Mishpatim", "Terumah", "Tetzaveh", "Ki Tisa", "Vayakhel",
        "Pekudei", "Vayikra", "Tzav", "Shmini", "Tazria", "Metzora", "Achrei Mot", "Kedoshim",
        "Emor", "Behar", "Bechukotai", "Bamidbar", "Nasso", "Beha'alotcha", "Sh'lach", "Korach",
        "Chukat", "Balak", "Pinchas", "Matot", "Masei", "Devarim", "Vaetchanan", "Eikev",
        "Re'eh", "Shoftim", "Ki Teitzei", "Ki Tavo", "Nitzavim", "Vayeilech", "Ha'azinu",
    ]

    private static func parashaInfo(from item: SedraItem) -> ParashaInfo? {
        let name: String
        switch item {
        case .chag:
            return nil  // festival reading — no weekly parsha
        case .parsha(let idx):
            guard idx >= 0 && idx < parshiot.count else { return nil }
            name = parshiot[idx]
        case .doubled(let p1):
            guard p1 >= 0 && p1 + 1 < parshiot.count else { return nil }
            name = "\(parshiot[p1])-\(parshiot[p1 + 1])"
        }
        guard let r = HaftaraSephardic.reading(for: name) else {
            return ParashaInfo(name: (en: name, he: name), torah: nil, haftara: nil, haftaraSephardic: nil)
        }
        return ParashaInfo(name: (en: name, he: r.he), torah: r.torah,
                           haftara: r.ashkenazi, haftaraSephardic: r.sephardic)
    }

    // MARK: - Weekday helper

    private static func noon(_ cal: Calendar, _ date: Date) -> Date? {
        let ymd = cal.dateComponents([.year, .month, .day], from: date)
        var c = DateComponents()
        c.year = ymd.year; c.month = ymd.month; c.day = ymd.day
        c.hour = 12; c.minute = 0; c.second = 0
        return cal.date(from: c)
    }
}

// MARK: - Sedra (weekly parasha) — port of @hebcal/core sedra.ts

/// One slot of the annual sedra schedule: a single parsha (0-based index), a
/// doubled pair (index of the first parsha), or a festival reading (chag).
enum SedraItem: Equatable {
    case parsha(Int)
    case doubled(Int)
    case chag(String)
}

/// Faithful port of hebcal's `Sedra`: the 14-kevia table keyed by
/// `leap · rhDay · yearType [· il]`, plus the `lookup` that maps a Saturday's
/// R.D. day to its parasha slot.
enum Sedra {

    private static let INCOMPLETE = 0
    private static let REGULAR = 1
    private static let COMPLETE = 2

    // Chag reading labels (used only to flag festival Shabbatot).
    private static let RH = "Rosh Hashana"
    private static let YK = "Yom Kippur"
    private static let SUKKOT = "Sukkot"
    private static let CHMSUKOT = "Sukkot Shabbat Chol ha-Moed"
    private static let SHMINI = "Shmini Atzeret"
    private static let PESACH = "Pesach"
    private static let PESACH1 = "Pesach I"
    private static let CHMPESACH = "Pesach Shabbat Chol ha-Moed"
    private static let PESACH7 = "Pesach VII"
    private static let PESACH8 = "Pesach VIII"
    private static let SHAVUOT = "Shavuot"

    private static func seq(_ a: Int, _ b: Int) -> [SedraItem] {
        guard b >= a else { return [] }
        return (a...b).map { SedraItem.parsha($0) }
    }
    private static func D(_ p: Int) -> SedraItem { .doubled(p) }
    private static func P(_ p: Int) -> SedraItem { .parsha(p) }
    private static func C(_ s: String) -> SedraItem { .chag(s) }

    private static var yearStartVayeilech: [SedraItem] { [P(51), P(52), C(CHMSUKOT)] }
    private static var yearStartHaazinu: [SedraItem] { [P(52), C(YK), C(CHMSUKOT)] }
    private static var yearStartRH: [SedraItem] { [C(RH), P(52), C(SUKKOT), C(SHMINI)] }

    /// The 14 ordinary keviot + Israel/Diaspora variants + aliases (sedra.ts `types`).
    private static let types: [String: [SedraItem]] = {
        var t: [String: [SedraItem]] = [:]

        t["020"]  = yearStartVayeilech + seq(0, 20) + [D(21), P(23), P(24), C(CHMPESACH), P(25), D(26), D(28), P(30), D(31)] + seq(33, 40) + [D(41)] + seq(43, 49) + [D(50)]
        t["0220"] = yearStartVayeilech + seq(0, 20) + [D(21), P(23), P(24), C(CHMPESACH), P(25), D(26), D(28), P(30), D(31), P(33), C(SHAVUOT)] + seq(34, 37) + [D(38), P(40), D(41)] + seq(43, 49) + [D(50)]
        t["0510"] = yearStartHaazinu + seq(0, 20) + [D(21), P(23), P(24), C(PESACH1), C(PESACH8), P(25), D(26), D(28), P(30), D(31)] + seq(33, 40) + [D(41)] + seq(43, 50)
        t["0511"] = yearStartHaazinu + seq(0, 20) + [D(21), P(23), P(24), C(PESACH), P(25), D(26), D(28)] + seq(30, 40) + [D(41)] + seq(43, 50)
        t["052"]  = yearStartHaazinu + seq(0, 24) + [C(PESACH7), P(25), D(26), D(28), P(30), D(31)] + seq(33, 40) + [D(41)] + seq(43, 50)
        t["070"]  = yearStartRH + seq(0, 20) + [D(21), P(23), P(24), C(PESACH7), P(25), D(26), D(28), P(30), D(31)] + seq(33, 40) + [D(41)] + seq(43, 50)
        t["072"]  = yearStartRH + seq(0, 20) + [D(21), P(23), P(24), C(CHMPESACH), P(25), D(26), D(28), P(30), D(31)] + seq(33, 40) + [D(41)] + seq(43, 49) + [D(50)]
        t["1200"] = yearStartVayeilech + seq(0, 27) + [C(CHMPESACH)] + seq(28, 33) + [C(SHAVUOT)] + seq(34, 37) + [D(38), P(40), D(41)] + seq(43, 49) + [D(50)]
        t["1201"] = yearStartVayeilech + seq(0, 27) + [C(CHMPESACH)] + seq(28, 40) + [D(41)] + seq(43, 49) + [D(50)]
        t["1220"] = yearStartVayeilech + seq(0, 27) + [C(PESACH1), C(PESACH8)] + seq(28, 40) + [D(41)] + seq(43, 50)
        t["1221"] = yearStartVayeilech + seq(0, 27) + [C(PESACH)] + seq(28, 50)
        t["150"]  = yearStartHaazinu + seq(0, 28) + [C(PESACH7)] + seq(29, 50)
        t["152"]  = yearStartHaazinu + seq(0, 28) + [C(CHMPESACH)] + seq(29, 49) + [D(50)]
        t["170"]  = yearStartRH + seq(0, 27) + [C(CHMPESACH)] + seq(28, 40) + [D(41)] + seq(43, 49) + [D(50)]
        t["1720"] = yearStartRH + seq(0, 27) + [C(CHMPESACH)] + seq(28, 33) + [C(SHAVUOT)] + seq(34, 37) + [D(38), P(40), D(41)] + seq(43, 49) + [D(50)]

        // Aliases (sedra.ts).
        t["0221"] = t["020"]
        t["0310"] = t["0220"]
        t["0311"] = t["020"]
        t["1310"] = t["1220"]
        t["1311"] = t["1221"]
        t["1721"] = t["170"]
        return t
    }()

    private static func yearType(_ hyear: Int) -> Int {
        let longC = HebrewCalc.longCheshvan(hyear)
        let shortK = HebrewCalc.shortKislev(hyear)
        if longC && !shortK { return COMPLETE }
        if !longC && shortK { return INCOMPLETE }
        return REGULAR
    }

    /// The annual schedule + first-Saturday R.D. for a Hebrew year / rite.
    private static func schedule(hyear: Int, il: Bool) -> (array: [SedraItem], firstSaturday: Int) {
        let rh = HebrewCalc.newYear(hyear)
        let rhDay = HebrewCalc.dayOfWeek(rh) + 1        // 1=Sun … 7=Sat
        let firstSaturday = HebrewCalc.dayOnOrBefore(6, rh + 6)
        let leap = HebrewCalc.isLeapYear(hyear) ? 1 : 0
        let type = yearType(hyear)
        var key = "\(leap)\(rhDay)\(type)"
        if types[key] == nil {
            key += il ? "1" : "0"
        }
        let arr = types[key] ?? []
        return (arr, firstSaturday)
    }

    /// Parasha slot for the first Saturday on/after the R.D. `abs`.
    static func lookup(abs: Int, il: Bool) -> SedraItem? {
        let saturday = HebrewCalc.dayOnOrBefore(6, abs + 6)
        // Resolve which Hebrew year's schedule contains this Saturday.
        var hyear = HebrewCalc.abs2hebrew(saturday).year
        for _ in 0..<3 {
            let sched = schedule(hyear: hyear, il: il)
            let weekNum = (saturday - sched.firstSaturday) / 7
            if weekNum < 0 { hyear -= 1; continue }
            if weekNum >= sched.array.count { hyear += 1; continue }
            return sched.array[weekNum]
        }
        return nil
    }
}

// MARK: - Holidays / fasts / Rosh Chodesh (deterministic, from HebrewCalc)

extension CalendarEngine {

    enum FastKind: Equatable { case none, minor, major25 }

    /// A holiday/fast/Rosh-Chodesh before zmanim enrichment.
    struct RawEvent {
        let desc: String
        let category: EventCategory
        let he: String
        let fr: String
        let en: String
        let emoji: String?
        let yomTov: Bool
        let fastKind: FastKind
        init(_ desc: String, _ category: EventCategory, he: String, fr: String, en: String,
             emoji: String? = nil, yomTov: Bool = false, fastKind: FastKind = .none) {
            self.desc = desc; self.category = category
            self.he = he; self.fr = fr; self.en = en
            self.emoji = emoji; self.yomTov = yomTov; self.fastKind = fastKind
        }
    }

    /// Weekday (0=Sun … 6=Sat) of a Hebrew date.
    private static func dow(_ y: Int, _ m: Int, _ d: Int) -> Int {
        HebrewCalc.dayOfWeek(HebrewCalc.hebrew2abs(y, m, d))
    }

    /// Whether the Hebrew date at `abs` is a work-prohibited Yom Tov day.
    static func assurBemelacha(abs: Int, il: Bool) -> Bool {
        let h = HebrewCalc.abs2hebrew(abs)
        switch h.month {
        case HebrewCalc.TISHREI:
            if [1, 2, 10, 15, 22].contains(h.day) { return true }
            if !il && (h.day == 16 || h.day == 23) { return true }
            return false
        case HebrewCalc.NISAN:
            if h.day == 15 || h.day == 21 { return true }
            if !il && (h.day == 16 || h.day == 22) { return true }
            return false
        case HebrewCalc.SIVAN:
            if h.day == 6 { return true }
            if !il && h.day == 7 { return true }
            return false
        default:
            return false
        }
    }

    /// All raw calendar events for a Hebrew (year, month, day).
    static func rawEvents(year y: Int, month m: Int, day d: Int, leap: Bool, il: Bool, abs: Int) -> [RawEvent] {
        var out: [RawEvent] = []
        let wd = HebrewCalc.dayOfWeek(abs)   // 0=Sun … 6=Sat
        let adarMonth = leap ? HebrewCalc.ADAR_II : HebrewCalc.ADAR_I

        // ---- Rosh Chodesh ----
        if d == 1 && m != HebrewCalc.TISHREI {
            let name = HebrewMonthTables.monthName(m, isLeapYear: leap)
            out.append(RawEvent("Rosh Chodesh \(name.en)", .roshchodesh,
                                he: "רֹאשׁ חוֹדֶשׁ \(name.he)", fr: "Roch Hodech \(name.fr)",
                                en: "Rosh Chodesh \(name.en)", emoji: "🌙"))
        }
        if d == 30 {
            let nextM = m + 1
            let name = HebrewMonthTables.monthName(nextM, isLeapYear: leap)
            out.append(RawEvent("Rosh Chodesh \(name.en)", .roshchodesh,
                                he: "רֹאשׁ חוֹדֶשׁ \(name.he)", fr: "Roch Hodech \(name.fr)",
                                en: "Rosh Chodesh \(name.en)", emoji: "🌙"))
        }

        switch m {
        // ================= TISHREI =================
        case HebrewCalc.TISHREI:
            switch d {
            case 1: out.append(RawEvent("Rosh Hashana", .yomtov, he: "רֹאשׁ הַשָּׁנָה", fr: "Roch Hachana", en: "Rosh Hashana", emoji: "🍏", yomTov: true))
            case 2: out.append(RawEvent("Rosh Hashana II", .yomtov, he: "רֹאשׁ הַשָּׁנָה ב׳", fr: "Roch Hachana II", en: "Rosh Hashana II", emoji: "🍏", yomTov: true))
            case 3 where wd != 6: out.append(fast("Tzom Gedaliah", he: "צוֹם גְּדַלְיָה", fr: "Jeûne de Guedalia", en: "Tzom Gedaliah"))
            case 4 where wd == 0: out.append(fast("Tzom Gedaliah", he: "צוֹם גְּדַלְיָה", fr: "Jeûne de Guedalia", en: "Tzom Gedaliah"))
            case 10: out.append(RawEvent("Yom Kippur", .yomtov, he: "יוֹם כִּפּוּר", fr: "Yom Kippour", en: "Yom Kippur", yomTov: true, fastKind: .major25))
            case 15: out.append(RawEvent("Sukkot I", .yomtov, he: "סוּכּוֹת א׳", fr: "Souccot I", en: "Sukkot I", emoji: "🌿", yomTov: true))
            case 16:
                if il { out.append(cholHamoed("Sukkot", he: "סוּכּוֹת", fr: "Souccot")) }
                else { out.append(RawEvent("Sukkot II", .yomtov, he: "סוּכּוֹת ב׳", fr: "Souccot II", en: "Sukkot II", emoji: "🌿", yomTov: true)) }
            case 17, 18, 19, 20: out.append(cholHamoed("Sukkot", he: "סוּכּוֹת", fr: "Souccot"))
            case 21: out.append(RawEvent("Hoshana Raba", .holiday, he: "הוֹשַׁעְנָא רַבָּה", fr: "Hochana Rabba", en: "Hoshana Raba", emoji: "🌿"))
            case 22:
                if il { out.append(RawEvent("Shmini Atzeret", .yomtov, he: "שְׁמִינִי עֲצֶרֶת / שִׂמְחַת תּוֹרָה", fr: "Chemini Atséret / Simhat Torah", en: "Shmini Atzeret / Simchat Torah", emoji: "📜", yomTov: true)) }
                else { out.append(RawEvent("Shmini Atzeret", .yomtov, he: "שְׁמִינִי עֲצֶרֶת", fr: "Chemini Atséret", en: "Shmini Atzeret", yomTov: true)) }
            case 23 where !il: out.append(RawEvent("Simchat Torah", .yomtov, he: "שִׂמְחַת תּוֹרָה", fr: "Simhat Torah", en: "Simchat Torah", emoji: "📜", yomTov: true))
            default: break
            }

        // ================= KISLEV / TEVET (Chanukah) =================
        case HebrewCalc.KISLEV:
            if d >= 25, let n = chanukahDay(y: y, m: m, d: d) {
                out.append(chanukah(n))
            }
        case HebrewCalc.TEVET:
            if let n = chanukahDay(y: y, m: m, d: d) { out.append(chanukah(n)) }
            if d == 10 { out.append(fast("Asara B'Tevet", he: "עֲשָׂרָה בְּטֵבֵת", fr: "Jeûne du 10 Tévet", en: "Asara B'Tevet")) }

        // ================= SHVAT =================
        case HebrewCalc.SHVAT:
            if d == 15 { out.append(RawEvent("Tu BiShvat", .holiday, he: "ט״וּ בִּשְׁבָט", fr: "Tou BiChvat", en: "Tu BiShvat", emoji: "🌳")) }

        // ================= ADAR I (leap: Purim Katan) =================
        case HebrewCalc.ADAR_I where leap:
            if d == 14 { out.append(RawEvent("Purim Katan", .holiday, he: "פּוּרִים קָטָן", fr: "Pourim Katan", en: "Purim Katan")) }
            if d == 15 { out.append(RawEvent("Shushan Purim Katan", .holiday, he: "שׁוּשַׁן פּוּרִים קָטָן", fr: "Chouchan Pourim Katan", en: "Shushan Purim Katan")) }

        default:
            break
        }

        // ---- Adar / Adar II (Ta'anit Esther, Purim) ----
        if m == adarMonth {
            if (d == 13 && wd != 6) || (d == 11 && wd == 4) {
                out.append(fast("Ta'anit Esther", he: "תַּעֲנִית אֶסְתֵּר", fr: "Jeûne d'Esther", en: "Ta'anit Esther"))
            }
            if d == 14 { out.append(RawEvent("Purim", .holiday, he: "פּוּרִים", fr: "Pourim", en: "Purim", emoji: "🎭")) }
            if d == 15 { out.append(RawEvent("Shushan Purim", .holiday, he: "שׁוּשַׁן פּוּרִים", fr: "Chouchan Pourim", en: "Shushan Purim", emoji: "🎭")) }
        }

        // ================= NISAN =================
        if m == HebrewCalc.NISAN {
            switch d {
            case 14 where wd != 6: out.append(fast("Ta'anit Bechorot", he: "תַּעֲנִית בְּכוֹרוֹת", fr: "Jeûne des premiers-nés", en: "Ta'anit Bechorot"))
            case 12 where wd == 4: out.append(fast("Ta'anit Bechorot", he: "תַּעֲנִית בְּכוֹרוֹת", fr: "Jeûne des premiers-nés", en: "Ta'anit Bechorot"))
            case 15: out.append(RawEvent("Pesach I", .yomtov, he: "פֶּסַח א׳", fr: "Pessah I", en: "Pesach I", emoji: "🫓", yomTov: true))
            case 16:
                if il { out.append(cholHamoed("Pesach", he: "פֶּסַח", fr: "Pessah")) }
                else { out.append(RawEvent("Pesach II", .yomtov, he: "פֶּסַח ב׳", fr: "Pessah II", en: "Pesach II", emoji: "🫓", yomTov: true)) }
            case 17, 18, 19, 20: out.append(cholHamoed("Pesach", he: "פֶּסַח", fr: "Pessah"))
            case 21: out.append(RawEvent("Pesach VII", .yomtov, he: "פֶּסַח ז׳", fr: "Pessah VII", en: "Pesach VII", emoji: "🫓", yomTov: true))
            case 22 where !il: out.append(RawEvent("Pesach VIII", .yomtov, he: "פֶּסַח ח׳", fr: "Pessah VIII", en: "Pesach VIII", emoji: "🫓", yomTov: true))
            default: break
            }
            // Yom HaShoah (27 Nisan; postponed: Fri→26, Sun→28).
            let dow27 = dow(y, HebrewCalc.NISAN, 27)
            if (d == 27 && dow27 != 5 && dow27 != 0)
                || (d == 26 && dow27 == 5)
                || (d == 28 && dow27 == 0) {
                out.append(RawEvent("Yom HaShoah", .holiday, he: "יוֹם הַשּׁוֹאָה", fr: "Yom HaShoah", en: "Yom HaShoah"))
            }
        }

        // ================= IYYAR =================
        if m == HebrewCalc.IYYAR {
            if d == 14 { out.append(RawEvent("Pesach Sheni", .holiday, he: "פֶּסַח שֵׁנִי", fr: "Pessah Cheni", en: "Pesach Sheni")) }
            if d == 18 { out.append(RawEvent("Lag BaOmer", .holiday, he: "ל״ג בָּעוֹמֶר", fr: "Lag BaOmer", en: "Lag BaOmer", emoji: "🔥")) }
            if d == 28 { out.append(RawEvent("Yom Yerushalayim", .holiday, he: "יוֹם יְרוּשָׁלַיִם", fr: "Yom Yérouchalayim", en: "Yom Yerushalayim")) }
            // Yom HaZikaron / Yom HaAtzmaut (anchored on 5 Iyar, Israeli rules).
            let dow5 = dow(y, HebrewCalc.IYYAR, 5)
            let (atz, zik): (Int, Int)
            switch dow5 {
            case 2: (atz, zik) = (6, 5)   // Mon → push forward
            case 5: (atz, zik) = (4, 3)   // Fri → pull back
            case 6: (atz, zik) = (3, 2)   // Sat → pull back
            default: (atz, zik) = (5, 4)
            }
            if d == zik { out.append(RawEvent("Yom HaZikaron", .holiday, he: "יוֹם הַזִּכָּרוֹן", fr: "Yom HaZikaron", en: "Yom HaZikaron")) }
            if d == atz { out.append(RawEvent("Yom HaAtzmaut", .holiday, he: "יוֹם הָעַצְמָאוּת", fr: "Yom HaAtsmaout", en: "Yom HaAtzmaut", emoji: "🇮🇱")) }
        }

        // ================= SIVAN =================
        if m == HebrewCalc.SIVAN {
            if d == 6 { out.append(RawEvent("Shavuot I", .yomtov, he: "שָׁבוּעוֹת א׳", fr: "Chavouot I", en: "Shavuot I", emoji: "🌾", yomTov: true)) }
            if d == 7 && !il { out.append(RawEvent("Shavuot II", .yomtov, he: "שָׁבוּעוֹת ב׳", fr: "Chavouot II", en: "Shavuot II", emoji: "🌾", yomTov: true)) }
        }

        // ================= TAMUZ =================
        if m == HebrewCalc.TAMUZ {
            if (d == 17 && wd != 6) || (d == 18 && wd == 0) {
                out.append(fast("Tzom Tammuz", he: "שִׁבְעָה עָשָׂר בְּתַמּוּז", fr: "Jeûne du 17 Tamouz", en: "Tzom Tammuz"))
            }
        }

        // ================= AV =================
        if m == HebrewCalc.AV {
            if (d == 9 && wd != 6) || (d == 10 && wd == 0) {
                out.append(RawEvent("Tish'a B'Av", .fast, he: "תִּשְׁעָה בְּאָב", fr: "Ticha BeAv", en: "Tish'a B'Av", fastKind: .major25))
            }
            if d == 15 { out.append(RawEvent("Tu B'Av", .holiday, he: "ט״וּ בְּאָב", fr: "Tou BeAv", en: "Tu B'Av", emoji: "❤️")) }
        }

        return out
    }

    // MARK: Event builders

    private static func fast(_ desc: String, he: String, fr: String, en: String) -> RawEvent {
        RawEvent(desc, .fast, he: he, fr: fr, en: en, fastKind: .minor)
    }

    private static func cholHamoed(_ base: String, he: String, fr: String) -> RawEvent {
        RawEvent("\(base) Chol ha-Moed", .holiday,
                 he: "חוֹל הַמּוֹעֵד \(he)", fr: "Hol HaMoed \(fr)", en: "\(base) Chol ha-Moed", emoji: "🌿")
    }

    private static func chanukah(_ n: Int) -> RawEvent {
        RawEvent("Chanukah: Day \(n)", .holiday,
                 he: "חֲנוּכָּה יוֹם \(HebrewNumerals.gematriya(n))",
                 fr: "Hanoucca — jour \(n)", en: "Chanukah: Day \(n)", emoji: "🕎")
    }

    /// Chanukah day number (1..8) for a Kislev/Tevet date, else nil.
    private static func chanukahDay(y: Int, m: Int, d: Int) -> Int? {
        if m == HebrewCalc.KISLEV {
            let n = d - 24                       // 25 Kislev → 1
            return (1...8).contains(n) ? n : nil
        }
        if m == HebrewCalc.TEVET {
            let kislevDays = HebrewCalc.daysInMonth(HebrewCalc.KISLEV, y)   // 29 or 30
            let n = (kislevDays - 24) + d
            return (1...8).contains(n) ? n : nil
        }
        return nil
    }
}
