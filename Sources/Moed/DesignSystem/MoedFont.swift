//
//  MoedFont.swift
//  Moed — DesignSystem
//
//  Échelle typographique (DESIGN.md §3 / CONTRACTS.md §2.2).
//
//  Deux familles Display (latin Fraunces / hébreu Frank Ruhl Libre) pour les
//  titres et TOUS les chiffres d'horaires ; deux familles Body (latin Instrument
//  Sans / hébreu Assistant) pour l'UI. Polices embarquées (self-hosted, zéro
//  requête réseau), déclarées via `UIAppFonts` dans Info.plist.
//
//  • Chaque style est mappé à un `Font.TextStyle` Apple → respecte Dynamic Type.
//  • Le sélecteur latin/hébreu se fait par la `Lang` active.
//  • Les horaires (`zmanTime`) sont TOUJOURS `.monospacedDigit()` (tabular).
//  • L'équilibre hébreu +4 % est appliqué par le modifier `.hebrewBalanced(_:)`
//    (voir plus bas) — il n'est PAS re-baké dans les tailles ci-dessous, pour
//    garder une seule source de vérité du facteur d'échelle.
//
//  `Lang` est défini dans Engine/EngineModels.swift (CONTRACTS §1.1) —
//  DesignSystem le consomme sans le redéfinir. Aucune logique métier ici.
//

import SwiftUI

public enum MoedFont {

    // MARK: - Faces embarquées (noms PostScript)

    private enum Face {
        // Display latin — Fraunces
        static let displayLatinRegular  = "Fraunces-Regular"
        static let displayLatinMedium   = "Fraunces-Medium"
        static let displayLatinSemibold = "Fraunces-SemiBold"
        // Display hébreu — Frank Ruhl Libre
        static let displayHebRegular  = "FrankRuhlLibre-Regular"
        static let displayHebMedium   = "FrankRuhlLibre-Medium"
        static let displayHebSemibold = "FrankRuhlLibre-SemiBold"
        // Body latin — Instrument Sans
        static let bodyLatinRegular  = "InstrumentSans-Regular"
        static let bodyLatinMedium   = "InstrumentSans-Medium"
        static let bodyLatinSemibold = "InstrumentSans-SemiBold"
        // Body hébreu — Assistant
        static let bodyHebRegular  = "Assistant-Regular"
        static let bodyHebMedium   = "Assistant-Medium"
        static let bodyHebSemibold = "Assistant-SemiBold"
    }

    private enum Family { case display, body }
    private enum Weight { case regular, medium, semibold }

    /// Choisit le nom de face en fonction de la famille, du poids et de la langue.
    private static func faceName(_ family: Family, _ weight: Weight, _ lang: Lang) -> String {
        let hebrew = (lang == .he)
        switch (family, weight) {
        case (.display, .regular):  return hebrew ? Face.displayHebRegular  : Face.displayLatinRegular
        case (.display, .medium):   return hebrew ? Face.displayHebMedium   : Face.displayLatinMedium
        case (.display, .semibold): return hebrew ? Face.displayHebSemibold : Face.displayLatinSemibold
        case (.body, .regular):     return hebrew ? Face.bodyHebRegular     : Face.bodyLatinRegular
        case (.body, .medium):      return hebrew ? Face.bodyHebMedium      : Face.bodyLatinMedium
        case (.body, .semibold):    return hebrew ? Face.bodyHebSemibold    : Face.bodyLatinSemibold
        }
    }

    /// Construit un `Font` custom relié à un `TextStyle` Apple (Dynamic Type).
    /// Si la police custom manque, iOS retombe automatiquement sur la métrique
    /// système reliée au même `TextStyle` — jamais d'écran nu (DESIGN §3).
    private static func font(_ family: Family,
                             _ weight: Weight,
                             size: CGFloat,
                             relativeTo textStyle: Font.TextStyle,
                             lang: Lang) -> Font {
        Font.custom(faceName(family, weight, lang), size: size, relativeTo: textStyle)
    }

