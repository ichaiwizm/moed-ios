//
//  ZmanimValidationTests.swift
//  MoedTests
//
//  ⭐ MODULE « Validation » — BARRE HALAKHIQUE BLOQUANTE (NATIVE_SPEC §3.6, PLAN J1).
//
//  « Les gens jeûnent et allument selon ces heures : zéro approximation. »
//  Rien de l'UI ne doit démarrer tant que cette validation n'est pas PASS.
//
//  Ce test rejoue la matrice de référence **10 villes × 2 ans × 4 types de dates**
//  contre un fixture FIGÉ (`Fixtures/kosher_zmanim_reference.json`), exporté hors-ligne
//  des moteurs de référence (`kosher-zmanim` ComplexZmanimCalendar / NOAA + `@hebcal/core`)
//  — les MÊMES références que le web et l'Android natif. Aucun réseau : le fixture est
//  embarqué dans le bundle de test, la CI tourne 100 % offline et déterministe.
//
//  Barre (identique à `validate.mjs`) :
//    • Dates hébraïques  : correspondance EXACTE (0 tolérance).
//    • Zmanim / allumage / havdala : idéal ±1 min, ÉCHEC si > 2 min (≤ 120 s).
//
//  Dépendances : moteur `Engine/` (ZmanimEngine, CandleEngine, HebrewDateEngine),
//  contrat `EngineModels` (CONTRACTS §1 / §3.2). Élévation 0 pour isoler l'algorithme
//  solaire (comme le harnais web) : la parité testée est celle du CALCUL, pas du dataset.
//

import XCTest
@testable import Moed

// MARK: - Fixture (chargement + modèle Codable partagés par tout le module de tests)

/// Jeton pour localiser le bundle de test (les ressources y sont copiées par XcodeGen).
final class MoedTestsBundleToken {}

/// Modèle Codable 1:1 du fixture de référence figé.
struct ReferenceFixture: Decodable {

    struct CityRef: Decodable {
        let name: String
        let slug: String
        let lat: Double
        let lng: Double
        let elevation: Double
        let timeZone: String
    }

    struct DateRef: Decodable {
        let kind: String      // "winterFri" | "summerFri" | "yomtov" | "plain"
        let key: String       // "2025-01-17"
        let gy: Int
        let gm: Int
        let gd: Int
    }

    struct HebRef: Decodable {
        let year: Int
        let month: Int        // Nisan-based 1..13 (13 = Adar II en année embolismique)
        let monthNameEn: String
        let day: Int
        let dayOfWeek: Int    // 0 = dimanche … 6 = samedi (offset +1 vs contrat)
        let isLeapYear: Bool
    }

    struct ConvRef: Decodable {
        let gy: Int, gm: Int, gd: Int
        let year: Int, month: Int, day: Int, dayOfWeek: Int
        let monthNameEn: String
        let isLeapYear: Bool
    }

    struct ToGregRef: Decodable {
        let year: Int, month: Int, day: Int
        let gy: Int, gm: Int, gd: Int
    }

    struct CandleRef: Decodable {
        let candleMinutes: Int
        let candleLighting: String?
        let havdalah: String?
    }

    struct MoladRef: Decodable {
        let year: Int, month: Int
        let monthNameEn: String
        let dow: Int, hour: Int, minutes: Int, chalakim: Int
    }

    struct OccRef: Decodable {
        let gy: Int, gm: Int, gd: Int
        let hy: Int, hMonth: Int, hDay: Int
        let hMonthNameEn: String
    }

    struct AnchorGreg: Decodable { let gy: Int, gm: Int, gd: Int }

    struct PersonalCase: Decodable {
        let label: String
        let type: String       // "yahrzeit" | "birthday"
        let anchorGreg: AnchorGreg
        let occurrences: [OccRef]
    }

    struct Personal: Decodable {
        let from: AnchorGreg
        let cases: [PersonalCase]
    }

    let cities: [CityRef]
    let dates: [DateRef]
    let zmanKeys: [String]
    let hebrewDates: [String: HebRef]
    let conversions: [ConvRef]
    let toGregorian: [ToGregRef]
    let zmanim: [String: [String: String]]      // "City|date" -> { zmanKey: iso }
    let candles: [String: CandleRef]             // "City|date" -> candle/havdalah
    let molad: [MoladRef]
    let personal: Personal
}

/// Accès paresseux et partagé au fixture + utilitaires temps/géo communs.
enum Fixture {

    /// Fixture décodé une seule fois pour toute la suite.
    static let shared: ReferenceFixture = load()

