//
//  MoedApp.swift
//  Moed — מועד, « le temps fixé »
//
//  Point d'entrée de l'application (CONTRACTS.md §4.1).
//  @main → injecte l'AppState racine en environment, pose la langue active
//  (moedLang), la direction de lecture (RTL si hébreu) et FORCE le light mode
//  en v1 (DESIGN.md §9 — le parchemin d'aube EST l'identité de Moed).
//
//  100 % offline : aucun réseau au runtime. Le seul cycle de vie « externe »
//  ici est l'enregistrement des tâches de fond (BGTaskScheduler) qui
//  replanifient localement les notifications déterministes (SPEC §9).
//

import SwiftUI

@main
struct MoedApp: App {

    /// État racine observable (Observation framework, iOS 17).
    /// Charge settings + carnet familial depuis le container App Group,
    /// expose les dérivés synchrones (ville, geo, langue, direction).
    @State private var appState = AppState()

    /// Suivi du cycle de vie pour replanifier la fenêtre glissante de notifs.
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // L'enregistrement des identifiants BGTask DOIT avoir lieu au lancement,
        // avant la fin de `application(_:didFinishLaunchingWithOptions:)`.
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // AppState observable partagé à tout l'arbre de vues.
                .environment(appState)
                // Langue active (nil settings → langue système au 1er lancement).
                .environment(\.moedLang, appState.lang)
                // RTL première classe : hébreu → .rightToLeft, fr/en → .leftToRight.
                // Posé à la racine → SwiftUI miroite automatiquement toute l'UI
                // (TabBar, paddings logiques, chevrons directionnels).
                .environment(\.layoutDirection, appState.layoutDirection)
                // Light mode forcé en v1 (dark préparé mais non branché, DESIGN §9).
                .preferredColorScheme(.light)
                // Transition douce quand la langue/direction change in-app,
                // sans redémarrage (DESIGN §8).
                .animation(.smooth(duration: 0.5), value: appState.lang)
        }
        .onChange(of: scenePhase) { _, phase in
            // Au passage en arrière-plan : (re)planifier la tâche de fond qui
            // re-remplira la fenêtre glissante de notifications locales.
            if phase == .background {
                BackgroundRefresh.schedule()
            }
        }
    }
}
