//
//  Gematria.swift
//  Moed — CalendarEngine module
//
//  Standard numeric value (mispar hechrachi) of a Hebrew word.
//
//  Parity with the web engine `mvp-moed/src/lib/engine/gematria.ts`:
//  absolute values of the 22 letters, final (sofit) letters counted as their
//  non-final form; nikud, spaces, punctuation and non-Hebrew characters ignored.
//
//  Pure, deterministic, offline. Foundation only.
//

import Foundation

public enum Gematria {

    /// Mispar hechrachi value of each Hebrew consonant (sofit == base form).
    private static let letterValues: [Character: Int] = [
        "א": 1, "ב": 2, "ג": 3, "ד": 4, "ה": 5, "ו": 6, "ז": 7, "ח": 8, "ט": 9,
        "י": 10, "כ": 20, "ך": 20, "ל": 30, "מ": 40, "ם": 40, "נ": 50, "ן": 50,
        "ס": 60, "ע": 70, "פ": 80, "ף": 80, "צ": 90, "ץ": 90,
        "ק": 100, "ר": 200, "ש": 300, "ת": 400,
    ]

    /// Standard gematria (mispar hechrachi) of a Hebrew string.
    /// - Example: `Gematria.value(of: "שלום")` → `376`; `"חי"` → `18`.
    public static func value(of word: String) -> Int {
        var total = 0
        for ch in word {
            total += letterValues[ch] ?? 0
        }
        return total
    }

    /// Per-letter breakdown, skipping characters with no gematria value.
    public static func breakdown(of word: String) -> [(letter: Character, value: Int)] {
        var out: [(letter: Character, value: Int)] = []
        for ch in word {
            if let v = letterValues[ch] {
                out.append((letter: ch, value: v))
            }
        }
        return out
    }
}
