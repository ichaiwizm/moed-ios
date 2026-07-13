//
//  BackgroundRefresh.swift
//  Moed — MODULE « Notifications » (CONTRACTS.md §4.4, SPEC §9, PLAN §8)
//
//  Re-remplissage EN TÂCHE DE FOND de la fenêtre glissante de notifications.
//  ------------------------------------------------------------------------
//  La fenêtre planifiée par `NotificationScheduler` est bornée (budget < 64,
//  limite iOS). Elle est reconstruite à chaque ouverture de l'app, mais si
//  l'utilisateur n'ouvre pas Moed pendant plusieurs semaines, les rappels
//  planifiés s'épuisent. `BGTaskScheduler` réveille l'app périodiquement pour
//  RE-CALCULER (offline, déterministe) et re-remplir la fenêtre.
//
//  Cycle de vie :
//    • `register()` — appelé UNE fois au lancement (dans `MoedApp.init`), AVANT
//      la fin du démarrage : enregistre le handler pour l'identifiant BGTask.
//    • `schedule()` — soumet une nouvelle demande (à l'arrière-plan / à la mise
//      en veille) ; le handler ré-appelle `schedule()` pour s'auto-perpétuer.
//
//  L'identifiant `com.wizycode.moed.refresh` est déclaré dans
//  `Info.plist` → `BGTaskSchedulerPermittedIdentifiers` (déjà présent).
//
//  Tout est recalculé localement à partir de l'état persisté :
//  `SettingsStore` + `FamilyStore` + `StaticData` — AUCUN réseau (SPEC règle
//  d'or n°1). Dépendances : Store, Data, Engine (via NotificationScheduler).
//

import Foundation

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// Orchestrateur des tâches de fond de replanification. `enum` sans cas.
public enum BackgroundRefresh {

    /// Identifiant de la tâche — DOIT correspondre à `Info.plist`
    /// (`BGTaskSchedulerPermittedIdentifiers`).
    public static let taskIdentifier = "com.wizycode.moed.refresh"

    /// Délai minimal avant la prochaine exécution en fond (le système décide de
    /// l'instant réel selon l'usage). ~12 h : bien assez fin pour re-remplir une
    /// fenêtre de plusieurs semaines.
    private static let refreshInterval: TimeInterval = 12 * 60 * 60

    // MARK: - Enregistrement (lancement)

    /// Enregistre le handler de la tâche de fond. À appeler dans `MoedApp.init`,
    /// avant la fin du démarrage (exigence `BGTaskScheduler`). Idempotent au sens
    /// où iOS n'autorise qu'un enregistrement par identifiant et par cycle de vie.
    public static func register() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            handle(task)
        }
        #endif
    }

    // MARK: - Planification

    /// Soumet une demande de réveil en fond. À appeler quand l'app passe en
    /// arrière-plan (et de nouveau depuis le handler pour s'auto-perpétuer).
    public static func schedule() {
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Échec bénin (simulateur, budget système saturé, mode avion des
            // tâches de fond) : la replanification à la prochaine OUVERTURE de
            // l'app couvre le cas — les rappels ne sont jamais perdus.
        }
        #endif
    }

    // MARK: - Exécution

    #if canImport(BackgroundTasks)
    /// Traite un réveil : reprogramme le suivant, recalcule la fenêtre depuis
    /// l'état persisté, puis clôt la tâche. Borné par un `expirationHandler`.
    private static func handle(_ task: BGTask) {
        // 1. Perpétuer le cycle immédiatement (avant tout travail susceptible
        //    d'expirer) afin de ne jamais casser la chaîne de réveils.
        schedule()

        // 2. Reconstituer le contexte 100 % offline depuis les préférences persistées.
        let settings = SettingsStore.load()
        let family = FamilyStore.load()
        let city = StaticData.city(slug: settings.citySlug)
        let geo = city.geoContext(candleMode: settings.candle)
        let lang = settings.lang ?? Lang.fromSystem()

        // 3. Re-remplir la fenêtre glissante, puis signaler la fin.
        //    `setTaskCompleted` n'est appelé qu'à UN seul endroit (fin du `Task`),
        //    avec le succès dérivé de l'annulation : appeler `setTaskCompleted`
        //    deux fois (fin normale + expiration) est un comportement indéfini.
        let work = Task {
            _ = await NotificationScheduler.rescheduleAndWait(
                settings: settings, family: family, geo: geo, lang: lang
            )
            task.setTaskCompleted(success: !Task.isCancelled)
        }

        // 4. Si le système reprend son budget, annuler proprement : le `Task`
        //    ci-dessus détecte l'annulation et clôt la tâche avec `success: false`.
        task.expirationHandler = {
            work.cancel()
        }
    }
    #endif
}
