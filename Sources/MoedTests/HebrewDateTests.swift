//
//  HebrewDateTests.swift
//  MoedTests
//
//  MODULE « Validation » — calendrier hébraïque (CONTRACTS §3.2 `HebrewDateEngine`).
//
//  Vérifie, 100 % offline et déterministe :
//    • conversions grégorien → hébreu (exactes, 0 tolérance, contre fixture figé) ;
//    • conversions hébreu → grégorien (aller-retour) ;
//    • molad du mois (correctness structurelle : intervalle = mois synodique moyen,
//      indépendant de toute convention d'epoch / timezone) ;
//    • edge cases : flag `afterSunset` (le jour hébraïque commence au coucher →
//      avance d'un jour) et latitudes polaires (zman `nil`, jamais `NaN`).
//
//  Le calendrier juif DOIT être correct : molad, années embolismiques (13 mois,
//  Adar II), Cheshvan/Kislev de longueur variable — tout est couvert par la lib de
//  référence et re-vérifié ici.
//

import XCTest
@testable import Moed

final class HebrewDateTests: XCTestCase {

    private let fx = Fixture.shared

    /// Géo neutre : la conversion de date ne dépend pas du lieu (afterSunset = false).
    private let utcGeo = GeoContext(lat: 0, lng: 0, elevation: 0, timeZone: "UTC", name: "UTC")

    // MARK: Grégorien → hébreu (exact, 0 tolérance)

    func testGregorianToHebrewConversions() {
        for c in fx.conversions {
            let noon = Fixture.civilNoon(c.gy, c.gm, c.gd, timeZone: "UTC")
            let res = HebrewDateEngine.convert(noon, afterSunset: false, geo: utcGeo, lang: .en)
            let ctx = "\(c.gy)-\(c.gm)-\(c.gd)"
            XCTAssertEqual(res.year, c.year, "année [\(ctx)]")
            XCTAssertEqual(res.month, c.month, "mois Nisan-based [\(ctx)]")
            XCTAssertEqual(res.day, c.day, "jour [\(ctx)]")
            XCTAssertEqual(res.isLeapYear, c.isLeapYear, "embolismique [\(ctx)]")
            XCTAssertEqual(res.dayOfWeek, c.dayOfWeek + 1, "jour de semaine [\(ctx)]")
        }
    }

    /// Sanity trilingue : les noms de mois/jours sont bien renseignés dans les 3 langues
    /// (tables maison he/fr/en — jamais le rendu `fr` de la lib, cf. SPEC §3.4).
    func testLocalizedNamesArePopulated() {
        let noon = Fixture.civilNoon(2025, 4, 13, timeZone: "UTC") // 15 Nisan 5785
        let res = HebrewDateEngine.convert(noon, afterSunset: false, geo: utcGeo, lang: .fr)
        for lang: Lang in [.he, .fr, .en] {
            XCTAssertFalse(res.monthName(lang).isEmpty, "mois vide en \(lang.rawValue)")
            XCTAssertFalse(res.weekdayName(lang).isEmpty, "jour vide en \(lang.rawValue)")
        }
        XCTAssertFalse(res.yearHebrew.isEmpty, "année en lettres hébraïques vide")
        XCTAssertFalse(res.dayHebrew.isEmpty, "jour en lettres hébraïques vide")
    }

    // MARK: Hébreu → grégorien (aller-retour)

