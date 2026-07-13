//
//  CalendarView.swift
//  Moed — Écran « Calendrier » (SPEC §2.2, DESIGN §5.4, PLAN écran #2)
//
//  Vue mensuelle défilable :
//   • En-tête chrome Liquid Glass : mois + année (langue active) + chevrons
//     précédent/suivant MIROITÉS en RTL + pilule « Aujourd'hui ».
//   • `List` de `CalendarDayRow` (Component transverse) : date hébraïque +
//     grégorienne, badges d'événements colorés par catégorie
//     (fête = ner, jeûne = rose, roch hodech = twilight, omer = sage, autre = neutre).
//   • Changement de mois : chevrons OU glissement horizontal (drag), avec
//     transition de glissement respectant le sens de lecture (auto-miroité RTL),
//     et haptique `.impact(.soft)` (Haptic.monthChange, DESIGN §7).
//
//  Dépendances (CONTRACTS) :
//   • Store        → `AppState` (env), `AppState.calendar(monthOffset:)`.
//   • DesignSystem → `MoedColor`, `MoedFont`, `MoedSpace`, `.glass(_:)`,
//                    `.hebrewBalanced(_:)`, `Image.directionalMirror()`,
//                    `.haptic(_:trigger:)`, `\.moedLang`, `L10n`.
//   • Components    → `CalendarDayRow(day:)`.
//
//  Le fond « parchemin d'aube » (CanvasBackground) est posé globalement par
//  RootView ; cet écran reste donc transparent. Light mode forcé à la racine.
//

import SwiftUI

struct CalendarView: View {

    // Store racine (Observation, injecté par RootView via `.environment(appState)`).
    @Environment(AppState.self) private var appState

    // Langue active + direction (posées à la racine). `moedLang` pilote polices
    // hébreu/latin et le +4 % hébreu ; `layoutDirection` pilote le miroir RTL.
    @Environment(\.moedLang) private var lang
    @Environment(\.layoutDirection) private var layoutDirection

    // Accessibilité : Reduce Motion → glissements remplacés par des fondus (DESIGN §6/§10).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var vm = CalendarViewModel()

