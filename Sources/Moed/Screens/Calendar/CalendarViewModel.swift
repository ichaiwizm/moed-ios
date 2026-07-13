//
//  CalendarViewModel.swift
//  Moed — Écran « Calendrier » (SPEC §2.2, DESIGN §5.4)
//
//  Rôle : gérer l'état de navigation mensuelle (`monthOffset`) et exposer les
//  jours du mois affiché. Le ViewModel NE RECALCULE JAMAIS lui-même
//  (CONTRACTS §4.3) : il délègue tout à `AppState.calendar(monthOffset:)`, qui
//  route vers `CalendarEngine.range(...)` (offline, déterministe). Il ne fait
//  que mémoriser l'offset, conserver le résultat et formater le titre du mois.
//
//  Parité web : `mvp-moed/src/app/[locale]/calendar/page.tsx` — la vue est une
//  fenêtre GRÉGORIENNE (base = 1er du mois courant + offset ; du 1er au dernier
//  jour du mois grégorien), titre = mois + année grégoriens dans la langue
//  active (les noms de mois grégoriens sont localisés, y compris en hébreu :
//  « יולי 2026 »). Chaque ligne affiche en plus la date hébraïque + badges.
//

import SwiftUI

@MainActor
@Observable
final class CalendarViewModel {

    // MARK: - État exposé (lecture seule pour la vue)

    /// Décalage en mois par rapport au mois courant (0 = ce mois-ci).
    /// `AppState.calendar(monthOffset:)` en est le seul interprète.
    private(set) var monthOffset: Int = 0

    /// Jours du mois affiché, produits par le moteur via `AppState`.
    /// `CalendarDay` est `Identifiable` (id = date) → directement listable.
    private(set) var days: [CalendarDay] = []

    /// Sens de la dernière transition (true = vers le futur / mois suivant).
    /// Pilote l'arête d'entrée/sortie du glissement horizontal (auto-miroité
    /// en RTL par `.move(edge:)` qui respecte `layoutDirection`).
    private(set) var isForward: Bool = true

    // MARK: - Chargement (délégué à AppState, jamais de calcul local)

    /// Premier chargement paresseux : ne recharge que si vide (évite de
    /// recalculer inutilement à chaque `onAppear` d'onglet).
    func onAppear(_ app: AppState) {
        if days.isEmpty {
            reload(app)
        }
    }

    /// Recalcule le mois courant. À rappeler quand une dépendance amont change
    /// (ville / minhag / région / langue) — le moteur relit `AppState` à jour.
    func reload(_ app: AppState) {
        days = app.calendar(monthOffset: monthOffset)
    }

    /// Avance/recule de `delta` mois (typiquement ±1) puis recharge.
    /// Mémorise le sens pour la transition de glissement. L'haptique
    /// `.monthChange` (`.impact(.soft)`, DESIGN §7) est déclenchée côté vue via
    /// `.haptic(.monthChange, trigger: monthOffset)`.
    func step(_ delta: Int, app: AppState) {
        guard delta != 0 else { return }
        isForward = delta > 0
        monthOffset += delta
        reload(app)
    }

    /// Retour au mois courant (bouton « Aujourd'hui »).
    func goToday(_ app: AppState) {
        guard monthOffset != 0 else { return }
        isForward = monthOffset < 0          // on « avance » si on revient du passé
        monthOffset = 0
        reload(app)
    }

    // MARK: - Titre de l'en-tête : « mois + année » (langue active)

    /// Date d'ancrage du mois affiché. Source de vérité = les jours réellement
    /// renvoyés par le moteur (le 1er jour EST le 1er du mois grégorien),
    /// avec repli calculé si la liste est momentanément vide.
    private var monthAnchor: Date {
        if let first = days.first?.date { return first }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return cal.date(byAdding: .month, value: monthOffset, to: startOfThisMonth) ?? Date()
    }

    /// « Juillet 2026 » / « July 2026 » / « יולי 2026 » selon la langue.
    /// Calendrier grégorien explicite (parité web `formatMonthYear`), noms
    /// localisés — hebcal/KosherCocoa ne sont PAS sollicités ici (mois
    /// grégoriens, pas hébraïques).
    func headerTitle(lang: Lang) -> String {
        let locale = Locale(identifier: lang.bcp47)
        let fmt = Self.formatter(for: lang.bcp47)
        return fmt.string(from: monthAnchor).capitalized(with: locale)
    }

    // Cache des DateFormatter par langue (leur création est coûteuse).
    private static var formatters: [String: DateFormatter] = [:]

    private static func formatter(for bcp47: String) -> DateFormatter {
        if let cached = formatters[bcp47] { return cached }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: bcp47)
        // Template → ordre mois/année adapté à la locale (année d'abord en he, etc.)
        fmt.setLocalizedDateFormatFromTemplate("yMMMM")
        formatters[bcp47] = fmt
        return fmt
    }
}
