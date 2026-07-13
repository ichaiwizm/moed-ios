//
//  SettingsView.swift
//  Moed — Screens / Settings (Réglages)
//
//  SPEC §2.5 · DESIGN §5.6. Écran « Réglages » : Langue (he/fr/en, change la
//  locale + la direction RTL/LTR EN LIVE, sans redémarrage, transition `.smooth`),
//  Localisation (ouvre `CitySearchView` : filtre des 191 villes + « autour de moi »
//  via `LocationProvider`), Minhag (minutes d'allumage segmented auto/18/20/30/40,
//  shita de tzeit degrés/minutes, région auto/il/diaspora) et Notifications
//  (toggles opt-in — la permission système est demandée AU MOMENT de l'activation,
//  jamais au lancement — SPEC §9).
//
//  Cet écran CONSOMME uniquement l'API contractuelle d'`AppState` (CONTRACTS §4.2) :
//  toute mutation passe par `AppState.update(settings:)`, qui persiste (App Group),
//  recalcule les dérivés synchrones (ville / geo / langue / direction) et replanifie
//  la fenêtre glissante de notifications locales. Aucun calcul halakhique ici,
//  aucun réseau : tout est offline et déterministe.
//
//  DA : contenu de lecture posé sur des cartes OPAQUES (`SectionCard` = cardSolid),
//  jamais de verre sous le contenu ; le verre reste au chrome (en-tête flottant).
//  La couleur « flamme » (ner) ne ponctue que les états sélectionnés / actifs.
//  RTL première classe : propriétés logiques uniquement (leading/trailing), chevrons
//  directionnels miroités, icônes non directionnelles (localisation) jamais miroitées.
//
//  Dépendances DesignSystem : MoedColor / MoedFont / MoedSpace / MoedRadius /
//  MoedElevation / `.glass(_:)` / `.hebrewBalanced(_:)` / `Image.directionalMirror()`
//  / `.haptic(_:trigger:)` / `\.moedLang` + i18n `L10n`. Composant `SectionCard`.
//

import SwiftUI
import UserNotifications

// MARK: - SettingsView

struct SettingsView: View {

    // Store racine (Observation, injecté par RootView via `.environment(appState)`).
    @Environment(AppState.self) private var app

    // Langue active + direction posées à la racine (pilotent police hébreu/latin,
    // +4 % hébreu, et le miroir RTL des chevrons / paddings logiques).
    @Environment(\.moedLang) private var lang

    // Accessibilité : Reduce Motion → révélation en fondu simple, pas de cascade
    // ni de glissement (DESIGN §6 / §10).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Présentation de la feuille de recherche de ville (CitySearchView).
    @State private var showCitySearch = false

    // Passage à `true` si l'utilisateur a REFUSÉ la permission système de
    // notifications lors d'un opt-in → on affiche une aide « Réglages iOS ».
    @State private var notifDenied = false

    // Déclencheur d'haptique `.toggleOn` (change à chaque activation ACCORDÉE).
    @State private var toggleOnTick = 0

