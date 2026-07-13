//
//  StaticData.swift
//  Moed — Data module
//
//  Chargement PARESSEUX + CACHE des datasets embarqués (CONTRACTS.md §3.3).
//  Zéro réseau : tout est bundlé (`Data/Resources/{cities,tsadikim}.json`).
//
//  • 189 villes — format riche trilingue conservé (`names`, `countryNames`,
//    `candleMinutes`, `israel`, `tz` IANA, `elevation`).
//  • 30 fiches tsadikim — bios trilingues sourcées, dates de hiloula hébraïques.
//    (NB : la source `src/data/tsadikim.ts` / `cities.ts` du moteur web contient
//     bien 30 tsadikim et 189 villes ; CONTRACTS annonçait ~32 / ~191. Le dataset
//     est porté FIDÈLEMENT — aucune fiche inventée : les bios doivent rester
//     sourcées, jamais fabriquées.)
//
//  Dépend du module Models (`City`, `Tsadik`, `HilulaDate`, `HebrewDateResult`,
//  `LocalizedText`) — non redéfinis ici.
//

import Foundation

/// Accès en lecture seule, paresseux et mis en cache, aux données statiques
/// embarquées. `enum` sans cas : espace de noms pur, jamais instancié.
///
/// Le chargement JSON est déclenché au premier accès à `cities` / `tsadikim`,
/// puis mémorisé pour toute la durée de vie du process (les `static let` Swift
/// sont initialisés une seule fois, de façon thread-safe — `dispatch_once`).
public enum StaticData {

    // MARK: - Datasets (lazy + cache)

    /// Les 189 villes du dataset embarqué (`Resources/cities.json`).
    /// Ordre du fichier préservé (France → Israël → US → …).
    public static var cities: [City] { Cache.cities }

    /// Les 30 fiches tsadikim (`Resources/tsadikim.json`).
    public static var tsadikim: [Tsadik] { Cache.tsadikim }

    // MARK: - Accès (API §3.3)

    /// Ville par slug, avec **repli sur `"paris"`** si le slug est introuvable
    /// (contrat : renvoie toujours une `City`, jamais `nil`).
    ///
    /// Si même `"paris"` venait à manquer (données corrompues), un repli codé en
    /// dur garantit l'absence de crash — l'UI reste toujours calculable offline.
    public static func city(slug: String) -> City {
        if let c = Cache.citiesBySlug[slug] { return c }
        if let paris = Cache.citiesBySlug["paris"] { return paris }
        return Cache.emergencyParis
    }

    /// Fiche tsadik par slug (`nil` si absente).
    public static func tsadik(slug: String) -> Tsadik? {
        Cache.tsadikimBySlug[slug]
    }

    /// Tsadikim dont la hiloula tombe à la **date hébraïque courante**.
    ///
    /// Réplique à l'identique la logique du moteur web (`hilulotOn` +
    /// `currentHilulaMonthName`) : on compare le **jour** hébraïque et le **nom
    /// de mois translittéré EN** du dataset. La conversion numéro→nom suit la
    /// numérotation Nisan-based de `HebrewDateResult.month` (1 = Nisan …
    /// 7 = Tishrei … 12 = Adar / Adar I, 13 = Adar II).
    ///
    /// Conséquence voulue (parité web) : en année embolismique, une hiloula
    /// notée `"Adar"` s'observe en **Adar I** (mois 12) ; les hiloulot `"Adar II"`
    /// s'observent en mois 13. En année ordinaire, mois 12 = `"Adar"`.
    public static func hilulotToday(hebrew: HebrewDateResult) -> [Tsadik] {
        guard let monthName = dataMonthName(forHebrewMonth: hebrew.month) else { return [] }
        let day = hebrew.day
        return tsadikim.filter { $0.hilula.day == day && $0.hilula.month == monthName }
    }