    func testHebrewToGregorian() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current   // toGregorian rend un instant à minuit local (cf. contrat)
        for c in fx.toGregorian {
            guard let g = HebrewDateEngine.toGregorian(year: c.year, month: c.month, day: c.day) else {
                XCTFail("toGregorian nil pour \(c.day)/\(c.month)/\(c.year)"); continue
            }
            let comps = cal.dateComponents([.year, .month, .day], from: g)
            let ctx = "\(c.day)/\(c.month)/\(c.year)"
            XCTAssertEqual(comps.year, c.gy, "année grég [\(ctx)]")
            XCTAssertEqual(comps.month, c.gm, "mois grég [\(ctx)]")
            XCTAssertEqual(comps.day, c.gd, "jour grég [\(ctx)]")
        }
    }

    // MARK: Molad — correctness structurelle (mois synodique moyen)

    /// Mois lunaire moyen (molad) : 29 j 12 h 793 chalakim = 2 551 443,33 s.
    /// Un chelek = 10/3 s ; 793 chalakim = 44 min 3,33 s.
    func testMoladSynodicInterval() {
        let synodicSeconds: TimeInterval = 29 * 86_400 + 12 * 3_600 + 793 * (10.0 / 3.0)
        // Paires de mois consécutifs (même sens de numérotation) → exactement une lunaison.
        // Nisan=1 … Adar/AdarII=12/13, Tishrei=7. On évite Elul(6)→Tishrei(7) et 13→1
        // (sauts d'année) en restant dans des paires m → m+1 de la même année hébraïque.
        let pairs: [(year: Int, from: Int, to: Int)] = [
            (5785, 7, 8),    // Tishrei → Cheshvan
            (5785, 8, 9),    // Cheshvan → Kislev
            (5785, 1, 2),    // Nisan → Iyyar
            (5786, 7, 8),    // Tishrei → Cheshvan
            (5784, 12, 13),  // Adar I → Adar II (année embolismique)
        ]
        for p in pairs {
            let a = HebrewDateEngine.molad(year: p.year, month: p.from)
            let b = HebrewDateEngine.molad(year: p.year, month: p.to)
            let delta = b.timeIntervalSince(a)
            XCTAssertEqual(delta, synodicSeconds, accuracy: 5.0,
                           "intervalle molad \(p.from)→\(p.to) (\(p.year)) = \(delta) s, attendu ≈ \(synodicSeconds) s")
        }
    }

    /// Le molad avance de façon monotone à travers l'année (ordre chronologique).
    func testMoladMonotonic() {
        // Ordre chronologique d'une année : Tishrei(7)…Elul(6).
        let order5785 = [7, 8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6]
        var previous: Date?
        for m in order5785 {
            let d = HebrewDateEngine.molad(year: 5785, month: m)
            if let prev = previous {
                XCTAssertGreaterThan(d, prev, "molad mois \(m) doit suivre le précédent")
            }
            previous = d
        }
    }

    // MARK: Edge case — afterSunset (le jour hébraïque commence au coucher)

    func testAfterSunsetAdvancesHebrewDay() {
        // 15 Nisan 5785 (jour) ; après le coucher → 16 Nisan.
        let day = Fixture.civilNoon(2025, 4, 13, timeZone: "UTC")
        let before = HebrewDateEngine.convert(day, afterSunset: false, geo: utcGeo, lang: .en)
        let after = HebrewDateEngine.convert(day, afterSunset: true, geo: utcGeo, lang: .en)
        XCTAssertEqual(before.day, 15, "jour de base attendu = 15 Nisan")
        XCTAssertEqual(after.day, before.day + 1, "afterSunset doit avancer d'un jour hébraïque")
        XCTAssertEqual(after.month, before.month, "même mois (milieu de mois, pas de rollover)")
    }

    // MARK: Edge case — latitudes polaires (zman nil, jamais NaN)

    func testExtremeLatitudeYieldsNilNotNaN() {
        // Longyearbyen (Svalbard, 78,22° N) au solstice d'été : le soleil ne descend
        // jamais à −8,5° ni −16,1° → tzeit / alot INDÉFINIS (nil), jamais NaN.
        let polar = GeoContext(lat: 78.2232, lng: 15.6267, elevation: 0,
                               timeZone: "Arctic/Longyearbyen", name: "Longyearbyen")
        let solstice = Fixture.civilNoon(2025, 6, 21, timeZone: "Arctic/Longyearbyen")
        let result = ZmanimEngine.zmanim(date: solstice, geo: polar, settings: Settings())

        XCTAssertNil(result.byKey[ZmanKey.tzeitHakochavim.rawValue]?.date,
                     "tzeit 8.5° doit être nil au pôle en été")
        XCTAssertNil(result.byKey[ZmanKey.alotHashachar.rawValue]?.date,
                     "alot 16.1° doit être nil au pôle en été")
        // Aucun zman ne doit être un NaN déguisé : tout est soit un instant valide, soit nil.
        for z in result.zmanim {
            if let t = z.date {
                XCTAssertFalse(t.timeIntervalSince1970.isNaN, "\(z.key) est NaN")
                XCTAssertTrue(t.timeIntervalSince1970.isFinite, "\(z.key) n'est pas fini")
            }
        }
    }
}
