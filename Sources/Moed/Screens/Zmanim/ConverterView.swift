//
//  ConverterView.swift
//  Moed — Sous-vue « Convertisseur de dates » (SPEC §2.6 ; DESIGN §5.5)
//
//  Convertit dans les deux sens, 100 % offline & déterministe :
//    • Grégorien → Hébreu : `DatePicker` grégorien → date hébraïque formatée
//      (jour + mois + année) dans la langue active.
//    • Hébreu → Grégorien : sélecteurs jour (1–30) / mois hébreu / année →
//      date grégorienne. La date INVALIDE (ex. 30 d'un mois de 29 jours, ou
//      Adar II hors année embolismique) est détectée et signalée (message
//      `converter.invalid` + haptique `.error`).
//
//  Contrat (CONTRACTS §3.2/§4.3) : la vue NE RÉIMPLÉMENTE PAS le calendrier.
//  Elle consomme exclusivement `HebrewDateEngine` :
//    - `.convert(date, afterSunset:geo:lang:) -> HebrewDateResult`
//    - `.toGregorian(year:month:day:) -> Date?`  (nil ⇔ date hébraïque invalide)
//
//  Correction du calendrier (embolismique / molad / longueurs de mois) : elle
//  vit dans le moteur, source de vérité unique (parité web/Android). La vue s'y
//  appuie de deux façons robustes :
//    1. Les MOIS proposés pour une année sont ceux que le moteur reconnaît :
//       on sonde `toGregorian(year, m, 1)` pour m ∈ 1…13 et on ne garde que les
//       mois non-nil → 12 mois en année ordinaire, 13 (avec Adar I / Adar II) en
//       année embolismique. Le NOM localisé de chaque mois est relu via
//       `convert(...)` (aucune table de mois maison ici → zéro divergence).
//    2. La VALIDITÉ jour/mois/année est celle de `toGregorian` (nil = invalide).
//
//  Aucun réseau. Light mode forcé à la racine. RTL hébreu géré (chiffres LTR).
//

import Foundation
import SwiftUI