    static func load() -> ReferenceFixture {
        let bundle = Bundle(for: MoedTestsBundleToken.self)
        guard let url = bundle.url(forResource: "kosher_zmanim_reference", withExtension: "json") else {
            fatalError("Fixture introuvable : kosher_zmanim_reference.json absent du bundle de test")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ReferenceFixture.self, from: data)
        } catch {
            fatalError("Fixture illisible : \(error)")
        }
    }

    /// Parseur ISO-8601 avec fractions de seconde (« 2025-01-17T14:59:47.021Z »).
    static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Parse un instant absolu du fixture (UTC).
    static func instant(_ iso: String) -> Date? { isoParser.date(from: iso) }

    /// Fabrique un instant civil non ambigu (midi local) pour un jour civil donné,
    /// afin que le JOUR CIVIL soit identique côté fixture et côté moteur, quelle que
    /// soit la timezone (midi ± 12 h reste dans la même journée).
    static func civilNoon(_ gy: Int, _ gm: Int, _ gd: Int, timeZone: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZone) ?? .init(secondsFromGMT: 0)!
        var c = DateComponents()
        c.year = gy; c.month = gm; c.day = gd; c.hour = 12; c.minute = 0; c.second = 0
        return cal.date(from: c)!
    }

    /// GeoContext depuis une ville de référence (élévation 0 : parité algorithme solaire).
    static func geo(_ city: ReferenceFixture.CityRef) -> GeoContext {
        GeoContext(lat: city.lat, lng: city.lng, elevation: city.elevation,
                   timeZone: city.timeZone, name: city.name)
    }
}

// MARK: - Tolérances

private let ZMAN_TOLERANCE_SECONDS: TimeInterval = 120   // > 2 min = ÉCHEC (barre §3.6)

// MARK: - Suite de validation

final class ZmanimValidationTests: XCTestCase {

    private let fx = Fixture.shared

    /// Compte agrégé pour le verdict (miroir de `validate.mjs`).
    private struct Tally { var comparisons = 0; var withinIdeal = 0; var withinTol = 0; var fail = 0 }

    // 1) Dates hébraïques de la matrice — correspondance EXACTE (0 tolérance).
    func testHebrewDatesExact() {
        // La conversion ne dépend pas du lieu : on ancre à midi UTC pour un jour civil net.
        let utcGeo = GeoContext(lat: 0, lng: 0, elevation: 0, timeZone: "UTC", name: "UTC")
        for d in fx.dates {
            guard let ref = fx.hebrewDates[d.key] else {
                XCTFail("Référence hébraïque manquante pour \(d.key)"); continue
            }
            let noon = Fixture.civilNoon(d.gy, d.gm, d.gd, timeZone: "UTC")
            let res = HebrewDateEngine.convert(noon, afterSunset: false, geo: utcGeo, lang: .en)

            XCTAssertEqual(res.year, ref.year, "année hébraïque \(d.key)")
            XCTAssertEqual(res.month, ref.month, "mois hébraïque (Nisan-based) \(d.key)")
            XCTAssertEqual(res.day, ref.day, "jour hébraïque \(d.key)")
            XCTAssertEqual(res.isLeapYear, ref.isLeapYear, "année embolismique \(d.key)")
            // Contrat : dayOfWeek 1=dimanche…7=samedi ; fixture 0=dimanche…6=samedi.
            XCTAssertEqual(res.dayOfWeek, ref.dayOfWeek + 1, "jour de semaine \(d.key)")
        }
    }

    // 2) Zmanim — 10 villes × 8 dates × 16 clés = 1280 comparaisons, ≤ 120 s.
    func testZmanimMatrixWithinTolerance() {
        for city in fx.cities {
            let geo = Fixture.geo(city)
            for d in fx.dates {
                guard let row = fx.zmanim["\(city.name)|\(d.key)"] else {
                    XCTFail("Ligne zmanim manquante : \(city.name)|\(d.key)"); continue
                }
                let noon = Fixture.civilNoon(d.gy, d.gm, d.gd, timeZone: city.timeZone)
                let result = ZmanimEngine.zmanim(date: noon, geo: geo, settings: Settings())

                for key in fx.zmanKeys {
                    let reference = row[key].flatMap(Fixture.instant)
                    let engine = result.byKey[key]?.date
                    assertClose(city: city.name, date: d.key, label: key,
                                reference: reference, engine: engine)
                }
            }
        }
    }

    // 3) Allumage des bougies (vendredis) — 18 min avant le coucher, ≤ 120 s.
    func testCandleLightingWithinTolerance() {
        for city in fx.cities {
            let geo = Fixture.geo(city)
            for d in fx.dates where d.kind == "winterFri" || d.kind == "summerFri" {
                guard let ref = fx.candles["\(city.name)|\(d.key)"],
                      let refISO = ref.candleLighting else { continue }
                let erev = Fixture.civilNoon(d.gy, d.gm, d.gd, timeZone: city.timeZone)
                let engine = CandleEngine.candleLighting(date: erev, geo: geo,
                                                         candle: .minutes(ref.candleMinutes),
                                                         cityMinutes: ref.candleMinutes)
                assertClose(city: city.name, date: d.key, label: "candleLighting",
                            reference: Fixture.instant(refISO), engine: engine)
            }
        }
    }

