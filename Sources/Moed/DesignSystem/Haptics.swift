//
//  Haptics.swift
//  Moed — DesignSystem
//
//  Haptique sémantique, discrète, jamais gratuite (DESIGN.md §7 / CONTRACTS.md §2.5).
//  Wrappe `.sensoryFeedback` (iOS 17+). JAMAIS d'haptique sur le scroll, le tick
//  de seconde, ou l'apparition de contenu (DESIGN §7).
//
//  Aucune logique métier ici.
//

import SwiftUI

/// Événements haptiques sémantiques de Moed (CONTRACTS §2.5 — cas gelés).
public enum Haptic {
    /// Sélection d'onglet, segmented, ville.
    case selection
    /// Ajout d'un proche (succès).
    case success
    /// Suppression (swipe confirmé) — impact rigide léger.
    case remove
    /// Erreur de saisie (date invalide converter).
    case error
    /// Changement de mois (calendrier) — impact soft.
    case monthChange
    /// Toggle notification activé — impact léger.
    case toggleOn
    /// Entrée du Chabbat (compte à rebours atteint 00:00) — succès doux.
    case shabbatEntry

    /// Traduction vers le retour sensoriel système.
    fileprivate var feedback: SensoryFeedback {
        switch self {
        case .selection:    return .selection
        case .success:      return .success
        case .remove:       return .impact(flexibility: .rigid, intensity: 0.7)
        case .error:        return .error
        case .monthChange:  return .impact(flexibility: .soft)
        case .toggleOn:     return .impact(weight: .light)
        case .shabbatEntry: return .success
        }
    }
}

public extension View {
    /// Déclenche un retour haptique sémantique quand `trigger` change.
    /// Ex. `.haptic(.selection, trigger: selectedTab)`.
    func haptic<T: Equatable>(_ h: Haptic, trigger: T) -> some View {
        sensoryFeedback(h.feedback, trigger: trigger)
    }
}
