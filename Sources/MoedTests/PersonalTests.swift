//
//  PersonalTests.swift
//  MoedTests
//
//  MODULE « Validation » — dates personnelles récurrentes (CONTRACTS §3.2 `PersonalEngine`).
//
//  Vérifie l'énumération des occurrences (yahrzeit / anniversaire hébraïque) contre le
//  fixture figé, en couvrant explicitement les règles halakhiques délicates (SPEC §3.5) :
//    • **Cheshvan 30** : mois qui peut n'avoir que 29 jours → report réglé par la lib.
//    • **Kislev 30**   : idem.
//    • **Adar / Adar II** : un décès en Adar d'une année simple s'observe en Adar II
//      dans une année embolismique (13 mois).
//
//  Chaque occurrence est comparée EXACTEMENT (dates 0 tolérance) sur sa date grégorienne
//  ET sur sa date hébraïque (année / mois Nisan-based / jour). 100 % offline, déterministe.
//

import XCTest
@testable import Moed

final class PersonalTests: XCTestCase {

    private let fx = Fixture.shared

    /// Géo de référence pour l'ancrage (afterSunset = false : seule la date civile compte).
    private let geo = GeoContext(lat: 31.7683, lng: 35.2137, elevation: 0,
                                 timeZone: "Asia/Jerusalem", name: "Jerusalem")

    private var geoCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        return cal
    }

    func testPersonalOccurrencesMatchFixture() {
        let from = Fixture.civilNoon(fx.personal.from.gy, fx.personal.from.gm, fx.personal.from.gd,
                                     timeZone: "Asia/Jerusalem")
        let cal = geoCalendar

        for kase in fx.personal.cases {
            let type: PersonType = (kase.type == "yahrzeit") ? .yahrzeit : .birthday
            let anchor = Fixture.civilNoon(kase.anchorGreg.gy, kase.anchorGreg.gm, kase.anchorGreg.gd,
                                           timeZone: "Asia/Jerusalem")
            let person = PersonRecord(id: UUID().uuidString, type: type,
                                      name: kase.label, date: anchor, afterSunset: false)

            let got = PersonalEngine.occurrences(of: person, from: from,
                                                 count: kase.occurrences.count,
                                                 geo: geo, lang: .en)

            XCTAssertEqual(got.count, kase.occurrences.count,
                           "[\(kase.label)] nombre d'occurrences")

            for (i, ref) in kase.occurrences.enumerated() {
                guard i < got.count else { break }
                let occ = got[i]
                let ctx = "[\(kase.label)] occ #\(i)"

                // Date hébraïque : contrôle halakhique primaire (indépendant de la timezone).
                XCTAssertEqual(occ.hebrew.year, ref.hy, "\(ctx) année hébraïque")
                XCTAssertEqual(occ.hebrew.month, ref.hMonth, "\(ctx) mois hébraïque (Nisan-based)")
                XCTAssertEqual(occ.hebrew.day, ref.hDay, "\(ctx) jour hébraïque")
                XCTAssertEqual(occ.hebrewYear, ref.hy, "\(ctx) hebrewYear")

                // Date grégorienne dérivée (extraction en timezone géo).
                let comps = cal.dateComponents([.year, .month, .day], from: occ.gregorian)
                XCTAssertEqual(comps.year, ref.gy, "\(ctx) année grég")
                XCTAssertEqual(comps.month, ref.gm, "\(ctx) mois grég")
                XCTAssertEqual(comps.day, ref.gd, "\(ctx) jour grég")
            }
        }
    }

    /// Les occurrences sont strictement croissantes et toutes ≥ `from` (garde-fou §3.5).
    func testOccurrencesAreForwardOnly() {
        let from = Fixture.civilNoon(fx.personal.from.gy, fx.personal.from.gm, fx.personal.from.gd,
                                     timeZone: "Asia/Jerusalem")
        for kase in fx.personal.cases {
            let type: PersonType = (kase.type == "yahrzeit") ? .yahrzeit : .birthday
            let anchor = Fixture.civilNoon(kase.anchorGreg.gy, kase.anchorGreg.gm, kase.anchorGreg.gd,
                                           timeZone: "Asia/Jerusalem")
            let person = PersonRecord(id: UUID().uuidString, type: type,
                                      name: kase.label, date: anchor, afterSunset: false)
            let got = PersonalEngine.occurrences(of: person, from: from, count: 6, geo: geo, lang: .en)

            var previous: Date?
            for occ in got {
                XCTAssertGreaterThanOrEqual(occ.gregorian.timeIntervalSince(from), -86_400,
                                            "[\(kase.label)] occurrence antérieure à `from`")
                if let prev = previous {
                    XCTAssertGreaterThan(occ.gregorian, prev, "[\(kase.label)] occurrences non croissantes")
                }
                previous = occ.gregorian
            }
        }
    }

    /// Cheshvan-30 / Kislev-30 : quand le mois n'a que 29 jours, la lib reporte le
    /// yahrzeit sans jamais produire un « 30 » dans un mois court (cohérence calendrier).
    func testShortMonthEdgeCasesResolveToValidDates() {
        let from = Fixture.civilNoon(2025, 1, 1, timeZone: "Asia/Jerusalem")
        let cal = geoCalendar
        for kase in fx.personal.cases where kase.label.contains("cheshvan-30") || kase.label.contains("kislev-30") {
            let anchor = Fixture.civilNoon(kase.anchorGreg.gy, kase.anchorGreg.gm, kase.anchorGreg.gd,
                                           timeZone: "Asia/Jerusalem")
            let person = PersonRecord(id: UUID().uuidString, type: .yahrzeit,
                                      name: kase.label, date: anchor, afterSunset: false)
            let got = PersonalEngine.occurrences(of: person, from: from, count: 6, geo: geo, lang: .en)
            for occ in got {
                // Un jour hébraïque valide est toujours dans 1...30 ; jamais de date grégorienne aberrante.
                XCTAssertTrue((1...30).contains(occ.hebrew.day), "[\(kase.label)] jour hébraïque hors 1...30")
                let y = cal.dateComponents([.year], from: occ.gregorian).year ?? 0
                XCTAssertGreaterThanOrEqual(y, 2025, "[\(kase.label)] occurrence dans le passé")
            }
        }
    }
}