    /// Traduit un numéro de mois hébreu (Nisan-based, 1…13) vers l'orthographe
    /// EN utilisée par le dataset des tsadikim. Miroir exact de
    /// `currentHilulaMonthName` côté web. `nil` hors plage.
    static func dataMonthName(forHebrewMonth month: Int) -> String? {
        switch month {
        case 1:  return "Nisan"
        case 2:  return "Iyyar"
        case 3:  return "Sivan"
        case 4:  return "Tammuz"
        case 5:  return "Av"
        case 6:  return "Elul"
        case 7:  return "Tishrei"
        case 8:  return "Cheshvan"
        case 9:  return "Kislev"
        case 10: return "Tevet"
        case 11: return "Shevat"
        case 12: return "Adar"        // Adar (année ordinaire) / Adar I (embolismique)
        case 13: return "Adar II"     // Adar Sheni (embolismique)
        default: return nil
        }
    }

    // MARK: - Cache interne

    /// Conteneur des `static let` paresseux. Séparé pour que l'initialisation
    /// unique et thread-safe reste lisible et que les index par slug soient
    /// construits une seule fois.
    private enum Cache {
        static let cities: [City] = ResourceLoader.decode([City].self, from: "cities")
        static let tsadikim: [Tsadik] = ResourceLoader.decode([Tsadik].self, from: "tsadikim")

        static let citiesBySlug: [String: City] = Dictionary(
            cities.map { ($0.slug, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        static let tsadikimBySlug: [String: Tsadik] = Dictionary(
            tsadikim.map { ($0.slug, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        /// Repli ultime si `cities.json` est absent/corrompu ET que `"paris"`
        /// manque. Garantit la propriété « `city(slug:)` ne renvoie jamais nil »
        /// sans jamais faire crasher l'app hors-ligne.
        static let emergencyParis = City(
            slug: "paris",
            names: LocalizedText(he: "פריז", fr: "Paris", en: "Paris"),
            country: "FR",
            countryNames: LocalizedText(he: "צרפת", fr: "France", en: "France"),
            lat: 48.8566,
            lng: 2.3522,
            elevation: 35,
            tz: "Europe/Paris",
            israel: false,
            candleMinutes: 18,
            community: 280_000
        )
    }
}

// MARK: - Chargeur de ressources bundle (app + widget)

/// Décodage JSON depuis le bundle courant, robuste au multi-cible (l'app `Moed`
/// et l'extension `MoedWidgets` embarquent chacune une copie des ressources via
/// double appartenance de cible). On sonde plusieurs bundles et emplacements.
enum ResourceLoader {

    /// Décode `<name>.json` en `[T]` (ou `T`). Échec = data corrompue / absente :
    /// on `fatalError` explicite (les datasets sont livrés AVEC l'app ; leur
    /// absence est un bug de packaging, pas un état runtime légitime).
    static func decode<T: Decodable>(_ type: T.Type, from name: String) -> T {
        guard let url = url(forResource: name, withExtension: "json") else {
            fatalError("StaticData: ressource « \(name).json » introuvable dans le bundle.")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("StaticData: échec de décodage de « \(name).json » — \(error)")
        }
    }

    /// Recherche une ressource dans les bundles candidats, à la racine puis sous
    /// `Resources/` (Xcode aplatit ou non selon group vs folder-reference).
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        for bundle in candidateBundles {
            if let u = bundle.url(forResource: name, withExtension: ext) { return u }
            if let u = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources") { return u }
        }
        return nil
    }

    /// Bundles à sonder, dédupliqués : celui qui contient ce code (résout l'app
    /// ou l'extension widget selon la cible compilée), puis le bundle principal.
    static var candidateBundles: [Bundle] {
        var seen = Set<String>()
        var result: [Bundle] = []
        for bundle in [Bundle(for: BundleToken.self), .main] {
            let path = bundle.bundlePath
            if seen.insert(path).inserted { result.append(bundle) }
        }
        return result
    }
}

/// Ancre pour `Bundle(for:)` — résout le bundle de la cible courante.
private final class BundleToken {}