    // 4) Havdala (motzaei) — 8.5° sous l'horizon, ≤ 120 s.
    func testHavdalahWithinTolerance() {
        for city in fx.cities {
            let geo = Fixture.geo(city)
            for d in fx.dates where d.kind == "winterFri" || d.kind == "summerFri" {
                guard let ref = fx.candles["\(city.name)|\(d.key)"],
                      let refISO = ref.havdalah else { continue }
                // Motzaei = lendemain (samedi) du vendredi civil.
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(identifier: city.timeZone) ?? .init(secondsFromGMT: 0)!
                let erev = Fixture.civilNoon(d.gy, d.gm, d.gd, timeZone: city.timeZone)
                let motzaei = cal.date(byAdding: .day, value: 1, to: erev)!
                let engine = CandleEngine.havdalah(date: motzaei, geo: geo, tzeit: .degrees)
                assertClose(city: city.name, date: d.key, label: "havdalah",
                            reference: Fixture.instant(refISO), engine: engine)
            }
        }
    }

    // 5) VERDICT global AUTONOME : recalcule toute la matrice et exige 0 échec.
    //    Indépendant de l'ordre d'exécution des autres tests (aucun état partagé).
    //    C'est LE gate : tant qu'il n'est pas vert, aucune UI ne doit démarrer.
    func testValidationVerdictHasZeroFailures() {
        var t = Tally()

        func tally(_ reference: Date?, _ engine: Date?) {
            if reference == nil && engine == nil { return }
            guard let ref = reference, let eng = engine else { t.fail += 1; return }
            let diff = abs(eng.timeIntervalSince(ref))
            t.comparisons += 1
            if diff <= 60 { t.withinIdeal += 1 }
            else if diff <= ZMAN_TOLERANCE_SECONDS { t.withinTol += 1 }
            else { t.fail += 1 }
        }

        for city in fx.cities {
            let geo = Fixture.geo(city)
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: city.timeZone) ?? .init(secondsFromGMT: 0)!
            for d in fx.dates {
                let noon = Fixture.civilNoon(d.gy, d.gm, d.gd, timeZone: city.timeZone)
                let result = ZmanimEngine.zmanim(date: noon, geo: geo, settings: Settings())
                if let row = fx.zmanim["\(city.name)|\(d.key)"] {
                    for key in fx.zmanKeys {
                        tally(row[key].flatMap(Fixture.instant), result.byKey[key]?.date)
                    }
                }
                if let ref = fx.candles["\(city.name)|\(d.key)"] {
                    if let cl = ref.candleLighting {
                        let eng = CandleEngine.candleLighting(date: noon, geo: geo,
                                                              candle: .minutes(ref.candleMinutes),
                                                              cityMinutes: ref.candleMinutes)
                        tally(Fixture.instant(cl), eng)
                    }
                    if let hv = ref.havdalah {
                        let motzaei = cal.date(byAdding: .day, value: 1, to: noon)!
                        let eng = CandleEngine.havdalah(date: motzaei, geo: geo, tzeit: .degrees)
                        tally(Fixture.instant(hv), eng)
                    }
                }
            }
        }

        print("""

        ============ MOED — VALIDATION HALAKHIQUE (offline) ============
        Source     : kosher-zmanim (NOAA) + @hebcal/core — fixture figé
        Matrice    : \(fx.cities.count) villes × \(fx.dates.count) dates × \(fx.zmanKeys.count) zmanim
        Tolérance  : idéal ±1 min, ÉCHEC si > 2 min ; dates 0 tolérance
        Comparaisons: \(t.comparisons)
        ≤ 1 min     : \(t.withinIdeal)
        ≤ 2 min     : \(t.withinTol)
        ÉCHEC > 2min: \(t.fail)
        VERDICT     : \(t.fail == 0 ? "PASS ✅" : "FAIL ❌")
        ===============================================================
        """)

        XCTAssertGreaterThan(t.comparisons, 0, "aucune comparaison — fixture non chargé ?")
        XCTAssertEqual(t.fail, 0, "\(t.fail) horaires hors tolérance (> 2 min) — BARRE HALAKHIQUE NON FRANCHIE")
    }

    // MARK: Helper de comparaison temporelle (assertion granulaire)

    private func assertClose(city: String, date: String, label: String,
                             reference: Date?, engine: Date?,
                             file: StaticString = #filePath, line: UInt = #line) {
        // Cohérence de présence : un zman nul de part et d'autre est valide (latitude extrême).
        if reference == nil && engine == nil { return }
        guard let ref = reference else {
            XCTFail("[\(city) \(date) \(label)] moteur=\(String(describing: engine)) mais référence nulle",
                    file: file, line: line)
            return
        }
        guard let eng = engine else {
            XCTFail("[\(city) \(date) \(label)] référence=\(ref) mais moteur nul (attendu non nul)",
                    file: file, line: line)
            return
        }
        let diff = abs(eng.timeIntervalSince(ref))
        XCTAssertLessThanOrEqual(
            diff, ZMAN_TOLERANCE_SECONDS,
            "[\(city) \(date) \(label)] écart \(String(format: "%.1f", diff / 60)) min — moteur=\(eng) réf=\(ref)",
            file: file, line: line
        )
    }
}
