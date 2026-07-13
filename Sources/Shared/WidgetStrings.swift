//
//  WidgetStrings.swift
//  Moed — Shared (double target membership : Moed + MoedWidgets)
//
//  Chaînes trilingues et formatage d'horaires DÉDIÉS aux widgets.
//
//  Pourquoi pas `L10n` ?
//  ─────────────────────
//  `L10n` charge des tables `Localizable.strings` depuis les `*.lproj` du bundle
//  de l'app. Une extension WidgetKit a son propre bundle ; ces ressources n'y
//  sont pas garanties. On embarque donc EN DUR le petit sous-ensemble de clés que
//  les widgets affichent — valeurs copiées 1:1 des `messages/{he,fr,en}.json`
//  (via `L10n`), 100 % offline, aucune ressource à résoudre. Toute dérive de
//  libellé = incohérence app ↔ widget.
//
//  Les libellés de zmanim sont VOLONTAIREMENT courts (colonne tabular d'un
//  widget medium), plus concis que `zmanim.*` de l'app.
//

import Foundation

/// Accès aux chaînes localisées des widgets (sous-ensemble figé de `L10n`).
enum WidgetStrings {

    /// Sélection trilingue.
    private static func pick(_ he: String, _ fr: String, _ en: String, _ lang: Lang) -> String {
        switch lang {
        case .he: return he
        case .fr: return fr
        case .en: return en
        }
    }

    // MARK: Chabbat / allumage (miroir de `home.*`)

    static func nextShabbat(_ lang: Lang) -> String {
        pick("השבת הקרובה", "Prochain Chabbat", "Next Shabbat", lang)
    }

    /// « Allumage à {time} » — `home.candleAt`.
    static func candleAt(_ time: String, _ lang: Lang) -> String {
        pick("הדלקת נרות ב\(time)", "Allumage à \(time)", "Candle lighting at \(time)", lang)
    }

    /// « Allumage dans … » (le compte à rebours suit, rendu par `Text(style:.timer)`).
    static func candleInPrefix(_ lang: Lang) -> String {
        pick("הדלקת נרות בעוד", "Allumage dans", "Candle lighting in", lang)
    }

    /// « Sortie (havdala) » — `home.havdala`.
    static func havdala(_ lang: Lang) -> String {
        pick("צאת השבת (הבדלה)", "Sortie (havdala)", "Ends (havdalah)", lang)
    }

    // MARK: Omer (miroir de `home.omerDay`)

    /// Titre court « OMER » (capitale, méta).
    static func omerTitle(_ lang: Lang) -> String {
        pick("העומר", "OMER", "OMER", lang)
    }

    /// « jour du Omer » (sous le grand chiffre). `home.omerDay` = « Omer — {n}ᵉ jour ».
    static func omerDayLabel(_ lang: Lang) -> String {
        pick("יום בעומר", "jour du Omer", "day of the Omer", lang)
    }

    /// État hors-période (aucun Omer en cours).
    static func omerNone(_ lang: Lang) -> String {
        pick("אין ספירה היום", "Pas de Omer aujourd'hui", "No Omer today", lang)
    }

    // MARK: Zmanim (libellés courts, colonne widget)

    /// Libellé court d'un zman par `ZmanKey.rawValue`. Repli : la clé brute.
    static func zmanLabel(_ key: String, _ lang: Lang) -> String {
        switch key {
        case ZmanKey.hanetzHachama.rawValue:
            return pick("הנץ החמה", "Lever (netz)", "Sunrise", lang)
        case ZmanKey.sofZmanShmaGRA.rawValue:
            return pick("סוף שמע (גר\"א)", "Fin Chéma", "Shema (GRA)", lang)
        case ZmanKey.chatzot.rawValue:
            return pick("חצות היום", "Hatzot", "Midday", lang)
        case ZmanKey.minchaGedola.rawValue:
            return pick("מנחה גדולה", "Min'ha guedola", "Mincha Gedola", lang)
        case ZmanKey.shkiaHachama.rawValue:
            return pick("שקיעה", "Chkia", "Sunset", lang)
        case ZmanKey.tzeitHakochavim.rawValue:
            return pick("צאת הכוכבים", "Tzeit", "Nightfall", lang)
        default:
            return key
        }
    }

    /// Placeholder d'un zman indisponible (latitude extrême → `date == nil`).
    static func unavailable(_ lang: Lang) -> String {
        "—"
    }
}

/// Formatage d'horaires DÉTERMINISTE, ancré sur le fuseau IANA de la ville
/// (le DST est piloté par la timezone de la ville, jamais par l'offset du
/// device — NATIVE_SPEC §3.4). Format 24 h « HH:mm », toujours affiché LTR.
enum WidgetFormat {

    /// « HH:mm » ancré sur le fuseau IANA de la ville. Sans état partagé
    /// (concurrency-safe sous strict concurrency) : un widget ne formate qu'une
    /// poignée d'horaires par recalcul, le coût d'un `DateFormatter` est négligeable.
    static func time(_ date: Date, timeZone: String, lang: Lang) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.bcp47)
        f.timeZone = TimeZone(identifier: timeZone) ?? .current
        f.setLocalizedDateFormatFromTemplate("HH:mm")
        return f.string(from: date)
    }
}
