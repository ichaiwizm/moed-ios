//
//  RootView.swift
//  Moed
//
//  Coquille de navigation (CONTRACTS.md §4.1, DESIGN.md §5.7).
//  TabView à 5 onglets FIGÉS (today / calendar / personal / tsadikim / settings),
//  ordre logique → miroité automatiquement en RTL (Aujourd'hui à droite en hébreu).
//  Onglet actif teinté `ner`, inactif `inkMute`, label `micro`.
//  `CanvasBackground` global (parchemin d'aube immobile) derrière tout le contenu.
//
//  Chaque onglet possède SON propre `NavigationStack` (porté par l'écran lui-même,
//  qui pousse ses détails : TsadikDetailView, ZmanimCityView, ConverterView…).
//  Sous iOS 26, la TabBar devient Liquid Glass automatiquement et réfracte le
//  contenu qui scrolle dessous ; sous iOS 17–25 elle retombe sur le material
//  système. Aucune fonctionnalité ne dépend du verre (habillage progressif).
//

import SwiftUI

struct RootView: View {

    @Environment(\.moedLang) private var lang
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Onglet sélectionné. L'ordre des `case` est l'ordre LOGIQUE ;
    /// SwiftUI l'inverse visuellement en RTL.
    @State private var selection: Tab = .today

    /// Les 5 onglets figés du produit (SPEC §2 — clés identiques web/Android/iOS).
    enum Tab: String, Hashable, CaseIterable {
        case today, calendar, personal, tsadikim, settings

        /// Clé i18n `nav.*` (voir Localizable.strings he/fr/en).
        var titleKey: String { "nav.\(rawValue)" }

        /// Glyphe SF Symbol de l'onglet (DESIGN §5.7).
        /// Icônes NON directionnelles → jamais miroitées en RTL.
        var systemImage: String {
            switch self {
            case .today:    return "sun.max"        // soleil d'aube
            case .calendar: return "calendar"
            case .personal: return "person.2"
            case .tsadikim: return "flame"          // motif bougie / flamme
            case .settings: return "gearshape"
            }
        }
    }

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        ZStack {
            // Plan « Canvas » : fond parchemin d'aube, immobile, jamais de verre
            // (DESIGN §1). Le contenu des onglets scrolle par-dessus.
            CanvasBackground()

            TabView(selection: $selection) {
                tab(.today)    { TodayView() }
                tab(.calendar) { CalendarView() }
                tab(.personal) { PersonalView() }
                tab(.tsadikim) { TsadikimView() }
                tab(.settings) { SettingsView() }
            }
            // Onglet actif teinté flamme (DESIGN §5.7).
            .tint(MoedColor.ner)
            // Reduce Transparency : rendre la TabBar opaque et lisible (DESIGN §10).
            .toolbarBackground(
                reduceTransparency ? .visible : .automatic,
                for: .tabBar
            )
        }
        // Le changement d'onglet est un geste de sélection (haptique sémantique,
        // jamais sur scroll/tick — DESIGN §7).
        .haptic(.selection, trigger: selection)
    }

    /// Construit un onglet : contenu (l'écran porte son propre NavigationStack)
    /// + libellé `micro` localisé + glyphe. Fond transparent pour laisser
    /// transparaître le CanvasBackground.
    @ViewBuilder
    private func tab<Content: View>(
        _ id: Tab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .toolbarBackground(.hidden, for: .navigationBar)
            .tag(id)
            .tabItem {
                Label {
                    Text(L10n.t(id.titleKey, lang))
                } icon: {
                    Image(systemName: id.systemImage)
                }
            }
            .accessibilityLabel(Text(L10n.t(id.titleKey, lang)))
    }

    // MARK: - Apparence UIKit de la TabBar

    /// Configure la couleur inactive (`inkMute`) et la fonte `micro` des libellés,
    /// non exposées par l'API SwiftUI `TabView` en iOS 17. La couleur ACTIVE reste
    /// pilotée par `.tint(MoedColor.ner)`. Tolérant : si un token d'asset manque,
    /// on retombe silencieusement sur les valeurs système (jamais de crash).
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let inactive = UIColor(named: "inkMute") ?? .secondaryLabel
        // `micro` = 11pt Semibold, +8 % tracking (DESIGN §3.1).
        let microFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let inactiveAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: inactive,
            .font: microFont,
            .kern: 0.88, // ≈ +8 % de 11pt
        ]

        for item in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            item.normal.iconColor = inactive
            item.normal.titleTextAttributes = inactiveAttrs
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#if DEBUG
#Preview {
    RootView()
        .environment(AppState())
        .environment(\.moedLang, .fr)
        .preferredColorScheme(.light)
}
#endif