    // Durée/courbe du « moment » de transition de mois (DESIGN §6).
    private var monthAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.42)
    }

    // MARK: - Corps

    var body: some View {
        NavigationStack {
            ZStack {
                monthContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()                                  // borne le glissement horizontal
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipe)            // n'entrave pas le scroll vertical de la List
            .animation(monthAnimation, value: vm.monthOffset)
            // En-tête chrome verre : le contenu défile dessous et le réfracte.
            .safeAreaInset(edge: .top, spacing: 0) { headerBar }
            .background(Color.clear)                     // canvas global (RootView)
            .toolbar(.hidden, for: .navigationBar)       // en-tête custom, pas de nav bar système
            // Haptique unique par changement de mois (chevron OU swipe).
            .haptic(.monthChange, trigger: vm.monthOffset)
            .onAppear { vm.onAppear(appState) }
            // Recalcul offline instantané quand ville / minhag / région / langue changent.
            .onChange(of: appState.settings) { _, _ in vm.reload(appState) }
        }
    }

    // MARK: - En-tête « mois + année » + navigation

    private var headerBar: some View {
        HStack(spacing: MoedSpace.s8) {
            Text(vm.headerTitle(lang: lang))
                .font(MoedFont.title1(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.opacity)             // cross-fade du titre au changement de mois
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: MoedSpace.s8)

            navControls
        }
        .padding(.horizontal, MoedSpace.pagePadding)
        .padding(.vertical, MoedSpace.s12)
        .frame(maxWidth: .infinity)
        .glass(.chrome)                                  // Liquid Glass iOS 26 + fallback iOS 17 (GlassBackground)
        .animation(monthAnimation, value: vm.monthOffset)
    }

    private var navControls: some View {
        HStack(spacing: MoedSpace.s4) {
            // « Précédent » : action figée (mois − 1) ; seul le VISUEL se miroite en RTL.
            navButton(
                system: "chevron.left",
                label: L10n.t("calendar.prevMonth", lang)
            ) { vm.step(-1, app: appState) }

            // Pilule « Aujourd'hui » (retour à l'offset 0), désactivée si déjà sur le mois courant.
            Button { vm.goToday(appState) } label: {
                Text(L10n.t("calendar.today", lang))
                    .font(MoedFont.caption(lang))
                    .hebrewBalanced(lang)
                    .foregroundStyle(vm.monthOffset == 0 ? MoedColor.inkMute : MoedColor.ner)
                    .padding(.horizontal, MoedSpace.s12)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .disabled(vm.monthOffset == 0)
            .accessibilityLabel(L10n.t("calendar.today", lang))

            // « Suivant » : action figée (mois + 1) ; visuel miroité en RTL.
            navButton(
                system: "chevron.right",
                label: L10n.t("calendar.nextMonth", lang)
            ) { vm.step(1, app: appState) }
        }
    }

    /// Bouton chevron : cible tactile ≥ 44 pt (DESIGN §10), icône directionnelle
    /// miroitée en RTL (DESIGN §8) via `Image.directionalMirror()`.
    private func navButton(
        system: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .directionalMirror()                     // doit être appelé sur l'Image brute (CONTRACTS §2.5)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MoedColor.inkSoft)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Contenu défilable (liste des jours du mois)

    /// La liste est identifiée par `monthOffset` : à chaque changement de mois,
    /// SwiftUI la remplace → la transition de glissement s'applique (in/out).
    private var monthContent: some View {
        Group {
            if vm.days.isEmpty {
                // Le moteur est synchrone/offline → un mois n'est jamais vide en
                // pratique. Cadre transparent le temps du 1er `reload` (pas un stub).
                Color.clear
            } else {
                List(vm.days) { day in
                    CalendarDayRow(day: day)                 // Component : date héb+grég + badges catégorie
                        .listRowInsets(EdgeInsets(
                            top: MoedSpace.s4,
                            leading: MoedSpace.s16,
                            bottom: MoedSpace.s4,
                            trailing: MoedSpace.s16
                        ))
                        .listRowSeparator(.hidden)           // les lignes sont des cartes cardSolid autonomes
                        .listRowBackground(Color.clear)      // fond canvas transparent (DESIGN §5.4)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 44)  // cibles tactiles
            }
        }
        .id(vm.monthOffset)
        .transition(monthTransition)
    }

    // MARK: - Transition & geste de changement de mois

    /// Glissement horizontal respectant le sens de lecture : `.move(edge:)`
    /// utilise des arêtes LOGIQUES (`.leading`/`.trailing`) → auto-miroitées en
    /// RTL ; `isForward` inverse l'orientation passé/futur. Reduce Motion → fondu.
    private var monthTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let insertionEdge: Edge = vm.isForward ? .trailing : .leading
        let removalEdge: Edge = vm.isForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    /// Swipe horizontal → mois précédent/suivant, sans bloquer le scroll vertical
    /// (`simultaneousGesture`). On n'agit qu'à la fin, si le geste est nettement
    /// horizontal. Le mappage swipe→direction s'inverse en RTL pour rester naturel.
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.2, abs(dx) > 56 else { return }
                let swipeLeft = dx < 0
                // LTR : swipe vers la gauche = mois suivant. RTL : inverse.
                let forward = (layoutDirection == .leftToRight) ? swipeLeft : !swipeLeft
                vm.step(forward ? 1 : -1, app: appState)
            }
    }
}

// MARK: - Preview

#Preview("Calendrier — FR") {
    CalendarView()
        .environment(AppState())
        .environment(\.moedLang, .fr)
        .environment(\.layoutDirection, .leftToRight)
        .preferredColorScheme(.light)
}

#Preview("Calendrier — HE (RTL)") {
    CalendarView()
        .environment(AppState())
        .environment(\.moedLang, .he)
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.light)
}
