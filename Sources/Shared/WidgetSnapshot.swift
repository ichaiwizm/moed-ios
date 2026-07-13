//
//  WidgetSnapshot.swift
//  Moed — Shared (double target membership : Moed + MoedWidgets)
//
//  RECALCUL LOCAL des widgets (CONTRACTS §4.4 / DESIGN §11).
//
//  Le `TimelineProvider` de chaque widget ne lit AUCUN réseau : il recharge les
//  préférences depuis `UserDefaults.standard` (`SettingsStore`) et
//  rejoue les moteurs déterministes offline (`ZmanimEngine`, `CandleEngine`,
//  `CalendarEngine`, `HebrewDateEngine`) — exactement comme `AppState`, mais
//  sans horloge ni état observable. Ces moteurs et `StaticData` sont partagés
//  via double appartenance de cible (Sources/Shared + Sources/Engine + Data),
//  d'où une PARITÉ de calcul stricte entre l'app et ses widgets (mêmes shitot,
//  mêmes règles) : les gens allument selon ces heures — zéro divergence.
//
//  Ce fichier ne dépend que de Foundation : ce sont des structures de DONNÉES
//  (portées par les `TimelineEntry`) + une façade de calcul pure. Toute la
//  présentation (couleurs, polices, RTL) vit dans les autres fichiers Shared et
//  dans la cible MoedWidgets.
//

import Foundation

// MARK: - Contexte partagé (préférences + géo + langue)

/// Instantané du contexte utilisateur au moment du calcul, dérivé des préférences.
struct WidgetContext: Sendable {
    let settings: Settings
    let city: City
    let geo: GeoContext
    let region: Region
    let lang: Lang
}

// MARK: - Snapshots par widget (payload des entries)

/// Données du widget « Allumage ».
struct CandleSnapshot: Sendable {
    let cityName: LocalizedText
    let timeZone: String
    let lang: Lang
    /// Prochain allumage (vendredi). `nil` aux latitudes extrêmes → l'UI affiche « — ».
    let candleLighting: Date?
    /// Havdala du samedi suivant.
    let havdalah: Date?
    /// Nom de parasha de la semaine (trilingue ; fr retombe sur en — hebcal en/he).
    let parashaName: LocalizedText
    /// Instant de référence du calcul (pour décider passé/à-venir de l'allumage).
    let reference: Date
}

/// Une ligne de zman du widget « Zmanim ».
struct WidgetZmanLine: Identifiable, Sendable {
    var id: String { key }
    let key: String
    let date: Date?
    /// `true` pour le prochain zman à venir (surligné `nerWash`).
    let isUpcoming: Bool
}

/// Données du widget « Zmanim du jour ».
struct ZmanimSnapshot: Sendable {
    let cityName: LocalizedText
    let timeZone: String
    let lang: Lang
    let lines: [WidgetZmanLine]
    let reference: Date
}

/// Données du widget « Omer ».
struct OmerSnapshot: Sendable {
    let lang: Lang
    /// Jour du Omer (1…49), ou `nil` hors période.
    let day: Int?
    /// Jour hébraïque en lettres (ex. « ל״ג »), pour l'affichage hébreu.
    let hebrewDay: String
    let reference: Date
}

// MARK: - Façade de calcul

/// Recalcul local des widgets. `enum` sans cas : espace de noms de fonctions pures.
enum WidgetEngine {

    // MARK: Contexte

    /// Recharge le contexte depuis les préférences (`UserDefaults.standard`) + datasets.
    /// Réplique les dérivés de `AppState` (ville, géo, région effective, langue).
    static func context() -> WidgetContext {
        let settings = SettingsStore.load()
        let city = StaticData.city(slug: settings.citySlug)
        let geo = city.geoContext(candleMode: settings.candle)
        let region: Region
        switch settings.region {
        case .auto:     region = city.israel ? .il : .diaspora
        case .il:       region = .il
        case .diaspora: region = .diaspora
        }
        let lang = settings.lang ?? Lang.fromSystem()
        return WidgetContext(settings: settings, city: city, geo: geo, region: region, lang: lang)
    }

    // MARK: Allumage (Chabbat)

    /// Prochain allumage + havdala + parasha, à partir de `date`.
    static func candle(for date: Date, _ ctx: WidgetContext) -> CandleSnapshot {
        let friday = nextWeekday(.friday, onOrAfter: date, geo: ctx.geo)
        let saturday = nextWeekday(.saturday, onOrAfter: date, geo: ctx.geo)

        let candle = CandleEngine.candleLighting(
            date: friday, geo: ctx.geo,
            candle: ctx.settings.candle, cityMinutes: ctx.city.candleMinutes
        )
        let havdalah = CandleEngine.havdalah(
            date: saturday, geo: ctx.geo, tzeit: ctx.settings.tzeit
        )
        let parasha = CalendarEngine.parasha(week: saturday, region: ctx.region)

        return CandleSnapshot(
            cityName: ctx.city.names,
            timeZone: ctx.geo.timeZone,
            lang: ctx.lang,
            candleLighting: candle,
            havdalah: havdalah,
            parashaName: localizedParasha(parasha),
            reference: date
        )
    }

