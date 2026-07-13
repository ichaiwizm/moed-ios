//
//  PersonalView.swift
//  Moed — Screens / Personal (carnet familial)
//
//  SPEC §2.3 · DESIGN §5.4-5.5. Écran « Personnel » : liste locale de proches
//  (anniversaires hébraïques + yahrzeits), chacun avec sa prochaine occurrence
//  grégorienne + hébraïque et un badge « dans X jours ». Suppression par swipe
//  (rose + haptique), bloc opt-in rappels, état vide illustré, bouton flottant
//  d'ajout (Liquid Glass) → `AddPersonSheet`.
//
//  Cet écran CONSOMME uniquement l'API contractuelle d'`AppState`
//  (CONTRACTS §4.2) : `family`, `now`, `city`, `lang`, `occurrences(_:)`,
//  `removePerson(id:)`, `update(settings:)`. Il ne rappelle jamais le moteur
//  directement — tout est offline, déterministe, synchrone.
//
//  Dépendances DesignSystem : MoedColor / MoedFont / MoedSpace / MoedRadius /
//  MoedElevation / Haptic / ForceLTR (via MoedFmt) + i18n L10n. Le calcul des
//  occurrences (règles Cheshvan-30 / Kislev-30 / Adar, années embolismiques,
//  ancrage `afterSunset`) est porté par `PersonalEngine` derrière `AppState`.
//
//  RTL première classe : propriétés logiques uniquement (leading/trailing) ; le
//  bouton flottant s'ancre bottom-trailing → miroité automatiquement en hébreu.
//  Les dates grégoriennes / hébraïques sont formatées dans le fuseau IANA de la
//  ville active (jamais l'offset device).
//

import SwiftUI
import UserNotifications

// MARK: - Présentation d'un PersonType (pastille, icônes NON directionnelles)

extension PersonType {
    /// SF Symbol de la pastille de type. **Non directionnel** → jamais miroité en RTL
    /// (DESIGN §8 : bougie/cadeau ne se retournent pas).
    var pastilleSymbol: String {
        switch self {
        case .birthday: return "gift.fill"
        case .yahrzeit: return "flame.fill"
        }
    }

    /// Fond de la pastille (DESIGN §5.4 : anniversaire = nerWash, yahrzeit = twilightWash).
    var pastilleFill: Color {
        switch self {
        case .birthday: return MoedColor.nerWash
        case .yahrzeit: return MoedColor.twilightWash
        }
    }

    /// Teinte du glyphe de la pastille.
    var pastilleForeground: Color {
        switch self {
        case .birthday: return MoedColor.ner
        case .yahrzeit: return MoedColor.twilight
        }
    }

    /// Clé i18n du libellé court du type (segmented / accessibilité).
    var l10nLabelKey: String {
        switch self {
        case .birthday: return "personal.addBirthday"
        case .yahrzeit: return "personal.addYahrzeit"
        }
    }
}

// MARK: - Formatage personnel (déterministe, langue + fuseau ville)

/// Utilitaires d'affichage propres au carnet familial. Sans état, purement
/// lexicaux : ils n'effectuent AUCUN calcul de date hébraïque (celui-ci vient du
/// moteur via `AppState.occurrences`).
enum PersonalFmt {

    /// Date hébraïque lisible dans la langue active. En hébreu : lettres
    /// (jour + mois + année) ; en fr/en : chiffres + nom de mois translittéré.
    /// Les noms de mois viennent des tables maison (jamais du rendu `fr` d'une lib).
    static func hebrew(_ h: HebrewDateResult, lang: Lang) -> String {
        switch lang {
        case .he:
            return "\(h.dayHebrew) \(h.monthName(lang)) \(h.yearHebrew)"
        case .fr, .en:
            return "\(h.day) \(h.monthName(lang)) \(h.year)"
        }
    }

    /// Libellé relatif « dans X jours » (aujourd'hui / demain gérés), langue active.
    /// Déterministe et localisé sans dépendre d'une clé i18n paramétrée absente.
    static func relativeDays(_ n: Int, lang: Lang) -> String {
        let days = max(0, n)
        switch lang {
        case .he:
            if days == 0 { return "היום" }
            if days == 1 { return "מחר" }
            return "בעוד \(days) ימים"
        case .fr:
            if days == 0 { return "aujourd’hui" }
            if days == 1 { return "demain" }
            return "dans \(days) jours"
        case .en:
            if days == 0 { return "today" }
            if days == 1 { return "tomorrow" }
            return "in \(days) days"
        }
    }
}

// MARK: - PersonalView

/// Écran « Personnel » — carnet familial local (SPEC §2.3).
struct PersonalView: View {

