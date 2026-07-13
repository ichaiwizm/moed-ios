//
//  WidgetTypography.swift
//  Moed — Shared (double target membership : Moed + MoedWidgets)
//
//  Typographie et helpers RTL DÉDIÉS aux widgets (DESIGN.md §3 / §11).
//
//  Les faces embarquées (Fraunces / Frank Ruhl Libre / Instrument Sans /
//  Assistant) sont déclarées `UIAppFonts` et livrées dans les DEUX cibles ; on
//  réutilise leurs noms PostScript. Si une face manque, iOS retombe sur la
//  métrique système reliée au même `TextStyle` (jamais d'écran nu).
//
//  Règles DA reprises telles quelles :
//   • Titres & chiffres → Display (latin Fraunces / hébreu Frank Ruhl Libre).
//   • UI / labels        → Body (latin Instrument Sans / hébreu Assistant).
//   • Horaires & comptes à rebours → `.monospacedDigit()` OBLIGATOIRE (tabular),
//     et TOUJOURS forcés en LTR (`18:42` ne s'inverse pas en hébreu — DESIGN §8).
//   • Hébreu +4 % : appliqué par `.hebrewBalanced(_:)` côté vue.
//

import SwiftUI

/// Échelle typographique des widgets. Signatures paramétrées par `Lang`
/// (sélection latin/hébreu), miroir minimal de `MoedFont` limité aux styles que
/// les widgets utilisent réellement.
enum WidgetFont {

    // Noms PostScript des faces embarquées (identiques à MoedFont.Face).
    private enum Face {
        static let displayLatinMedium   = "Fraunces-Medium"
        static let displayLatinSemibold = "Fraunces-SemiBold"
        static let displayHebMedium     = "FrankRuhlLibre-Medium"
        static let displayHebSemibold   = "FrankRuhlLibre-SemiBold"
        static let bodyLatinRegular     = "InstrumentSans-Regular"
        static let bodyLatinMedium      = "InstrumentSans-Medium"
        static let bodyLatinSemibold    = "InstrumentSans-SemiBold"
        static let bodyHebRegular       = "Assistant-Regular"
        static let bodyHebMedium        = "Assistant-Medium"
        static let bodyHebSemibold      = "Assistant-SemiBold"
    }

    private static func display(_ semibold: Bool, _ lang: Lang) -> String {
        let heb = lang == .he
        if semibold { return heb ? Face.displayHebSemibold : Face.displayLatinSemibold }
        return heb ? Face.displayHebMedium : Face.displayLatinMedium
    }

    private static func body(_ weight: Font.Weight, _ lang: Lang) -> String {
        let heb = lang == .he
        switch weight {
        case .semibold: return heb ? Face.bodyHebSemibold : Face.bodyLatinSemibold
        case .medium:   return heb ? Face.bodyHebMedium   : Face.bodyLatinMedium
        default:        return heb ? Face.bodyHebRegular  : Face.bodyLatinRegular
        }
    }

    /// Très grand chiffre Display (numéro de Omer, heure d'allumage héro).
    static func hero(_ lang: Lang, size: CGFloat = 40) -> Font {
        .custom(display(true, lang), size: size, relativeTo: .largeTitle)
    }

    /// Titre de widget (nom de section, « Prochain Chabbat »).
    static func title(_ lang: Lang, size: CGFloat = 17) -> Font {
        .custom(display(false, lang), size: size, relativeTo: .headline)
    }

    /// Horaire tabular (colonne de zmanim, heure d'allumage). Monospaced digits.
    static func time(_ lang: Lang, size: CGFloat = 20) -> Font {
        .custom(display(false, lang), size: size, relativeTo: .title3).monospacedDigit()
    }

    /// Compte à rebours (`Text(_, style: .timer)`), tabular pour ne pas « sauter ».
    static func timer(_ lang: Lang, size: CGFloat = 22) -> Font {
        .custom(display(true, lang), size: size, relativeTo: .title2).monospacedDigit()
    }

    /// Label courant (nom de zman, parasha).
    static func label(_ lang: Lang, size: CGFloat = 14) -> Font {
        .custom(body(.medium, lang), size: size, relativeTo: .subheadline)
    }

    /// Label fort (en-tête de ligne surlignée).
    static func labelEmph(_ lang: Lang, size: CGFloat = 14) -> Font {
        .custom(body(.semibold, lang), size: size, relativeTo: .subheadline)
    }

    /// Méta / capitale (« OMER », sous-titre discret).
    static func caption(_ lang: Lang, size: CGFloat = 11) -> Font {
        .custom(body(.semibold, lang), size: size, relativeTo: .caption2)
    }
}

// MARK: - RTL : chiffres forcés en LTR

/// Force la lecture LTR sur son contenu (heures, comptes à rebours) même dans un
/// widget hébreu RTL — `18:42` reste `18:42`, aligné naturellement (DESIGN §8).
/// Équivalent widget de `ForceLTR` (DesignSystem, cible app).
struct WidgetLTR<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Équilibre hébreu +4 %

private struct WidgetHebrewBalanced: ViewModifier {
    let lang: Lang
    func body(content: Content) -> some View {
        content.scaleEffect(lang == .he ? 1.04 : 1.0, anchor: .center)
    }
}

extension View {
    /// Rééquilibre l'échelle typographique en hébreu (×1.04). No-op en fr/en.
    /// Nom préfixé `widget…` pour ne pas entrer en collision avec
    /// `MoedFont`'s `hebrewBalanced(_:)` (les deux sont compilés dans la cible app).
    func widgetHebrewBalanced(_ lang: Lang) -> some View {
        modifier(WidgetHebrewBalanced(lang: lang))
    }
}
