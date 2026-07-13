//
//  CandleEngine.swift
//  Moed — Engine (source de vérité halakhique)
//
//  Allumage des bougies (Chabbat & Yom Tov) et havdala, par ville et minhag.
//
//  Parité STRICTE avec le moteur web `mvp-moed/src/lib/engine/candles.ts` :
//   • Allumage  = coucher (shkia) − `candleMinutes`  (défaut 18 ; minhagim 18/20/30/40).
//   • Havdala   = 8.5° sous l'horizon (défaut, « 3 étoiles »)  OU  coucher + offset
//                 fixe en minutes (défaut 72 min, Rabbeinu Tam — valeur du web).
//
//  Le coucher utilisé est élévation-conscient ssi `geo.elevation > 0` (le calcul
//  passe par `SolarCalendar`, qui n'applique l'élévation qu'au-dessus du niveau
//  de la mer et pilote le fuseau IANA de la ville pour un DST correct partout).
//
//  Invariants : instants BRUTS (aucun arrondi ici — fait à l'affichage) ;
//  `nil` aux latitudes extrêmes (jamais `NaN`) ; 100 % offline / déterministe.
//
//  Dépend de : EngineModels (GeoContext, CandleMode, TzeitMethod) et de
//  `SolarCalendar` / `SolarTime` (définis dans SolarCalculator.swift).
//

import Foundation

enum CandleEngine {

    // MARK: Constantes de minhag (défauts halakhiques, parité web)

    /// Minutes d'allumage par défaut quand la ville n'impose pas de minhag
    /// (`CandleMode.auto` sans `City`). `candles.ts` → `DEFAULT_CANDLE_MIN = 18`.
    static let defaultCandleMinutes = 18

    /// Degrés sous l'horizon pour la havdala « 3 étoiles ». `DEFAULT_HAVDALAH_DEG = 8.5`.
    static let havdalahDegrees = 8.5

    /// Offset fixe (minutes après le coucher) pour la havdala en mode `.minutes`.
    /// Le web utilise 72 min (Rabbeinu Tam) — cf. `page.tsx` `{ type: 'minutes', minutes: 72 }`.
    static let havdalahMinutes = 72

    // MARK: Allumage

    /// Heure d'allumage des bougies = `candleMinutes` avant le coucher, le jour
    /// civil `date` (veille de Chabbat / Yom Tov).
    ///
    /// - Parameters:
    ///   - candle: minhag d'allumage (`.auto` → utilise `cityMinutes`, ou une
    ///     valeur explicite `.minutes(n)`).
    ///   - cityMinutes: minutes propres à la ville (Jérusalem 40 ; Haïfa / Petah
    ///     Tikva / Beer Sheva 30 ; défaut 18 ; certaines communautés 20).
    /// - Returns: instant brut d'allumage, ou `nil` si le coucher est indéfini
    ///   (latitude polaire).
    static func candleLighting(date: Date,
                               geo: GeoContext,
                               candle: CandleMode,
                               cityMinutes: Int) -> Date? {
        let minutes: Int
        switch candle {
        case .auto:            minutes = cityMinutes
        case .minutes(let m):  minutes = m
        }

        return SolarCalendar.withCalendar(date: date, geo: geo) { cal in
            guard let sunset = cal.sunset() else { return nil }
            return sunset.addingTimeInterval(-Double(minutes) * 60)
        }
    }

    // MARK: Havdala

    /// Heure de havdala le jour civil `date` (motzaei Chabbat / Yom Tov), selon
    /// la shita choisie.
    ///
    /// - `.degrees` : coucher décalé de `90° + 8.5°` sous l'horizon géométrique
    ///   (équivalent `getSunsetOffsetByDegrees(98.5)` du web).
    /// - `.minutes` : coucher + `havdalahMinutes` minutes (offset fixe).
    ///
    /// - Returns: instant brut de havdala, ou `nil` si l'heure requise est
    ///   indéfinie à cette latitude.
    static func havdalah(date: Date,
                         geo: GeoContext,
                         tzeit: TzeitMethod) -> Date? {
        SolarCalendar.withCalendar(date: date, geo: geo) { cal -> Date? in
            switch tzeit {
            case .degrees:
                // Zénith = 90° (horizon géométrique) + dépression en degrés.
                return cal.sunsetOffset(byDegrees: 90 + havdalahDegrees)
            case .minutes:
                guard let sunset = cal.sunset() else { return nil }
                return sunset.addingTimeInterval(Double(havdalahMinutes) * 60)
            }
        }
    }
}