    @Environment(AppState.self) private var app
    @Environment(\.moedLang) private var lang
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Présentation de la feuille d'ajout (`AddPersonSheet`).
    @State private var showAddSheet = false
    /// Déclencheur d'haptique de suppression (change à chaque swipe confirmé).
    @State private var removeTick = 0

    /// Fuseau IANA de la ville active — pilote l'affichage des dates (DST inclus).
    private var cityZone: TimeZone {
        TimeZone(identifier: app.city.tz) ?? .current
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Fond transparent : laisse transparaître le CanvasBackground global.
                Color.clear

                content

                // Bouton flottant d'ajout (Liquid Glass) — ancre logique bottom-trailing
                // (→ bottom-leading en RTL, géré par SwiftUI). Icône plus non directionnelle.
                PersonalFloatingAddButton {
                    showAddSheet = true
                }
                .padding(.trailing, MoedSpace.pagePadding)
                .padding(.bottom, MoedSpace.s24)
                .accessibilityLabel(Text(L10n.t("common.add", lang)))
            }
            .toolbar(.hidden, for: .navigationBar)
            // Haptique de suppression sémantique (jamais sur scroll/tick — DESIGN §7).
            .haptic(.remove, trigger: removeTick)
            .sheet(isPresented: $showAddSheet) {
                AddPersonSheet()
            }
        }
    }

    // MARK: Contenu (liste peuplée ou état vide)

    @ViewBuilder
    private var content: some View {
        if app.family.isEmpty {
            emptyState
        } else {
            populatedList
        }
    }

    // MARK: En-tête (titre + sous-titre, respire sur le canvas)

    private var header: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s4) {
            Text(L10n.t("personal.title", lang))
                .font(MoedFont.title1(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
            Text(L10n.t("personal.subtitle", lang))
                .font(MoedFont.callout(lang))
                .foregroundStyle(MoedColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Liste peuplée

    private var populatedList: some View {
        List {
            // En-tête + bloc rappels : lignes « transparentes » sans style de liste.
            Section {
                header
                    .listRowInsets(EdgeInsets(
                        top: MoedSpace.s8, leading: MoedSpace.pagePadding,
                        bottom: MoedSpace.s8, trailing: MoedSpace.pagePadding))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                RemindersOptInCard()
                    .listRowInsets(EdgeInsets(
                        top: MoedSpace.s4, leading: MoedSpace.pagePadding,
                        bottom: MoedSpace.s8, trailing: MoedSpace.pagePadding))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Cartes des proches (cardSolid), suppression par swipe trailing (rose).
            Section {
                ForEach(app.family) { person in
                    PersonalPersonRow(
                        person: person,
                        occurrence: app.occurrences(person).first,
                        now: app.now,
                        zone: cityZone
                    )
                    .listRowInsets(EdgeInsets(
                        top: MoedSpace.s4, leading: MoedSpace.pagePadding,
                        bottom: MoedSpace.s4, trailing: MoedSpace.pagePadding))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(person)
                        } label: {
                            Label(L10n.t("common.delete", lang), systemImage: "trash")
                        }
                        .tint(MoedColor.rose)
                    }
                }
            }

            // Respiration sous la liste pour ne pas coller au bouton flottant.
            Color.clear
                .frame(height: MoedSpace.s72)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: État vide illustré (DESIGN §5.4)

    private var emptyState: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, MoedSpace.pagePadding)
                .padding(.top, MoedSpace.s8)

            Spacer(minLength: MoedSpace.s24)

            VStack(spacing: MoedSpace.s16) {
                EmptyFamilyIllustration()
                    .frame(width: 132, height: 132)
                    .accessibilityHidden(true)

                VStack(spacing: MoedSpace.s8) {
                    Text(L10n.t("personal.emptyTitle", lang))
                        .font(MoedFont.title3(lang))
                        .foregroundStyle(MoedColor.ink)
                        .hebrewBalanced(lang)
                        .multilineTextAlignment(.center)
                    Text(L10n.t("personal.emptyBody", lang))
                        .font(MoedFont.callout(lang))
                        .foregroundStyle(MoedColor.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 320)

                Button {
                    showAddSheet = true
                } label: {
                    Label(L10n.t("common.add", lang), systemImage: "plus")
                        .font(MoedFont.bodyEmph(lang))
                        .foregroundStyle(MoedColor.surface)
                        .padding(.horizontal, MoedSpace.s20)
                        .padding(.vertical, MoedSpace.s12)
                        .background(Capsule().fill(MoedColor.ner))
                }
                .buttonStyle(.plain)
                .padding(.top, MoedSpace.s4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(L10n.t("common.add", lang)))
            }
            .padding(.horizontal, MoedSpace.pagePadding)
            .accessibilityElement(children: .contain)

            Spacer(minLength: MoedSpace.s56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Mutations

    private func delete(_ person: PersonRecord) {
        // Confirmation haptique de suppression (DESIGN §7 : .impact rigide léger).
        removeTick &+= 1
        let animation: Animation = reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.35)
        withAnimation(animation) {
            app.removePerson(id: person.id)
        }
    }
}

// MARK: - Ligne d'un proche (cardSolid, contenu de lecture — pas de verre)

/// Carte lisible d'un proche : pastille de type · nom · prochaine occurrence
/// (grég + héb) · badge « dans X jours ». Contenu de LECTURE → surface opaque
/// `cardSolid`, jamais de verre (DESIGN §5.4). Stateless : tout dérive des entrées.
private struct PersonalPersonRow: View {

    let person: PersonRecord
    /// Prochaine occurrence (déjà calculée par le moteur via `AppState`), ou `nil`
    /// si la date d'origine est invalide (jamais un crash, jamais « NaN »).
    let occurrence: Occurrence?
    /// Instant courant (tick d'`AppState`) pour « dans X jours ».
    let now: Date
    /// Fuseau IANA de la ville active.
    let zone: TimeZone

    @Environment(\.moedLang) private var lang

    private var daysUntil: Int? {
        guard let occ = occurrence else { return nil }
        return MoedFmt.days(from: now, to: occ.gregorian, tz: zone)
    }

    var body: some View {
        HStack(spacing: MoedSpace.s12) {
            pastille

            VStack(alignment: .leading, spacing: MoedSpace.s2) {
                Text(person.name)
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.ink)
                    .lineLimit(1)
                    .hebrewBalanced(lang)

                subtitle
            }

            Spacer(minLength: MoedSpace.s8)

            if let days = daysUntil {
                daysBadge(days)
            }
        }
        .padding(.horizontal, MoedSpace.cardPaddingCompact)
        .padding(.vertical, MoedSpace.s12)
        .frame(minHeight: 44) // cible tactile ≥ 44 pt (DESIGN §10)
        .background {
            MoedRadius.shape(MoedRadius.md).fill(MoedColor.surface)
        }
        .overlay {
            MoedRadius.shape(MoedRadius.md).strokeBorder(MoedColor.lineStrong, lineWidth: 1)
        }
        .moedElevation(.e1)
        .contentShape(MoedRadius.shape(MoedRadius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel)
    }

    // Pastille de type (cercle teinté + glyphe non directionnel).
    private var pastille: some View {
        ZStack {
            Circle().fill(person.type.pastilleFill)
            Image(systemName: person.type.pastilleSymbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(person.type.pastilleForeground)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }

    // Sous-titre : « prochaine occurrence · 14 juil. 2026 · ט״ו בתשרי תשפ״ה ».
    @ViewBuilder
    private var subtitle: some View {
        if let occ = occurrence {
            (
                Text(L10n.t("personal.nextOccurrence", lang) + " · ")
                    + Text(MoedFmt.gregorian(occ.gregorian, lang: lang, tz: zone))
                    + Text(" · " + PersonalFmt.hebrew(occ.hebrew, lang: lang))
            )
            .font(MoedFont.caption(lang))
            .foregroundStyle(MoedColor.inkSoft)
            .lineLimit(2)
        } else {
            Text(L10n.t("common.empty", lang))
                .font(MoedFont.caption(lang))
                .foregroundStyle(MoedColor.inkMute)
        }
    }

    // Badge « dans X jours » — capsule surfaceDeep (DESIGN §5.4 / §5.6 neutre).
    private func daysBadge(_ days: Int) -> some View {
        Text(PersonalFmt.relativeDays(days, lang: lang))
            .font(MoedFont.caption(lang))
            .foregroundStyle(MoedColor.inkSoft)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, MoedSpace.s12)
            .padding(.vertical, MoedSpace.s4 + 2)
            .background(Capsule().fill(MoedColor.surfaceDeep))
            .accessibilityHidden(true)
    }

    private var voiceOverLabel: String {
        var parts = [person.name, L10n.t(person.type.l10nLabelKey, lang)]
        if let occ = occurrence {
            parts.append(L10n.t("personal.nextOccurrence", lang))
            parts.append(MoedFmt.gregorian(occ.gregorian, lang: lang, tz: zone))
            parts.append(PersonalFmt.hebrew(occ.hebrew, lang: lang))
            if let days = daysUntil {
                parts.append(PersonalFmt.relativeDays(days, lang: lang))
            }
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Bloc opt-in rappels (SPEC §2.3)

/// Carte « Activer les rappels » — opt-in des notifications locales du carnet
/// familial (yahrzeits / anniversaires). Bascule la préférence via l'API
/// contractuelle `AppState.update(settings:)` (qui persiste + replanifie la
/// fenêtre glissante de notifications, CONTRACTS §4.2) et demande la permission
/// système au moment de l'activation (jamais avant — opt-in, DESIGN/SPEC §1.5).
private struct RemindersOptInCard: View {

    @Environment(AppState.self) private var app
    @Environment(\.moedLang) private var lang

    /// Reflète la préférence yahrzeit (rappels du carnet). Le toggle en est le miroir.
    private var isOn: Binding<Bool> {
        Binding(
            get: { app.settings.notif.yahrzeit },
            set: { newValue in
                var s = app.settings
                s.notif.yahrzeit = newValue
                app.update(settings: s)
                if newValue {
                    requestAuthorization()
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: MoedSpace.s12) {
            ZStack {
                Circle().fill(MoedColor.nerWash)
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MoedColor.ner)
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MoedSpace.s2) {
                Text(L10n.t("personal.enableReminders", lang))
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
                Text(L10n.t("personal.kaddish", lang))
                    .font(MoedFont.caption(lang))
                    .foregroundStyle(MoedColor.inkMute)
                    .lineLimit(2)
            }

            Spacer(minLength: MoedSpace.s8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(MoedColor.ner)
        }
        .padding(.horizontal, MoedSpace.cardPaddingCompact)
        .padding(.vertical, MoedSpace.s12)
        .background {
            MoedRadius.shape(MoedRadius.md).fill(MoedColor.surface)
        }
        .overlay {
            MoedRadius.shape(MoedRadius.md).strokeBorder(MoedColor.lineStrong, lineWidth: 1)
        }
        .moedElevation(.e1)
        // Haptique légère à l'activation (DESIGN §7 : toggle notification activé).
        .haptic(.toggleOn, trigger: app.settings.notif.yahrzeit)
        .accessibilityElement(children: .combine)
    }

    /// Demande la permission de notifications locales (best-effort, offline).
    private func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

// MARK: - Bouton flottant d'ajout (Liquid Glass + fallback iOS 17-25)

/// FAB « Ajouter » (DESIGN §5.4) : verre flottant teinté flamme, halo `glowNer`,
/// ancré bottom-trailing (logique → miroité en RTL). Le verre est le SEUL usage
/// de chrome flottant ici (jamais sous du contenu de lecture — DESIGN §1).
private struct PersonalFloatingAddButton: View {

    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let diameter: CGFloat = 60

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus") // non directionnel → jamais miroité
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MoedColor.nerStrong)
                .frame(width: diameter, height: diameter)
                .background(glassBackground)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(MoedColor.nerGlow.opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        // Halo flamme (glowNer) — accent sacré, un seul élément fort ici (DESIGN §4.3).
        .modifier(GlowNer())
        .contentShape(Circle())
        .accessibilityAddTraits(.isButton)
    }

    /// Fond du bouton : Liquid Glass sous iOS 26, sinon material + surface opaque
    /// si Reduce Transparency (DESIGN §10 / CONTRACTS §2.4).
    @ViewBuilder
    private var glassBackground: some View {
        if reduceTransparency {
            Circle().fill(MoedColor.surface)
        } else if #available(iOS 26.0, *) {
            // Liquid Glass natif, teinté flamme (DESIGN §4.2 : glassFloat).
            Circle()
                .fill(.clear)
                .glassEffect(.regular.tint(MoedColor.ner.opacity(0.14)), in: Circle())
        } else {
            // Repli iOS 17-25 : material régulier + voile flamme léger.
            Circle()
                .fill(.regularMaterial)
                .overlay { Circle().fill(MoedColor.nerWash.opacity(0.5)) }
        }
    }

    /// Wrapper d'ombre (le générique `MoedElevation.glowNer` s'applique via modifier).
    private struct GlowNer: ViewModifier {
        func body(content: Content) -> some View {
            MoedElevation.e2(MoedElevation.glowNer(content))
        }
    }
}

// MARK: - Illustration d'état vide (motif symbolique, sans asset externe)

/// Illustration légère du carnet vide : deux silhouettes sur un disque parchemin
/// halo flamme. Composée de SF Symbols (aucun asset bundlé requis → jamais
/// d'écran nu) — fidèle à la DA (parchemin + flamme rare).
private struct EmptyFamilyIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(MoedColor.surfaceDeep)
            Circle()
                .fill(MoedColor.nerWash.opacity(0.6))
                .padding(18)
            Image(systemName: "person.2.fill")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(MoedColor.ner)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "flame.fill") // non directionnel
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(MoedColor.nerGlow)
                .padding(6)
                .background(Circle().fill(MoedColor.surface))
                .moedElevation(.e1)
                .offset(x: 4, y: -2)
        }
    }
}

#if DEBUG
#Preview("Personnel — peuplé") {
    PersonalView()
        .environment(AppState())
        .environment(\.moedLang, .fr)
        .preferredColorScheme(.light)
}
#endif
