//
//  ZmanimEngine.swift
//  Moed — Engine (source de vérité halakhique)
//
//  Calcule les 16 zmanim du catalogue figé (`ZmanKey`) via le calculateur
//  solaire natif `SolarCalculator` (algorithme NOAA de KosherJava, Swift pur,
//  sans dépendance externe) — parité stricte avec `kosher-zmanim` (web) et
//  `KosherJava 2.5.0` (Android). Algorithme solaire NOAA.
//
//  Parité STRICTE avec le moteur web `mvp-moed/src/lib/engine/zmanim.ts` :
//  chaque zman est recalculé à partir des mêmes formules que kosher-zmanim
//  (lever/coucher + heures proportionnelles GRA/MGA), et non délégué à des
//  getters de haut niveau (dont les méthodes GRA forcent le niveau de la mer).
//
//  Invariants (CONTRACTS §1.3, NATIVE_SPEC §3.4) :
//   • Toutes les `Date` sont des instants absolus BRUTS — aucun arrondi ici.
//     L'arrondi à la minute est fait plus tard, à l'affichage (UI).
//   • DST piloté par l'identifiant IANA de la ville (`geo.timeZone`), jamais par
//     l'offset fixe de l'appareil.
//   • Élévation appliquée au lever/coucher UNIQUEMENT si `geo.elevation > 0`
//     (émule `setUseElevation(elevation > 0)` du web).
//   • Aux latitudes extrêmes, un zman absent vaut `nil`, JAMAIS `NaN`.
//   • 100 % offline, déterministe, aucun appel réseau.
//
//  Dépend de : EngineModels (Zman, ZmanimResult, ZmanKey, GeoContext, Settings,
//  CandleMode, TzeitMethod, LocalizedText…).
//

import Foundation

// La fabrique de calendrier solaire (`SolarCalendar`) et le calculateur natif
// (`SolarTime`, algorithme NOAA en Swift pur) sont définis dans
// `SolarCalculator.swift` — partagés avec `CandleEngine`.

// MARK: - Moteur des zmanim

enum ZmanimEngine {

    /// Calcule les 16 zmanim (ordre catalogue), l'allumage éventuel et la havdala
    /// pour `date` / `geo`, selon les préférences `settings`.
    static func zmanim(date: Date, geo: GeoContext, settings: Settings) -> ZmanimResult {

        // Résolution des heures brutes dans le fuseau de la ville.
        let times: [ZmanKey: Date?] = SolarCalendar.withCalendar(date: date, geo: geo) { cal in
            computeTimes(cal)
        }

        // Construction de la liste ordonnée + index O(1) par rawValue.
        var zmanim: [Zman] = []
        zmanim.reserveCapacity(ZmanKey.allCases.count)
        var byKey: [String: Zman] = [:]
        byKey.reserveCapacity(ZmanKey.allCases.count)

        for key in ZmanKey.allCases {
            let resolved = times[key] ?? nil            // Date??  →  Date?
            let z = Zman(key: key.rawValue, date: resolved, shita: shita(for: key))
            zmanim.append(z)
            byKey[key.rawValue] = z
        }

        // Allumage / havdala du Chabbat, dérivés dans le même passage solaire.
        let (candle, havdalah) = shabbatTimes(date: date, geo: geo, settings: settings)

        return ZmanimResult(zmanim: zmanim,
                            byKey: byKey,
                            location: geo,
                            date: date,
                            candleLighting: candle,
                            havdalah: havdalah)
    }

    // MARK: Calcul des instants (dans le bloc à fuseau forcé)

    /// Recalcule les 16 zmanim à partir des primitives solaires natives.
    ///
    /// Le lever/coucher `cal.sunrise()` / `cal.sunset()` sont ajustés à
    /// l'élévation ssi celle-ci est > 0 (élévation déjà « bakée » à 0 sinon par
    /// `SolarCalendar`), ce qui reproduit `getSunrise()` / `getSunset()` du web
    /// sous `setUseElevation(elevation > 0)`. Toutes les heures temporelles (GRA,
    /// MGA, plag…) sont dérivées de ces deux ancres via des `shaʿot zmaniyot`,
    /// exactement comme kosher-zmanim — et NON via des getters GRA de haut niveau
    /// (qui forcent le niveau de la mer).
    private static func computeTimes(_ cal: SolarTime) -> [ZmanKey: Date?] {

        // Ancres élévation-conscientes.
        let sunrise = cal.sunrise()      // netz (hanetz hachama)
        let sunset  = cal.sunset()       // shkia hachama

        // shaʿah zmanit GRA = (coucher − lever) / 12.
        let shaahGra = temporalHour(from: sunrise, to: sunset)

        // Alot / tzeit 72 minutes (Rabbeinu Tam) — ancrés au lever/coucher.
        let alos72  = sunrise.map { $0.addingTimeInterval(-72 * 60) }
        let tzais72 = sunset.map  { $0.addingTimeInterval( 72 * 60) }

        // shaʿah zmanit MGA = (tzeit72 − alot72) / 12 (jour Magen Avraham).
        let shaahMga = temporalHour(from: alos72, to: tzais72)

        // Heures dérivées, toutes en instants bruts.
        return [
            // Aube
            .alotHashachar:      cal.alos16Point1Degrees(),                 // 16.1° (degré, NOAA)
            .alotHashachar72:    alos72,                                    // 72 min avant le lever
            .misheyakir:         cal.misheyakir11Point5Degrees(),           // 11.5°
            .misheyakirMachmir:  cal.misheyakir10Point2Degrees(),           // 10.2°
            // Lever
            .hanetzHachama:      sunrise,
            // Sof zman Shema / Tefila
            .sofZmanShmaMGA:     offset(from: alos72,  hours: 3,  shaah: shaahMga),
            .sofZmanShmaGRA:     offset(from: sunrise, hours: 3,  shaah: shaahGra),
            .sofZmanTfilaMGA:    offset(from: alos72,  hours: 4,  shaah: shaahMga),
            .sofZmanTfilaGRA:    offset(from: sunrise, hours: 4,  shaah: shaahGra),
            // Midi solaire (= lever + 6 shaʿot GRA = milieu lever/coucher)
            .chatzot:            offset(from: sunrise, hours: 6,     shaah: shaahGra),
            // Après-midi (GRA)
            .minchaGedola:       offset(from: sunrise, hours: 6.5,   shaah: shaahGra),
            .minchaKetana:       offset(from: sunrise, hours: 9.5,   shaah: shaahGra),
            .plagHamincha:       offset(from: sunrise, hours: 10.75, shaah: shaahGra),
            // Coucher
            .shkiaHachama:       sunset,
            // Tombée de la nuit
            .tzeitHakochavim:    cal.tzaisGeonim8Point5Degrees(),           // 8.5° (3 étoiles)
            .tzeit72:            tzais72,                                   // 72 min (Rabbeinu Tam)
        ]
    }

