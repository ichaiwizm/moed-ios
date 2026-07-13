//
//  ZmanimCityView.swift
//  Moed — Sous-vue « Zmanim par ville » (SPEC §2, écran secondaire ; DESIGN §5.2/§5.3)
//
//  Page détaillée d'une VILLE (la ville active), poussée depuis « Aujourd'hui »
//  (lien « Tous les zmanim »). Contenu (SPEC §2, écrans secondaires) :
//    1. En-tête : nom de ville + date hébraïque + date grégorienne.
//    2. Allumage du Chabbat (carte héros `ShabbatCard` : allumage + compte à
//       rebours live + havdala) — le seul porteur de flamme pleine de l'écran.
//    3. TOUS les zmanim : `ZmanCatalog.all` (16 clés) → 16 lignes `ZmanRow`
//       (icône · label · shita TOUJOURS affichée · heure tabulaire), sur une
//       carte `cardSolid` OPAQUE (lisibilité halakhique absolue — aucun verre).
//       Le prochain zman à venir est surligné (`nerWash` + `glowNer`, un seul).
//    4. Disclaimer halakhique OBLIGATOIRE + shita active + minutes d'allumage.
//    5. Villes proches : les plus proches par distance (haversine) → tap = ville
//       active (recalcul offline instantané de toute la page).
//
//  Contrat (CONTRACTS §4.2/§4.3) : la vue NE CALCULE PAS d'horaire. Elle consomme
//  `AppState.zmanim(date:)` (catalogue complet) et `AppState.today()` (date
//  hébraïque + prochain Chabbat de la ville active). Le choix du « prochain zman »
//  n'est pas un calcul halakhique : c'est une simple comparaison d'instants déjà
//  calculés par le moteur (comme `AppState.today()` le fait pour le sous-ensemble
//  HOME). Aucun réseau. Light mode forcé à la racine.
//

import Foundation
import SwiftUI

struct ZmanimCityView: View {

    // Store racine (Observation) injecté par RootView.
    @Environment(AppState.self) private var appState
    @Environment(\.moedLang) private var lang

