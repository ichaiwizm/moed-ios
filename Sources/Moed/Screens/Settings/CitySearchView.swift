//
//  CitySearchView.swift
//  Moed — Screens / Settings (sélecteur de ville)
//
//  SPEC §2.5 · CONTRACTS §4.1 / §4.3. Feuille (`.sheet`) de recherche de ville,
//  présentée depuis Réglages (et l'en-tête « Aujourd'hui »). Elle FILTRE les
//  191 villes du dataset statique embarqué (`StaticData.cities`) et propose
//  « autour de moi » via `LocationProvider` (CoreLocation opt-in) qui renvoie la
//  ville la plus proche — matching 100 % offline (distance orthodromique locale,
//  aucun géocodage réseau).
//
//  Elle NE recalcule aucune donnée halakhique : elle sélectionne une `City` et la
//  remonte à l'appelant via `onSelect`, qui persiste le nouveau `citySlug` par
//  `AppState.update(settings:)` (recalcul dérivés + reschedule notifs). Zéro réseau.
//
//  DA : contenu de lecture sur cartes OPAQUES (`cardSolid`) ; le champ de recherche
//  est un `cardInset` (`surfaceDeep`). RTL première classe : propriétés logiques,
//  loupe non miroitée, chevrons directionnels miroités. Cibles tactiles ≥ 44 pt.
//
//  Le filtrage est insensible à la casse ET aux diacritiques (folding), et porte
//  sur les noms trilingues (he/fr/en), le pays et le slug — l'utilisateur trouve
//  « Jérusalem », « Jerusalem » ou « ירושלים » indifféremment.
//

import SwiftUI

struct CitySearchView: View {