    /// Allumage (veille de Chabbat) + havdala (motzaei Chabbat) pour le jour
    /// civil courant, calculés dans le même passage solaire.
    ///
    /// - Le vendredi : allumage = coucher − minutes.
    /// - Le samedi   : havdala = 8.5° sous l'horizon, ou coucher + offset minutes.
    ///
    /// Les minutes d'allumage minhagiques dépendantes de la ville
    /// (`CandleMode.auto`) ne sont pas connues de ce moteur (il ne reçoit pas la
    /// `City`) : on retombe alors sur le défaut halakhique 18 min. La couche
    /// `AppState` renseigne la valeur exacte via `CandleEngine` + `City.candleMinutes`.
    private static func shabbatTimes(date: Date,
                                     geo: GeoContext,
                                     settings: Settings) -> (candle: Date?, havdalah: Date?) {
        let timeZone = TimeZone(identifier: geo.timeZone) ?? TimeZone(identifier: "UTC")!
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        // Gregorian weekday : 1 = dimanche … 6 = vendredi, 7 = samedi.
        let weekday = gregorian.component(.weekday, from: date)

        let candleMinutes: Int
        switch settings.candle {
        case .auto:            candleMinutes = CandleEngine.defaultCandleMinutes
        case .minutes(let m):  candleMinutes = m
        }

        return SolarCalendar.withCalendar(date: date, geo: geo) { cal -> (Date?, Date?) in
            var candle: Date? = nil
            var havdalah: Date? = nil

            if weekday == 6, let sunset = cal.sunset() {            // vendredi
                candle = sunset.addingTimeInterval(-Double(candleMinutes) * 60)
            }
            if weekday == 7 {                                       // samedi
                switch settings.tzeit {
                case .degrees:
                    havdalah = cal.sunsetOffset(byDegrees: 90 + CandleEngine.havdalahDegrees)
                case .minutes:
                    if let sunset = cal.sunset() {
                        havdalah = sunset.addingTimeInterval(Double(CandleEngine.havdalahMinutes) * 60)
                    }
                }
            }
            return (candle, havdalah)
        }
    }

    // MARK: Helpers arithmétiques (propagation stricte du nil, jamais de NaN)

    /// Durée d'une `shaʿah zmanit` = (end − start) / 12. `nil` si l'une des
    /// bornes est absente (latitude extrême) → tous les dérivés seront `nil`.
    private static func temporalHour(from start: Date?, to end: Date?) -> TimeInterval? {
        guard let start, let end else { return nil }
        let interval = end.timeIntervalSince(start)
        guard interval.isFinite else { return nil }
        return interval / 12.0
    }

    /// `base + hours × shaʿah`. `nil` dès qu'une entrée manque.
    private static func offset(from base: Date?, hours: Double, shaah: TimeInterval?) -> Date? {
        guard let base, let shaah, shaah.isFinite else { return nil }
        return base.addingTimeInterval(hours * shaah)
    }

    // MARK: Libellés de shita (TOUJOURS affichés — transparence halakhique)
    // Parité 1:1 avec les libellés du moteur web (zmanim.ts).

    private static func shita(for key: ZmanKey) -> String {
        switch key {
        case .alotHashachar:     return "16.1°"
        case .alotHashachar72:   return "72 min"
        case .misheyakir:        return "11.5°"
        case .misheyakirMachmir: return "10.2°"
        case .hanetzHachama:     return "sunrise"
        case .sofZmanShmaMGA:    return "MGA 72 min"
        case .sofZmanShmaGRA:    return "GRA"
        case .sofZmanTfilaMGA:   return "MGA 72 min"
        case .sofZmanTfilaGRA:   return "GRA"
        case .chatzot:           return "astronomical noon"
        case .minchaGedola:      return "GRA (0.5 shaʿah)"
        case .minchaKetana:      return "GRA (9.5 shaʿah)"
        case .plagHamincha:      return "GRA (10.75 shaʿah)"
        case .shkiaHachama:      return "sunset"
        case .tzeitHakochavim:   return "8.5° (3 stars)"
        case .tzeit72:           return "72 min (Rabbeinu Tam)"
        }
    }
}