    // MARK: - Corps

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MoedSpace.interCard) {
                    languageSection.reveal(index: 0, reduceMotion: reduceMotion)
                    locationSection.reveal(index: 1, reduceMotion: reduceMotion)
                    minhagSection.reveal(index: 2, reduceMotion: reduceMotion)
                    notificationsSection.reveal(index: 3, reduceMotion: reduceMotion)
                }
                .padding(.horizontal, MoedSpace.pagePadding)
                .padding(.top, MoedSpace.s16)
                .padding(.bottom, MoedSpace.s56)   // dégage la TabBar verre flottante
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)                 // canvas global (RootView)
            .safeAreaInset(edge: .top, spacing: 0) { headerBar }
            .toolbar(.hidden, for: .navigationBar)    // en-tête custom, pas de nav bar système
            // Haptique de sélection : minhag (candle / tzeit / région) + langue.
            // Chaque changement de valeur (jamais l'apparition) déclenche `.selection`.
            .haptic(.selection, trigger: app.settings.candle)
            .haptic(.selection, trigger: app.settings.tzeit)
            .haptic(.selection, trigger: app.settings.region)
            .haptic(.selection, trigger: lang)
            // Toggle notification activé (accordé) — impact léger (DESIGN §7).
            .haptic(.toggleOn, trigger: toggleOnTick)
            // Feuille de recherche de ville (filtre 191 villes + « autour de moi »).
            .sheet(isPresented: $showCitySearch) {
                CitySearchView(currentSlug: app.settings.citySlug) { city in
                    selectCity(city)
                }
            }
        }
    }

    // MARK: - En-tête chrome (Liquid Glass)

    /// Bandeau verre au sommet : le contenu défile dessous et le réfracte
    /// (iOS 26) ; fallback material + Reduce Transparency gérés par `.glass`.
    private var headerBar: some View {
        HStack {
            Text(L10n.t("settings.title", lang))
                .font(MoedFont.title1(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MoedSpace.pagePadding)
        .padding(.vertical, MoedSpace.s12)
        .frame(maxWidth: .infinity)
        .glass(.chrome)
    }

    // MARK: - 1. Langue (change locale + RTL EN LIVE, transition douce)

    private var languageSection: some View {
        SectionCard(title: L10n.t("settings.language", lang)) {
            MoedSegmented(
                options: [Lang.he, .fr, .en],
                selected: lang,
                title: { Self.endonym($0) },
                font: { MoedFont.bodyEmph($0) },   // chaque endonyme dans sa propre face
                accessibilityLabel: { Self.endonym($0) },
                onSelect: setLanguage
            )
        }
    }

    // MARK: - 2. Localisation (ville active → CitySearchView)

    private var locationSection: some View {
        SectionCard(title: L10n.t("settings.location", lang)) {
            Button {
                showCitySearch = true
            } label: {
                HStack(spacing: MoedSpace.s12) {
                    // Icône NON directionnelle (localisation) → jamais miroitée (DESIGN §8).
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MoedColor.ner)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: MoedSpace.s2) {
                        Text(app.city.names(lang))
                            .font(MoedFont.bodyEmph(lang))
                            .foregroundStyle(MoedColor.ink)
                            .hebrewBalanced(lang)
                        Text(app.city.countryNames(lang))
                            .font(MoedFont.caption(lang))
                            .foregroundStyle(MoedColor.inkMute)
                            .hebrewBalanced(lang)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Chevron DIRECTIONNEL → miroité en RTL (DESIGN §8).
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MoedColor.inkMute)
                        .directionalMirror()
                }
                .padding(.vertical, MoedSpace.s2)
                .frame(minHeight: 44)              // cible tactile ≥ 44 pt (DESIGN §10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("common.changeCity", lang))
            .accessibilityValue("\(app.city.names(lang)), \(app.city.countryNames(lang))")
        }
    }

    // MARK: - 3. Minhag & shita

    private var minhagSection: some View {
        SectionCard(title: L10n.t("settings.minhag", lang)) {
            VStack(alignment: .leading, spacing: MoedSpace.s20) {

                // Minutes d'allumage : auto (= minhag de la ville) / 18 / 20 / 30 / 40.
                settingBlock(
                    label: L10n.t("settings.candleMinutes", lang),
                    caption: candleCaption
                ) {
                    MoedSegmented(
                        options: Self.candleOptions,
                        selected: app.settings.candle,
                        title: { Self.candleLabel($0, lang: lang) },
                        accessibilityLabel: { Self.candleLabel($0, lang: lang) },
                        onSelect: { mode in mutate { $0.candle = mode } }
                    )
                }

                CardDivider()

                // Shita de tzeit / havdala : 8,5° (« 3 étoiles ») ou offset fixe.
                settingBlock(label: L10n.t("settings.tzeitShita", lang)) {
                    MoedSegmented(
                        options: [TzeitMethod.degrees, .minutes],
                        selected: app.settings.tzeit,
                        title: { Self.tzeitLabel($0, lang: lang) },
                        accessibilityLabel: { Self.tzeitLabel($0, lang: lang) },
                        onSelect: { m in mutate { $0.tzeit = m } }
                    )
                }

                CardDivider()

                // Région du calendrier des fêtes / parasha / haftara.
                settingBlock(
                    label: L10n.t("settings.israelDiaspora", lang),
                    caption: regionCaption
                ) {
                    MoedSegmented(
                        options: [Region.auto, .il, .diaspora],
                        selected: app.settings.region,
                        title: { Self.regionLabel($0, lang: lang) },
                        accessibilityLabel: { Self.regionLabel($0, lang: lang) },
                        onSelect: { r in mutate { $0.region = r } }
                    )
                }
            }
        }
    }

    // MARK: - 4. Notifications (opt-in → permission à l'activation)

    private var notificationsSection: some View {
        SectionCard(title: L10n.t("settings.notifications", lang)) {
            VStack(alignment: .leading, spacing: MoedSpace.s16) {
                Text(L10n.t("settings.notifDesc", lang))
                    .font(MoedFont.callout(lang))
                    .foregroundStyle(MoedColor.inkSoft)
                    .hebrewBalanced(lang)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                notifToggle("settings.notifShabbat", \.shabbat)
                CardDivider()
                notifToggle("settings.notifOmer", \.omer)
                CardDivider()
                notifToggle("settings.notifHilula", \.hilula)
                CardDivider()
                notifToggle("settings.notifYahrzeit", \.yahrzeit)

                if notifDenied {
                    deniedHint
                }
            }
        }
    }

    /// Un toggle de rappel. La lecture reflète `Settings.notif` ; l'écriture passe
    /// par `enableNotif`, qui demande la permission système AU MOMENT de l'activation
    /// (jamais au lancement — SPEC §9). En cas de refus, la valeur reste `false`
    /// → le toggle « rebondit » visuellement en position éteinte.
    private func notifToggle(
        _ key: String,
        _ path: WritableKeyPath<NotifPrefs, Bool>
    ) -> some View {
        let binding = Binding<Bool>(
            get: { app.settings.notif[keyPath: path] },
            set: { enableNotif(path, to: $0) }
        )
        return Toggle(isOn: binding) {
            Text(L10n.t(key, lang))
                .font(MoedFont.body(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
        }
        .tint(MoedColor.ner)
        .frame(minHeight: 44)
    }

    /// Aide affichée si la permission a été refusée : lien direct vers les
    /// réglages système iOS (le prompt natif ne réapparaît pas après un refus).
    private var deniedHint: some View {
        Button {
            #if canImport(UIKit)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #endif
        } label: {
            HStack(spacing: MoedSpace.s8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MoedColor.rose)
                Text(L10n.t("settings.enableNotif", lang))
                    .font(MoedFont.caption(lang))
                    .foregroundStyle(MoedColor.rose)
                    .hebrewBalanced(lang)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MoedColor.rose)
                    .directionalMirror()
            }
            .padding(MoedSpace.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MoedColor.roseWash, in: RoundedRectangle(cornerRadius: MoedRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bloc de réglage (label + contrôle + caption optionnelle)

    /// Enveloppe un contrôle avec son intitulé (`bodyEmph`) et une légende
    /// explicative optionnelle (`caption`, `inkMute`).
    @ViewBuilder
    private func settingBlock<Control: View>(
        label: String,
        caption: String? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: MoedSpace.s8) {
            Text(label)
                .font(MoedFont.bodyEmph(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            control()
            if let caption {
                Text(caption)
                    .font(MoedFont.caption(lang))
                    .foregroundStyle(MoedColor.inkMute)
                    .hebrewBalanced(lang)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Mutations (chemin unique → AppState.update)

    /// Applique une transformation immuable des préférences puis persiste via
    /// `AppState.update(settings:)` (App Group + recalcul dérivés + reschedule notifs).
    private func mutate(_ transform: (inout Settings) -> Void) {
        var s = app.settings
        transform(&s)
        app.update(settings: s)
    }

    /// Change la langue IN-APP (indépendante de la langue système). La racine
    /// (`MoedApp`) re-pose `\.moedLang` + `\.layoutDirection` → locale ET direction
    /// RTL basculent SANS redémarrage. La transition `.smooth` enveloppe le
    /// changement (DESIGN §8) ; `MoedApp` anime déjà sur `appState.lang`, on
    /// renforce ici pour la mise à jour locale de cet écran.
    private func setLanguage(_ new: Lang) {
        guard app.lang != new else { return }
        withAnimation(.smooth(duration: 0.5)) {
            mutate { $0.lang = new }
        }
    }

    /// Définit la ville active (depuis `CitySearchView`). No-op si inchangée.
    private func selectCity(_ city: City) {
        guard city.slug != app.settings.citySlug else { return }
        mutate { $0.citySlug = city.slug }
    }

    /// Active/désactive un rappel. Désactivation : immédiate. Activation : demande
    /// la permission système à la volée ; si accordée → persiste `true` + haptique
    /// `.toggleOn` ; si refusée → reste `false` (rebond visuel) + aide « Réglages iOS ».
    private func enableNotif(_ path: WritableKeyPath<NotifPrefs, Bool>, to on: Bool) {
        guard on else {
            mutate { $0.notif[keyPath: path] = false }
            return
        }
        Task {
            let granted = await NotifPermission.ensureAuthorized()
            await MainActor.run {
                if granted {
                    notifDenied = false
                    mutate { $0.notif[keyPath: path] = true }
                    toggleOnTick &+= 1               // déclenche l'haptique .toggleOn
                } else {
                    // La valeur reste false → le Toggle rebondit en position éteinte.
                    notifDenied = true
                }
            }
        }
    }
}

// MARK: - Libellés & options (statiques, localisés)

private extension SettingsView {

    /// Options d'allumage exposées dans le segmented (SPEC §2.5 : auto/18/20/30/40).
    static let candleOptions: [CandleMode] = [.auto, .minutes(18), .minutes(20), .minutes(30), .minutes(40)]

    /// Endonyme d'affichage d'une langue (jamais traduit : chaque langue dans sa
    /// propre graphie). L'hébreu est rendu avec sa face Display via `font:`.
    static func endonym(_ l: Lang) -> String {
        switch l {
        case .he: return "עברית"
        case .fr: return "Français"
        case .en: return "English"
        }
    }

    /// Libellé COMPACT d'un segment d'allumage : « Auto » (court, localisé) ou le
    /// nombre de minutes. La description complète du mode auto est en légende.
    static func candleLabel(_ mode: CandleMode, lang: Lang) -> String {
        switch mode {
        case .auto:           return autoShort(lang)
        case .minutes(let m): return String(m)
        }
    }

    /// Libellé de la shita de tzeit (degrés vs minutes).
    static func tzeitLabel(_ m: TzeitMethod, lang: Lang) -> String {
        switch m {
        case .degrees: return L10n.t("settings.tzeitDegrees", lang)
        case .minutes: return L10n.t("settings.tzeitMinutes", lang)
        }
    }

    /// Libellé de région : « Auto » (court), « Israël », « Diaspora ».
    static func regionLabel(_ r: Region, lang: Lang) -> String {
        switch r {
        case .auto:     return autoShort(lang)
        case .il:       return L10n.t("common.israel", lang)
        case .diaspora: return L10n.t("common.diaspora", lang)
        }
    }

    /// « Auto » court, adapté à la langue (les segments doivent rester compacts).
    static func autoShort(_ lang: Lang) -> String {
        switch lang {
        case .he: return "אוטו׳"
        case .fr, .en: return "Auto"
        }
    }

    /// Légende du bloc allumage : rappelle ce que « auto » vaut pour la ville
    /// active (transparence : l'utilisateur voit le nombre de minutes effectif).
    var candleCaption: String {
        switch app.settings.candle {
        case .auto:
            let mins = app.city.candleMinutes
            return "\(L10n.t("settings.candleAuto", lang)) — \(app.city.names(lang)) : \(mins) min"
        case .minutes(let m):
            return "\(m) min"
        }
    }

    /// Légende du bloc région : en mode auto, expose la région effective déduite
    /// de la ville (Israël vs diaspora) — l'utilisateur voit ce qui s'applique.
    var regionCaption: String? {
        guard app.settings.region == .auto else { return nil }
        let effective = app.city.israel
            ? L10n.t("common.israel", lang)
            : L10n.t("common.diaspora", lang)
        return "\(L10n.t("settings.auto", lang)) — \(effective)"
    }
}

// MARK: - Permission de notifications (opt-in, à l'activation)

/// Demande / vérifie l'autorisation `UNUserNotificationCenter` au moment précis
/// où l'utilisateur active un rappel (jamais au lancement — SPEC §9).
///
/// • `.notDetermined` → présente le prompt système une fois.
/// • `.authorized` / `.provisional` / `.ephemeral` → déjà accordée.
/// • `.denied` → refusée (l'app ne peut pas re-prompter ; l'UI oriente vers Réglages iOS).
///
/// 100 % local : aucune dépendance à un serveur push — toutes les échéances Moed
/// sont déterministes et planifiées localement (SPEC §9).
enum NotifPermission {
    static func ensureAuthorized() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}

// MARK: - Segmented control Moed (parchemin, teinté ner)

/// Contrôle segmenté maison, fidèle à la DA (piste `surfaceDeep`, pilule
/// sélectionnée `surface` + texte `ner`, élévation `e1`), plutôt que le
/// `Picker(.segmented)` système (gris UIKit hors-DA). Générique sur une option
/// `Equatable`. Sélection = geste `.selection` (haptique gérée par l'écran hôte
/// via `.haptic(.selection, trigger:)` sur la valeur mutée).
///
/// RTL : `HStack` + propriétés logiques → l'ordre des segments se miroite
/// automatiquement en hébreu. Cibles tactiles ≥ 44 pt.
struct MoedSegmented<Option: Equatable>: View {

    let options: [Option]
    let selected: Option
    let title: (Option) -> String
    var font: ((Option) -> Font)? = nil
    var accessibilityLabel: ((Option) -> String)? = nil
    let onSelect: (Option) -> Void

    @Environment(\.moedLang) private var lang
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: MoedSpace.s4) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                segment(option)
            }
        }
        .padding(MoedSpace.s4)
        .background(
            MoedColor.surfaceDeep,
            in: Capsule(style: .continuous)
        )
        .overlay(
            Capsule(style: .continuous).strokeBorder(MoedColor.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segment(_ option: Option) -> some View {
        let isSelected = option == selected
        Button {
            guard !isSelected else { return }
            let anim: Animation? = reduceMotion ? nil : .snappy(duration: 0.22)
            withAnimation(anim) { onSelect(option) }
        } label: {
            Text(title(option))
                .font(font?(option) ?? MoedFont.caption(lang))
                .foregroundStyle(isSelected ? MoedColor.ner : MoedColor.inkSoft)
                .hebrewBalanced(lang)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 36)
                .padding(.horizontal, MoedSpace.s8)
                .background(pill(isSelected))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)                 // cible tactile globale ≥ 44 pt
        .accessibilityLabel(accessibilityLabel?(option) ?? title(option))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private func pill(_ isSelected: Bool) -> some View {
        if isSelected {
            MoedElevation.e1(
                Capsule(style: .continuous)
                    .fill(MoedColor.surface)
                    .overlay(
                        Capsule(style: .continuous).strokeBorder(MoedColor.lineStrong, lineWidth: 1)
                    )
            )
        } else {
            Color.clear
        }
    }
}

// MARK: - Révélation en cascade (le « moment » d'écran, DESIGN §6)

private struct Reveal: ViewModifier {
    let index: Int
    let reduceMotion: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: (shown || reduceMotion) ? 0 : 8)
            .onAppear {
                guard !shown else { return }              // une seule fois par présentation
                if reduceMotion {
                    // Fondu simple ≤ 150 ms, pas de translation (DESIGN §6 / §10).
                    withAnimation(.easeOut(duration: 0.15)) { shown = true }
                } else {
                    withAnimation(.smooth(duration: 0.5).delay(Double(index) * 0.06)) { shown = true }
                }
            }
    }
}

private extension View {
    /// Apparition opacity 0→1 + translation Y 8→0 en stagger de 60 ms (DESIGN §6).
    /// Reduce Motion → fondu simple sans glissement.
    func reveal(index: Int, reduceMotion: Bool) -> some View {
        modifier(Reveal(index: index, reduceMotion: reduceMotion))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Réglages — FR") {
    SettingsView()
        .environment(AppState())
        .environment(\.moedLang, .fr)
        .environment(\.layoutDirection, .leftToRight)
        .preferredColorScheme(.light)
}

#Preview("Réglages — HE (RTL)") {
    SettingsView()
        .environment(AppState())
        .environment(\.moedLang, .he)
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.light)
}
#endif