    /// Slug de la ville actuellement active (coche de confirmation dans la liste).
    let currentSlug: String
    /// Callback de sélection : l'appelant persiste la ville (via AppState).
    let onSelect: (City) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.moedLang) private var lang

    /// Texte de recherche (filtre live sur les 191 villes).
    @State private var query = ""
    /// Géolocalisation « autour de moi » en cours (spinner + désactivation).
    @State private var locating = false
    /// Déclencheur d'haptique de sélection (change à chaque choix confirmé).
    @State private var pickTick = 0

    /// Provider CoreLocation opt-in (l'autorisation est demandée à la volée, au tap).
    /// Référence conservée le temps de la présentation (le delegate doit survivre).
    @State private var locator = LocationProvider()

    // MARK: - Corps

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, MoedSpace.pagePadding)
                    .padding(.top, MoedSpace.s12)
                    .padding(.bottom, MoedSpace.s8)

                cityList
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MoedColor.canvas.ignoresSafeArea())      // fond parchemin de la sheet
            .navigationTitle(L10n.t("common.city", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel", lang)) { dismiss() }
                        .foregroundStyle(MoedColor.inkSoft)
                }
            }
            .haptic(.selection, trigger: pickTick)
        }
        // Feuille de formulaire : détents medium + large (CONTRACTS §4.1).
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Champ de recherche (cardInset)

    private var searchField: some View {
        HStack(spacing: MoedSpace.s8) {
            // Loupe : icône NON directionnelle → jamais miroitée en RTL (DESIGN §8).
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoedColor.inkMute)

            TextField(L10n.t("common.searchCity", lang), text: $query)
                .font(MoedFont.body(lang))
                .foregroundStyle(MoedColor.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MoedColor.inkMute)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("common.cancel", lang))
            }
        }
        .padding(.horizontal, MoedSpace.s12)
        .frame(minHeight: 48)
        .background(
            MoedColor.surfaceDeep,
            in: RoundedRectangle(cornerRadius: MoedRadius.sm, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MoedRadius.sm, style: .continuous)
                .strokeBorder(MoedColor.line, lineWidth: 1)
        )
    }

    // MARK: - Liste (autour de moi + villes filtrées)

    private var cityList: some View {
        List {
            // « Autour de moi » : masqué pendant une recherche active (on filtre
            // alors explicitement par nom).
            if query.isEmpty {
                aroundMeRow
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(filtered) { city in
                cityRow(city)
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if filtered.isEmpty {
                emptyRow
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .environment(\.defaultMinListRowHeight, 44)
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: MoedSpace.s4, leading: MoedSpace.pagePadding,
                   bottom: MoedSpace.s4, trailing: MoedSpace.pagePadding)
    }

    // MARK: - Ligne « Autour de moi » (LocationProvider, opt-in)

    private var aroundMeRow: some View {
        Button(action: locateNearest) {
            HStack(spacing: MoedSpace.s12) {
                // Icône NON directionnelle (localisation) → jamais miroitée.
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MoedColor.ner)
                    .frame(width: 24)

                Text(L10n.t("common.aroundMe", lang))
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if locating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(MoedColor.ner)
                }
            }
            .padding(.horizontal, MoedSpace.cardPaddingCompact)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .contentShape(RoundedRectangle(cornerRadius: MoedRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(locating)
        .accessibilityLabel(L10n.t("common.aroundMe", lang))
    }

    // MARK: - Ligne ville

    private func cityRow(_ city: City) -> some View {
        let isCurrent = city.slug == currentSlug
        return Button {
            pick(city)
        } label: {
            HStack(spacing: MoedSpace.s12) {
                VStack(alignment: .leading, spacing: MoedSpace.s2) {
                    Text(city.names(lang))
                        .font(MoedFont.bodyEmph(lang))
                        .foregroundStyle(MoedColor.ink)
                        .hebrewBalanced(lang)
                        .lineLimit(1)
                    Text(city.countryNames(lang))
                        .font(MoedFont.caption(lang))
                        .foregroundStyle(MoedColor.inkMute)
                        .hebrewBalanced(lang)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isCurrent {
                    // Coche NON directionnelle → jamais miroitée.
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MoedColor.ner)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, MoedSpace.cardPaddingCompact)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .contentShape(RoundedRectangle(cornerRadius: MoedRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(city.names(lang)), \(city.countryNames(lang))")
        .accessibilityAddTraits(isCurrent ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - État vide (aucune ville ne correspond)

    private var emptyRow: some View {
        Text(L10n.t("common.empty", lang))
            .font(MoedFont.callout(lang))
            .foregroundStyle(MoedColor.inkMute)
            .hebrewBalanced(lang)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, MoedSpace.s32)
    }

    /// Fond de carte opaque commun (cardSolid : surface + bordure lineStrong).
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: MoedRadius.md, style: .continuous)
            .fill(MoedColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: MoedRadius.md, style: .continuous)
                    .strokeBorder(MoedColor.lineStrong, lineWidth: 1)
            )
    }

    // MARK: - Filtrage (offline, 191 villes)

    /// Villes filtrées par la requête. Vide → toutes les villes (ordre du dataset).
    /// Comparaison insensible casse + diacritiques sur noms trilingues / pays / slug.
    private var filtered: [City] {
        let q = Self.fold(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return StaticData.cities }
        return StaticData.cities.filter { city in
            Self.fold(city.names.he).contains(q)
                || Self.fold(city.names.fr).contains(q)
                || Self.fold(city.names.en).contains(q)
                || Self.fold(city.countryNames.fr).contains(q)
                || Self.fold(city.countryNames.en).contains(q)
                || Self.fold(city.countryNames.he).contains(q)
                || city.slug.contains(q)
        }
    }

    /// Normalisation de recherche : minuscules + suppression des diacritiques
    /// (« é » ≈ « e »). L'hébreu (sans casse/diacritiques usuels) passe intact.
    private static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
    }

    // MARK: - Actions

    /// Sélection d'une ville : haptique `.selection`, remontée à l'appelant, fermeture.
    private func pick(_ city: City) {
        pickTick &+= 1
        onSelect(city)
        dismiss()
    }

    /// « Autour de moi » : demande la position (autorisation à la volée) et
    /// sélectionne la ville la plus proche du dataset. En cas de refus / échec,
    /// on arrête simplement le spinner (aucune ville imposée).
    private func locateNearest() {
        guard !locating else { return }
        locating = true
        locator.requestNearestCity { city in
            locating = false
            if let city { pick(city) }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Recherche ville — FR") {
    Color.clear.sheet(isPresented: .constant(true)) {
        CitySearchView(currentSlug: "paris") { _ in }
            .environment(\.moedLang, .fr)
            .environment(\.layoutDirection, .leftToRight)
            .preferredColorScheme(.light)
    }
}

#Preview("Recherche ville — HE (RTL)") {
    Color.clear.sheet(isPresented: .constant(true)) {
        CitySearchView(currentSlug: "jerusalem") { _ in }
            .environment(\.moedLang, .he)
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.light)
    }
}
#endif