struct ConverterView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.moedLang) private var lang

    /// Sens de conversion (segmented). `Hashable` pour servir de `tag` de Picker.
    private enum Direction: Hashable { case gregToHeb, hebToGreg }

    // MARK: - État de saisie

    @State private var direction: Direction = .gregToHeb

    /// Grégorien → Hébreu : date grégorienne choisie.
    @State private var gregDate = Date()

    /// Hébreu → Grégorien : composantes hébraïques (année / mois num. 1…13 / jour 1…30).
    @State private var hebYear = 5785
    @State private var hebMonth = 7          // 7 = Tishrei (Nisan-based), défaut sûr
    @State private var hebDay = 1

    /// Compteur d'impulsions d'erreur : n'augmente QUE sur une nouvelle sélection
    /// hébraïque invalide → l'haptique `.error` ne se déclenche jamais à tort
    /// (ni sur les états valides, ni sur le retour invalide → valide).
    @State private var errorPulse = 0

    /// Marque le premier `onAppear` pour initialiser les composantes hébraïques
    /// sur la date du jour (sans écraser une saisie utilisateur ultérieure).
    @State private var didSeed = false

    // MARK: - Corps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MoedSpace.interCard) {
                titleBlock
                directionPicker

                switch direction {
                case .gregToHeb: gregToHebSection
                case .hebToGreg: hebToGregSection
                }
            }
            .padding(.horizontal, MoedSpace.pagePadding)
            .padding(.top, MoedSpace.s12)
            .padding(.bottom, MoedSpace.s40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)                      // CanvasBackground global (RootView)
        .navigationTitle(L10n.t("converter.title", lang))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: seedTodayIfNeeded)
        // Haptique d'erreur : uniquement quand une saisie hébraïque devient invalide.
        .haptic(.error, trigger: errorPulse)
        // Re-vérifie la validité à chaque changement de sens / composante hébraïque.
        .onChange(of: direction) { _, _ in flagIfInvalid() }
        .onChange(of: hebKey) { _, _ in
            clampMonthToYear()
            flagIfInvalid()
        }
    }

    // MARK: - Titre + sous-titre

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s4) {
            Text(L10n.t("converter.title", lang))
                .font(MoedFont.title1(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .accessibilityAddTraits(.isHeader)
            Text(L10n.t("converter.subtitle", lang))
                .font(MoedFont.callout(lang))
                .foregroundStyle(MoedColor.inkMute)
                .hebrewBalanced(lang)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sens de conversion (segmented, teinté ner)

    private var directionPicker: some View {
        Picker("", selection: $direction) {
            Text(L10n.t("converter.gregToHeb", lang)).tag(Direction.gregToHeb)
            Text(L10n.t("converter.hebToGreg", lang)).tag(Direction.hebToGreg)
        }
        .pickerStyle(.segmented)
        .tint(MoedColor.ner)
        .haptic(.selection, trigger: direction)
        .accessibilityLabel(L10n.t("converter.title", lang))
    }

    // MARK: - Grégorien → Hébreu

    private var gregToHebSection: some View {
        let hebrew = HebrewDateEngine.convert(
            gregDate, afterSunset: false, geo: appState.geo, lang: lang
        )
        return VStack(alignment: .leading, spacing: MoedSpace.interCard) {
            // Champ enfoncé `cardInset` : DatePicker grégorien natif.
            fieldCard(label: L10n.t("converter.gregorianDate", lang)) {
                DatePicker(
                    "",
                    selection: $gregDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(MoedColor.ner)
                .labelsHidden()
                .environment(\.layoutDirection, .leftToRight) // calendrier grégorien lu LTR
            }

            resultCard(
                primary: hebrewString(hebrew),
                secondary: hebrew.weekdayName(lang)
            )
        }
    }

    // MARK: - Hébreu → Grégorien

    private var hebToGregSection: some View {
        let months = hebMonths(for: hebYear)
        let result = HebrewDateEngine.toGregorian(year: hebYear, month: hebMonth, day: hebDay)

        return VStack(alignment: .leading, spacing: MoedSpace.interCard) {
            fieldCard(label: hebInputLabel) {
                HStack(spacing: MoedSpace.s8) {
                    // Jour (1…30) — la validité réelle dépend du mois/année (toGregorian).
                    labeledWheel(title: L10n.t("converter.day", lang)) {
                        Picker("", selection: $hebDay) {
                            ForEach(1...30, id: \.self) { d in
                                Text(numeral(d)).tag(d)
                            }
                        }
                    }
                    // Mois hébreu : uniquement ceux reconnus par le moteur pour l'année.
                    labeledWheel(title: L10n.t("converter.month", lang)) {
                        Picker("", selection: $hebMonth) {
                            ForEach(months, id: \.number) { m in
                                Text(m.name).tag(m.number)
                            }
                        }
                    }
                    // Année hébraïque (numérique — lisible et non ambigu dans les 3 langues).
                    labeledWheel(title: L10n.t("converter.year", lang)) {
                        Picker("", selection: $hebYear) {
                            ForEach(yearRange, id: \.self) { y in
                                Text(numeral(y)).tag(y)
                            }
                        }
                    }
                }
            }

            if let g = result {
                resultCard(
                    primary: gregorianString(g),
                    secondary: weekdayString(g)
                )
            } else {
                invalidCard
            }
        }
    }

    /// Libellé accessible du bloc de saisie hébraïque (jour/mois/année).
    private var hebInputLabel: String {
        "\(L10n.t("converter.day", lang)) · \(L10n.t("converter.month", lang)) · \(L10n.t("converter.year", lang))"
    }

    // MARK: - Cartes réutilisables

    /// Carte de saisie : titre `micro` + contenu sur fond `surfaceDeep` (`cardInset`).
    private func fieldCard<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: MoedSpace.s8) {
            Text(label)
                .font(MoedFont.micro(lang))
                .textCase(.uppercase)
                .tracking(0.9)
                .foregroundStyle(MoedColor.inkMute)
            content()
                .frame(maxWidth: .infinity)
        }
        .padding(MoedSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoedColor.surfaceDeep, in: MoedRadius.shape(MoedRadius.md))
        .overlay {
            MoedRadius.shape(MoedRadius.md)
                .strokeBorder(MoedColor.lineStrong, lineWidth: 1)
        }
    }

    /// Carte de résultat lisible (`cardSolid`) : grande valeur + ligne secondaire.
    private func resultCard(primary: String, secondary: String) -> some View {
        let card = VStack(alignment: .leading, spacing: MoedSpace.s4) {
            Text(L10n.t("converter.result", lang))
                .font(MoedFont.micro(lang))
                .textCase(.uppercase)
                .tracking(0.9)
                .foregroundStyle(MoedColor.inkMute)
            Text(primary)
                .font(MoedFont.title1(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .fixedSize(horizontal: false, vertical: true)
            Text(secondary)
                .font(MoedFont.callout(lang))
                .foregroundStyle(MoedColor.inkSoft)
                .hebrewBalanced(lang)
        }
        .padding(MoedSpace.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoedColor.surface, in: MoedRadius.shape(MoedRadius.md))
        .overlay {
            MoedRadius.shape(MoedRadius.md)
                .strokeBorder(MoedColor.lineStrong, lineWidth: 1)
        }

        return MoedElevation.e1(card)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(L10n.t("converter.result", lang)): \(primary), \(secondary)")
    }

    /// Carte d'erreur (date hébraïque invalide) — ton `rose` (alerte douce, DESIGN §5.6).
    private var invalidCard: some View {
        HStack(spacing: MoedSpace.s8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundStyle(MoedColor.rose)
                .accessibilityHidden(true)
            Text(L10n.t("converter.invalid", lang))
                .font(MoedFont.bodyEmph(lang))
                .foregroundStyle(MoedColor.rose)
                .hebrewBalanced(lang)
        }
        .padding(MoedSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoedColor.rose.opacity(0.12), in: MoedRadius.shape(MoedRadius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t("converter.invalid", lang))
    }

    /// Colonne « titre + roue » pour un sélecteur hébraïque.
    private func labeledWheel<P: View>(
        title: String,
        @ViewBuilder picker: () -> P
    ) -> some View {
        VStack(spacing: MoedSpace.s4) {
            Text(title)
                .font(MoedFont.caption(lang))
                .foregroundStyle(MoedColor.inkMute)
                .hebrewBalanced(lang)
            picker()
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 120)
                .clipped()
                .tint(MoedColor.ink)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mois hébreux reconnus par le moteur (sondés, nommés via convert)

    private struct HebMonth { let number: Int; let name: String }

    /// Mois valides de l'année `year`, dans l'ordre du moteur (1 = Nisan … 13 = Adar II).
    /// Un mois est retenu ssi `toGregorian(year, m, 1)` est non-nil ; son nom localisé
    /// est relu via `convert(...)` (aucune table de mois maison → parité stricte).
    private func hebMonths(for year: Int) -> [HebMonth] {
        (1...13).compactMap { m -> HebMonth? in
            guard let d = HebrewDateEngine.toGregorian(year: year, month: m, day: 1) else { return nil }
            let hr = HebrewDateEngine.convert(d, afterSunset: false, geo: appState.geo, lang: lang)
            return HebMonth(number: m, name: hr.monthName(lang))
        }
    }

    /// Numéros de mois valides de l'année (pour le bornage de la sélection).
    private func validMonthNumbers(for year: Int) -> [Int] {
        (1...13).filter { HebrewDateEngine.toGregorian(year: year, month: $0, day: 1) != nil }
    }

    /// Si l'année passe embolismique → ordinaire (ou l'inverse), un mois sélectionné
    /// peut devenir inexistant (ex. Adar II en année ordinaire) : on le ramène au
    /// dernier mois valide, jamais d'état incohérent.
    private func clampMonthToYear() {
        let valid = validMonthNumbers(for: hebYear)
        if !valid.contains(hebMonth) {
            hebMonth = valid.last ?? hebMonth
        }
    }

    // MARK: - Validité & haptique d'erreur

    /// Clé de sélection hébraïque (déclenche les re-vérifications sur changement).
    private var hebKey: String { "\(hebYear)-\(hebMonth)-\(hebDay)" }

    /// Signale une NOUVELLE saisie hébraïque invalide (incrémente `errorPulse`,
    /// ce qui fait vibrer `.error`). Ne fait rien en sens grég→héb ni si valide.
    private func flagIfInvalid() {
        guard direction == .hebToGreg else { return }
        if HebrewDateEngine.toGregorian(year: hebYear, month: hebMonth, day: hebDay) == nil {
            errorPulse += 1
        }
    }

    // MARK: - Amorçage sur la date du jour

    private func seedTodayIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        let today = HebrewDateEngine.convert(
            appState.now, afterSunset: false, geo: appState.geo, lang: lang
        )
        hebYear = today.year
        hebMonth = today.month
        hebDay = today.day
        gregDate = appState.now
    }

    // MARK: - Plage d'années (autour de l'année courante)

    private var yearRange: [Int] {
        let base = HebrewDateEngine.convert(
            appState.now, afterSunset: false, geo: appState.geo, lang: lang
        ).year
        return Array((base - 120)...(base + 120))
    }

    // MARK: - Numérotation (chiffres occidentaux, stables & non ambigus)

    /// Chiffres occidentaux, sans séparateur de milliers (années hébraïques : « 5785 »).
    private func numeral(_ n: Int) -> String { String(n) }

    // MARK: - Formatage des résultats

    /// Date hébraïque : he → « ט״ו שבט תשפ״ה » ; fr/en → « 15 Shevat 5785 ».
    private func hebrewString(_ h: HebrewDateResult) -> String {
        switch lang {
        case .he:        return "\(h.dayHebrew) \(h.monthName(.he)) \(h.yearHebrew)"
        case .fr, .en:   return "\(h.day) \(h.monthName(lang)) \(h.year)"
        }
    }

    /// Date grégorienne complète localisée (sans heure), initiale capitalisée.
    private func gregorianString(_ date: Date) -> String {
        let loc = Locale(identifier: lang.bcp47)
        let f = DateFormatter()
        f.locale = loc
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        let raw = f.string(from: date)
        return String(raw.prefix(1)).uppercased(with: loc) + raw.dropFirst()
    }

    /// Jour de la semaine grégorien, localisé (ligne secondaire du résultat).
    private func weekdayString(_ date: Date) -> String {
        let loc = Locale(identifier: lang.bcp47)
        let f = DateFormatter()
        f.locale = loc
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate("EEEE")
        let raw = f.string(from: date)
        return String(raw.prefix(1)).uppercased(with: loc) + raw.dropFirst()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Convertisseur — FR") {
    NavigationStack {
        ConverterView()
            .environment(AppState())
            .environment(\.moedLang, .fr)
            .environment(\.layoutDirection, .leftToRight)
            .preferredColorScheme(.light)
    }
}

#Preview("Convertisseur — HE (RTL)") {
    NavigationStack {
        ConverterView()
            .environment(AppState())
            .environment(\.moedLang, .he)
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.light)
    }
}
#endif