    var body: some View {
        // Une seule passe moteur (offline, synchrone) réutilisée par toute la vue.
        let model = appState.today()             // date hébraïque + prochain Chabbat (ville active)
        let result = appState.zmanim(date: appState.now) // catalogue COMPLET des 16 zmanim
        let city = model.city
        let tz = TimeZone(identifier: city.tz) ?? .current

        ScrollView {
            VStack(alignment: .leading, spacing: MoedSpace.interCard) {
                header(city: city, hebrew: model.hebrew, gregorian: model.gregorian, tz: tz)

                // Allumage du Chabbat (si calculable — non-nil hors latitudes polaires).
                if let shabbat = model.shabbat {
                    ShabbatCard(shabbat: shabbat, now: appState.now, timeZone: tz)
                }

                allZmanimCard(result: result, tz: tz)

                disclaimer(result: result, city: city)

                nearbyCitiesSection(current: city)
            }
            .padding(.horizontal, MoedSpace.pagePadding)
            .padding(.top, MoedSpace.s12)
            .padding(.bottom, MoedSpace.s40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)                   // CanvasBackground global (RootView)
        // Vue POUSSÉE : on conserve la barre de navigation système (bouton retour)
        // et on affiche le nom de ville en titre inline ; l'en-tête custom en-dessous
        // porte la date hébraïque (parité DESIGN §5.1).
        .navigationTitle(city.names(lang))
        .navigationBarTitleDisplayMode(.inline)
        // Retour haptique quand on bascule sur une ville proche (sélection).
        .haptic(.selection, trigger: appState.settings.citySlug)
    }

    // MARK: - 1. En-tête (ville + date hébraïque + grégorienne)

    private func header(city: City, hebrew: HebrewDateResult, gregorian: Date, tz: TimeZone) -> some View {
        VStack(alignment: .leading, spacing: MoedSpace.s4) {
            HStack(spacing: MoedSpace.s4) {
                Image(systemName: "location.fill")       // non directionnelle → jamais miroitée
                    .font(.system(size: 15))
                    .foregroundStyle(MoedColor.ner)
                    .accessibilityHidden(true)
                Text(city.names(lang))
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.inkSoft)
                    .hebrewBalanced(lang)
            }

            Text(hebrewString(hebrew))
                .font(MoedFont.title1(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .accessibilityAddTraits(.isHeader)

            Text(gregorianString(gregorian, tz: tz))
                .font(MoedFont.callout(lang))
                .foregroundStyle(MoedColor.inkMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 3. Carte « Tous les zmanim » (cardSolid opaque, aucune couche de verre)

    /// Carte de CONTENU lisible : surface opaque + bordure `lineStrong` + `e1`,
    /// lignes edge-to-edge séparées par `line` (DESIGN §5.3). Le padding interne
    /// est porté par chaque `ZmanRow` → coins nets, séparateurs pleine largeur.
    private func allZmanimCard(result: ZmanimResult, tz: TimeZone) -> some View {
        // Prochain zman à venir parmi le catalogue complet (surlignage unique).
        let keyRaw = nextUpcomingKey(in: result)

        let list = VStack(alignment: .leading, spacing: 0) {
            Text(L10n.t("home.allZmanim", lang))
                .font(MoedFont.title2(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .padding(.horizontal, MoedSpace.s16)
                .padding(.top, MoedSpace.s16)
                .padding(.bottom, MoedSpace.s8)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(orderedZmanim(result).enumerated()), id: \.element.id) { index, zman in
                if index > 0 { CardDivider() }
                ZmanRow(zman: zman, isKey: zman.key == keyRaw, timeZone: tz)
            }
        }
        .padding(.bottom, MoedSpace.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoedColor.surface, in: MoedRadius.shape(MoedRadius.md))
        .overlay {
            MoedRadius.shape(MoedRadius.md)
                .strokeBorder(MoedColor.lineStrong, lineWidth: 1)
        }

        return MoedElevation.e1(list)
    }

    // MARK: - 4. Disclaimer halakhique (obligatoire) + shita active

    private func disclaimer(result: ZmanimResult, city: City) -> some View {
        // Shita active = celle du tzeit (méthode nuit/havdala), toujours affichée.
        let shita = result.byKey[ZmanKey.tzeitHakochavim.rawValue]?.shita ?? "8.5°"
        let text = L10n.t("zmanim.disclaimer", lang, [
            "shita": shita,
            "min": effectiveCandleMinutes(city: city),
        ])
        return HStack(alignment: .top, spacing: MoedSpace.s8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(MoedColor.inkMute)
                .accessibilityHidden(true)
            Text(text)
                .font(MoedFont.caption(lang))
                .foregroundStyle(MoedColor.inkMute)
                .hebrewBalanced(lang)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MoedSpace.s4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 5. Villes proches (haversine) → bascule de ville active

    private func nearbyCitiesSection(current: City) -> some View {
        let nearby = nearestCities(to: current, limit: 6)
        return VStack(alignment: .leading, spacing: MoedSpace.s8) {
            Text(L10n.t("zmanim.nearby", lang))
                .font(MoedFont.title3(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(nearby.enumerated()), id: \.element.city.id) { index, item in
                    if index > 0 { CardDivider() }
                    nearbyRow(item)
                }
            }
            .background(MoedColor.surface, in: MoedRadius.shape(MoedRadius.md))
            .overlay {
                MoedRadius.shape(MoedRadius.md)
                    .strokeBorder(MoedColor.lineStrong, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nearbyRow(_ item: NearbyCity) -> some View {
        Button {
            selectCity(item.city)
        } label: {
            HStack(spacing: MoedSpace.s12) {
                VStack(alignment: .leading, spacing: MoedSpace.s2) {
                    Text(item.city.names(lang))
                        .font(MoedFont.bodyEmph(lang))
                        .foregroundStyle(MoedColor.ink)
                        .hebrewBalanced(lang)
                    Text(item.city.countryNames(lang))
                        .font(MoedFont.caption(lang))
                        .foregroundStyle(MoedColor.inkMute)
                        .hebrewBalanced(lang)
                }
                Spacer(minLength: MoedSpace.s8)
                // Distance : chiffres LTR (restent lisibles en hébreu).
                ForceLTR {
                    Text(distanceLabel(item.km))
                        .font(MoedFont.caption(lang))
                        .monospacedDigit()
                        .foregroundStyle(MoedColor.inkMute)
                }
                Image(systemName: "chevron.right")           // directionnelle → miroitée en RTL
                    .directionalMirror()
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MoedColor.inkMute)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, MoedSpace.s16)
            .padding(.vertical, MoedSpace.s12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.city.names(lang)), \(distanceLabel(item.km))")
    }

    /// Définit la ville proche comme ville active (persiste + recalcule tout, offline).
    private func selectCity(_ city: City) {
        guard city.slug != appState.settings.citySlug else { return }
        var s = appState.settings
        s.citySlug = city.slug
        appState.update(settings: s)
    }

    // MARK: - Sélection & tri des zmanim (affichage, pas de calcul halakhique)

    /// Catalogue COMPLET dans l'ordre `ZmanCatalog.all` (= ordre du moteur).
    private func orderedZmanim(_ result: ZmanimResult) -> [Zman] {
        ZmanCatalog.all.compactMap { result.byKey[$0.rawValue] }
    }

    /// Clé du prochain zman à venir (> now). Simple comparaison d'instants déjà
    /// calculés — jamais un recalcul. `nil` si tous passés / latitude extrême.
    private func nextUpcomingKey(in result: ZmanimResult) -> String? {
        let now = appState.now
        return orderedZmanim(result)
            .compactMap { z -> (String, Date)? in z.date.map { (z.key, $0) } }
            .filter { $0.1 > now }
            .min { $0.1 < $1.1 }?
            .0
    }

    // MARK: - Villes proches (calcul géométrique local, pas d'horaire)

    private struct NearbyCity { let city: City; let km: Double }

    /// Les `limit` villes les plus proches (hors ville courante), par distance
    /// grand-cercle. Déterministe, offline (dataset embarqué `StaticData.cities`).
    private func nearestCities(to current: City, limit: Int) -> [NearbyCity] {
        StaticData.cities
            .filter { $0.slug != current.slug }
            .map { NearbyCity(city: $0, km: haversineKm(current, $0)) }
            .sorted { $0.km < $1.km }
            .prefix(limit)
            .map { $0 }
    }

    /// Distance grand-cercle en kilomètres (formule de haversine, rayon terrestre 6371 km).
    private func haversineKm(_ a: City, _ b: City) -> Double {
        let r = 6371.0
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLng = (b.lng - a.lng) * .pi / 180
        let lat1 = a.lat * .pi / 180
        let lat2 = b.lat * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

    private func distanceLabel(_ km: Double) -> String {
        let rounded = Int(km.rounded())
        return "\(rounded) km"
    }

    // MARK: - Minutes d'allumage effectives (auto = minhag ville, sinon offset)

    private func effectiveCandleMinutes(city: City) -> Int {
        if case .minutes(let n) = appState.settings.candle { return n }
        return city.candleMinutes
    }

    // MARK: - Formatage date (langue active ; tables maison he/fr/en)

    /// Date hébraïque : he → « ט״ו שבט תשפ״ה » (lettres RTL) ; fr/en → « 15 Shevat 5785 ».
    private func hebrewString(_ h: HebrewDateResult) -> String {
        switch lang {
        case .he:        return "\(h.dayHebrew) \(h.monthName(.he)) \(h.yearHebrew)"
        case .fr, .en:   return "\(h.day) \(h.monthName(lang)) \(h.year)"
        }
    }

    /// Date grégorienne complète localisée, dans le fuseau de la ville, initiale capitalisée.
    private func gregorianString(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.bcp47)
        f.timeZone = tz
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMMyyyy")
        let raw = f.string(from: date)
        return String(raw.prefix(1)).uppercased(with: Locale(identifier: lang.bcp47)) + raw.dropFirst()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Zmanim ville — FR") {
    NavigationStack {
        ZmanimCityView()
            .environment(AppState())
            .environment(\.moedLang, .fr)
            .environment(\.layoutDirection, .leftToRight)
            .preferredColorScheme(.light)
    }
}

#Preview("Zmanim ville — HE (RTL)") {
    NavigationStack {
        ZmanimCityView()
            .environment(AppState())
            .environment(\.moedLang, .he)
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.light)
    }
}
#endif