    // MARK: - Styles (CONTRACTS §2.2 — signatures gelées)

    /// 40 Semibold Display — chiffre d'allumage, grand horaire. `.largeTitle`
    public static func hero(_ lang: Lang) -> Font {
        font(.display, .semibold, size: 40, relativeTo: .largeTitle, lang: lang)
    }

    /// 30 Semibold Display — date hébraïque en tête. `.title`
    public static func title1(_ lang: Lang) -> Font {
        font(.display, .semibold, size: 30, relativeTo: .title, lang: lang)
    }

    /// 24 Medium Display — titre de carte / section. `.title2`
    public static func title2(_ lang: Lang) -> Font {
        font(.display, .medium, size: 24, relativeTo: .title2, lang: lang)
    }

    /// 20 Medium Display — nom de tsadik, sous-titre fort. `.title3`
    public static func title3(_ lang: Lang) -> Font {
        font(.display, .medium, size: 20, relativeTo: .title3, lang: lang)
    }

    /// 16 Regular Body — corps courant. `.body`
    public static func body(_ lang: Lang) -> Font {
        font(.body, .regular, size: 16, relativeTo: .body, lang: lang)
    }

    /// 16 Semibold Body — label de zman, nom en liste. `.body`
    public static func bodyEmph(_ lang: Lang) -> Font {
        font(.body, .semibold, size: 16, relativeTo: .body, lang: lang)
    }

    /// 15 Regular Body — descriptions secondaires. `.callout`
    public static func callout(_ lang: Lang) -> Font {
        font(.body, .regular, size: 15, relativeTo: .callout, lang: lang)
    }

    /// 13 Medium Body — badges, méta, sources. `.caption`
    public static func caption(_ lang: Lang) -> Font {
        font(.body, .medium, size: 13, relativeTo: .caption, lang: lang)
    }

    /// 11 Semibold Body — labels d'onglet, uppercase +8 % tracking. `.caption2`
    ///
    /// Le tracking (+8 %) et l'`.uppercased()` sont appliqués côté vue (le
    /// tracking hébreu doit rester à 0 — DESIGN §3.1) ; ici seule la face/taille.
    public static func micro(_ lang: Lang) -> Font {
        font(.body, .semibold, size: 11, relativeTo: .caption2, lang: lang)
    }

    /// 22 Medium Display — **horaire**. `.monospacedDigit()` OBLIGATOIRE :
    /// les colonnes d'heures s'empilent parfaitement et le compte à rebours ne
    /// « saute » pas à chaque seconde (DESIGN §3.1 / §12). Pas de `TextStyle`
    /// dédié Apple → relié à `.title2` pour le Dynamic Type.
    public static func zmanTime(_ lang: Lang) -> Font {
        font(.display, .medium, size: 22, relativeTo: .title2, lang: lang)
            .monospacedDigit()
    }
}

// MARK: - Équilibre hébreu +4 %

/// Applique le multiplicateur d'échelle ×1.04 quand la langue est l'hébreu.
///
/// L'hébreu « pèse » moins que le latin à taille égale ; +4 % rééquilibre la
/// couleur typographique (DESIGN §3.1 / §8). Implémenté comme un léger
/// `scaleEffect` centré (le facteur est faible → aucun reflow perceptible) afin
/// de rester l'unique source du facteur d'échelle (voir note `MoedFont`).
private struct HebrewBalanced: ViewModifier {
    let lang: Lang
    func body(content: Content) -> some View {
        content.scaleEffect(lang == .he ? 1.04 : 1.0, anchor: .center)
    }
}

public extension View {
    /// Rééquilibre l'échelle typographique en hébreu (×1.04). No-op en fr/en.
    /// À apposer sur un `Text` (ou un petit conteneur de texte) rendu avec `MoedFont`.
    func hebrewBalanced(_ lang: Lang) -> some View {
        modifier(HebrewBalanced(lang: lang))
    }
}
