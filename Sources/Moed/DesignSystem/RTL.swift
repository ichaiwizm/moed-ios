//
//  RTL.swift
//  Moed — DesignSystem
//
//  RTL & hébreu, citoyens de première classe (DESIGN.md §8 / CONTRACTS.md §2.5-§2.6).
//
//  • `ForceLTR` : force la direction gauche→droite pour les CHIFFRES d'horaires
//    et les comptes à rebours, afin que `18:42` reste `18:42` (et non inversé) même
//    dans une ligne hébraïque RTL, tout en s'alignant naturellement à droite.
//    Équivalent d'un `unicode-bidi: plaintext` sur les nombres.
//  • `Image.directionalMirror()` : miroite les icônes DIRECTIONNELLES (chevrons,
//    flèches « voir plus », back) en RTL. À N'UTILISER JAMAIS sur les icônes non
//    directionnelles (bougie `flame`, lune `moon`, localisation, feuille).
//  • `moedLang` : langue active exposée dans l'environnement. La racine pose
//    `.environment(\.moedLang, appState.lang)` et
//    `.environment(\.layoutDirection, lang.dir)` (CONTRACTS §2.6 / §4.1).
//
//  `Lang` est défini dans Engine/EngineModels.swift (CONTRACTS §1.1) — consommé
//  ici sans redéfinition. Aucune logique métier.
//

import SwiftUI

// MARK: - ForceLTR (chiffres / comptes à rebours)

/// Force la direction de lecture LTR sur son contenu (heures, minuteries).
/// À envelopper autour de TOUTE heure / compte à rebours (DESIGN §8).
public struct ForceLTR<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content.environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Icônes directionnelles

public extension Image {
    /// Miroite l'image en RTL — RÉSERVÉ aux icônes directionnelles (chevrons,
    /// flèches, back). Ne jamais appliquer à bougie / lune / localisation.
    func directionalMirror() -> some View {
        self.flipsForRightToLeftLayoutDirection(true)
    }
}

// MARK: - Environnement : langue active

private struct MoedLangKey: EnvironmentKey {
    // Défaut : suit la langue système au premier lancement (CONTRACTS §2.6).
    static let defaultValue: Lang = Lang.fromSystem()
}

public extension EnvironmentValues {
    /// Langue Moed active. Défaut `Lang.fromSystem()`. Posée par la racine.
    var moedLang: Lang {
        get { self[MoedLangKey.self] }
        set { self[MoedLangKey.self] = newValue }
    }
}
