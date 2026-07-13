//
//  GematriaTests.swift
//  MoedTests
//
//  MODULE « Validation » — guématria standard (CONTRACTS §3.2 `Gematria`).
//
//  Mispar hechrachi (valeur absolue) : les 22 lettres, les finales (sofit) comptées
//  comme leur forme normale ; nikoud, espaces, ponctuation et caractères non hébreux
//  ignorés. Valeurs de référence mathématiquement certaines (déterministe, offline).
//

import XCTest
@testable import Moed

final class GematriaTests: XCTestCase {

    func testStandardWords() {
        // (mot, valeur attendue)
        let cases: [(String, Int)] = [
            ("שלום", 376),      // ש300 ל30 ו6 ם40
            ("חי", 18),         // ח8 י10  — « vie »
            ("אמת", 441),       // א1 מ40 ת400  — « vérité »
            ("ישראל", 541),     // י10 ש300 ר200 א1 ל30
            ("מלך", 90),        // מ40 ל30 ך20  (kaf sofit = kaf = 20)
            ("תורה", 611),      // ת400 ו6 ר200 ה5
            ("אחד", 13),        // א1 ח8 ד4  — « un »
            ("בראשית", 913),    // ב2 ר200 א1 ש300 י10 ת400
        ]
        for (word, expected) in cases {
            XCTAssertEqual(Gematria.value(of: word), expected, "guématria de « \(word) »")
        }
    }

    func testFinalLettersEqualBaseForm() {
        // Les finales valent leur forme de base (mispar hechrachi).
        XCTAssertEqual(Gematria.value(of: "ם"), 40, "mem sofit = mem")
        XCTAssertEqual(Gematria.value(of: "מ"), 40)
        XCTAssertEqual(Gematria.value(of: "ן"), 50, "noun sofit = noun")
        XCTAssertEqual(Gematria.value(of: "ך"), 20, "kaf sofit = kaf")
        XCTAssertEqual(Gematria.value(of: "ף"), 80, "pe sofit = pe")
        XCTAssertEqual(Gematria.value(of: "ץ"), 90, "tsadi sofit = tsadi")
    }

    func testIgnoresNikudSpacesPunctuationAndLatin() {
        // Nikoud (points-voyelles) ignoré : « חַי » == « חי » == 18.
        XCTAssertEqual(Gematria.value(of: "חַי"), 18, "nikoud doit être ignoré")
        // Espaces / ponctuation / lettres latines ignorés.
        XCTAssertEqual(Gematria.value(of: "בית המקדש"), 861, "espaces ignorés")
        //   בית = 412 (ב2 י10 ת400) ; המקדש = 449 (ה5 מ40 ק100 ד4 ש300) ; total 861.
        XCTAssertEqual(Gematria.value(of: "chai חי !"), 18, "latin et ponctuation ignorés")
        XCTAssertEqual(Gematria.value(of: ""), 0, "chaîne vide = 0")
        XCTAssertEqual(Gematria.value(of: "123 abc"), 0, "aucune lettre hébraïque = 0")
    }

    func testBreakdownEnumeratesEveryHebrewLetter() {
        let breakdown = Gematria.breakdown(of: "חי")
        XCTAssertEqual(breakdown.count, 2)
        XCTAssertEqual(breakdown.map(\.letter), ["ח", "י"])
        XCTAssertEqual(breakdown.map(\.value), [8, 10])
        // La somme du détail égale la valeur totale.
        XCTAssertEqual(breakdown.reduce(0) { $0 + $1.value }, Gematria.value(of: "חי"))
    }

    func testBreakdownSkipsNonHebrew() {
        // « חַי » : le nikoud n'apparaît pas dans le détail.
        let breakdown = Gematria.breakdown(of: "חַי")
        XCTAssertEqual(breakdown.map(\.letter), ["ח", "י"], "le détail ne contient que des lettres")
        XCTAssertEqual(breakdown.reduce(0) { $0 + $1.value }, 18)
    }
}