    // MARK: Zmanim du jour

    /// Sous-ensemble de zmanim du widget (4 marqueurs solaires universels),
    /// avec le PROCHAIN à venir marqué (surlignage `nerWash`).
    static let widgetZmanim: [ZmanKey] = [
        .hanetzHachama, .chatzot, .shkiaHachama, .tzeitHakochavim,
    ]

    static func zmanim(for date: Date, _ ctx: WidgetContext) -> ZmanimSnapshot {
        let result = ZmanimEngine.zmanim(date: date, geo: ctx.geo, settings: ctx.settings)

        // Prochain zman à venir parmi le sous-ensemble widget.
        let upcomingKey: String? = widgetZmanim
            .compactMap { key -> (String, Date)? in
                guard let d = result.byKey[key.rawValue]?.date else { return nil }
                return (key.rawValue, d)
            }
            .filter { $0.1 > date }
            .min { $0.1 < $1.1 }?
            .0

        let lines = widgetZmanim.map { key -> WidgetZmanLine in
            let d = result.byKey[key.rawValue]?.date
            return WidgetZmanLine(key: key.rawValue, date: d, isUpcoming: key.rawValue == upcomingKey)
        }

        return ZmanimSnapshot(
            cityName: ctx.city.names,
            timeZone: ctx.geo.timeZone,
            lang: ctx.lang,
            lines: lines,
            reference: date
        )
    }

    // MARK: Omer

    /// Jour du Omer courant. Le jour hébraïque commençant au coucher, on avance
    /// d'un jour civil après la shkia (parité `AppState.today()`), pour que le
    /// compte bascule au bon moment le soir.
    static func omer(for date: Date, _ ctx: WidgetContext) -> OmerSnapshot {
        let z = ZmanimEngine.zmanim(date: date, geo: ctx.geo, settings: ctx.settings)
        let sunset = z.byKey[ZmanKey.shkiaHachama.rawValue]?.date
        let afterSunset = sunset.map { date >= $0 } ?? false
        let civilDay = afterSunset
            ? (civilCalendar(ctx.geo).date(byAdding: .day, value: 1, to: date) ?? date)
            : date

        let cal = CalendarEngine.day(civilDay, geo: ctx.geo, region: ctx.region, lang: ctx.lang)
        let hebrew = HebrewDateEngine.convert(date, afterSunset: afterSunset, geo: ctx.geo, lang: ctx.lang)

        return OmerSnapshot(
            lang: ctx.lang,
            day: cal.omer,
            hebrewDay: hebrew.dayHebrew,
            reference: date
        )
    }

    // MARK: - Timeline : instants de rafraîchissement

    /// Prochain minuit dans le fuseau de la ville (rollover date / Omer / parasha).
    static func nextMidnight(after date: Date, _ ctx: WidgetContext) -> Date {
        let cal = civilCalendar(ctx.geo)
        let startOfDay = cal.startOfDay(for: date)
        return cal.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(86_400)
    }

    /// Instants de transition des zmanim d'AUJOURD'HUI encore à venir après `date`
    /// (triés) : à chacun, le surlignage « prochain zman » doit se déplacer.
    static func zmanTransitions(after date: Date, _ ctx: WidgetContext) -> [Date] {
        let result = ZmanimEngine.zmanim(date: date, geo: ctx.geo, settings: ctx.settings)
        return widgetZmanim
            .compactMap { result.byKey[$0.rawValue]?.date }
            .filter { $0 > date }
            .sorted()
    }

    // MARK: - Helpers date (fuseau ville → DST correct, parité AppState)

    static func civilCalendar(_ geo: GeoContext) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: geo.timeZone) ?? .current
        return cal
    }

    private enum Weekday: Int { case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday }

    /// Prochaine occurrence de `weekday` (incluse si `date` tombe ce jour-là),
    /// au début de journée dans le fuseau de la ville — miroir de `AppState`.
    private static func nextWeekday(_ weekday: Weekday, onOrAfter date: Date, geo: GeoContext) -> Date {
        let cal = civilCalendar(geo)
        let startToday = cal.startOfDay(for: date)
        let current = cal.component(.weekday, from: startToday)
        let delta = (weekday.rawValue - current + 7) % 7
        return cal.date(byAdding: .day, value: delta, to: startToday) ?? startToday
    }

    /// `ParashaInfo` (en/he) → `LocalizedText` : le fr retombe sur en (la lib ne
    /// traduit pas les noms de parasha en français). Miroir de `AppState`.
    private static func localizedParasha(_ p: ParashaInfo?) -> LocalizedText {
        guard let p else { return LocalizedText(he: "", fr: "", en: "") }
        return LocalizedText(he: p.name.he, fr: p.name.en, en: p.name.en)
    }
}
