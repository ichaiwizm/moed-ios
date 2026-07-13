//
//  City.swift
//  Moed
//
//  MODULE « Models » / Data — type de donnée VILLE (CONTRACTS.md §3.3).
//
//  Parité 1:1 avec `src/data/cities.ts` du moteur web (191 villes, format riche
//  conservé côté iOS : tous les champs trilingues + `candleMinutes` + `israel`).
//  Type de vocabulaire PUR : struct immuable `Codable`, décodable directement
//  depuis `Data/Resources/cities.json`. Le seul membre non-stocké est le helper
//  contractuel `geoContext(candleMode:)`, purement lexical (assemble un
//  `GeoContext` à partir des champs de la ville — aucun calcul astronomique).
//
//  La résolution `slug → City` et le chargement paresseux du JSON relèvent du
//  module Data (`StaticData`), PAS de ce fichier de modèle.
//

import Foundation

/// Une ville du dataset embarqué. `candleMinutes` encode le minhag d'allumage
/// local (Jérusalem 40 ; Haïfa / Petah Tikva / Beer Sheva 30 ; défaut 18 ;
/// quelques communautés 20). `tz` est un identifiant IANA (pilote le DST).
public struct City: Codable, Identifiable, Hashable, Sendable {
    public var id: String { slug }

    /// Identifiant unique en kebab-case (ex. `"paris"`).
    public let slug: String
    /// Nom de la ville, trilingue.
    public let names: LocalizedText
    /// Code pays ISO-2 (ex. `"FR"`).
    public let country: String
    /// Nom du pays, trilingue.
    public let countryNames: LocalizedText
    public let lat: Double
    public let lng: Double
    /// Élévation en mètres. `nil` ⇒ niveau de la mer (traité comme `0`).
    public let elevation: Double?
    /// Identifiant IANA (ex. `"Asia/Jerusalem"`).
    public let tz: String
    /// `true` si la ville est en Israël (affecte fêtes / parasha / haftara).
    public let israel: Bool
    /// Minutes d'allumage avant le coucher (minhag local).
    public let candleMinutes: Int
    /// Ordre de grandeur de la population juive (facultatif).
    public let community: Int?

    public init(
        slug: String,
        names: LocalizedText,
        country: String,
        countryNames: LocalizedText,
        lat: Double,
        lng: Double,
        elevation: Double?,
        tz: String,
        israel: Bool,
        candleMinutes: Int,
        community: Int?
    ) {
        self.slug = slug
        self.names = names
        self.country = country
        self.countryNames = countryNames
        self.lat = lat
        self.lng = lng
        self.elevation = elevation
        self.tz = tz
        self.israel = israel
        self.candleMinutes = candleMinutes
        self.community = community
    }

    /// Assemble le `GeoContext` consommé par le moteur solaire.
    ///
    /// Helper purement lexical : il ne calcule aucun horaire. Le `candleMode`
    /// figure dans la signature contractuelle car l'appelant le résout en amont ;
    /// le nombre de minutes effectif (auto = `candleMinutes` de la ville, sinon
    /// l'offset explicite) est appliqué par `CandleEngine`, pas ici. L'élévation
    /// absente retombe sur `0` (niveau mer). Le nom EN sert de libellé d'affichage.
    public func geoContext(candleMode: CandleMode) -> GeoContext {
        _ = candleMode
        return GeoContext(
            lat: lat,
            lng: lng,
            elevation: elevation ?? 0,
            timeZone: tz,
            name: names.en
        )
    }
}
