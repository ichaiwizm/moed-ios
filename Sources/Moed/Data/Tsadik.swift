//
//  Tsadik.swift
//  Moed
//
//  MODULE « Models » / Data — types de donnée TSADIK (CONTRACTS.md §3.3).
//
//  Parité 1:1 avec `src/data/tsadikim.ts` du moteur web (32 fiches sourcées,
//  biographies trilingues pré-générées — jamais de LLM au runtime). Vocabulaire
//  PUR : structs immuables + enums `String Codable`, décodables directement
//  depuis `Data/Resources/tsadikim.json`. Aucune logique : le filtrage
//  « hiloula du jour » et le chargement du JSON relèvent du module Data
//  (`StaticData`), pas de ce fichier de modèle.
//

import Foundation

/// Courant / époque du tsadik. Pilote le visuel symbolique par catégorie
/// (jamais de portrait photoréaliste — exigence éditoriale, DESIGN §5.4).
public enum TsadikCategory: String, Codable, Sendable {
    case tanna
    case rishon
    case acharon
    case hassid
    case habad
    case sefarade
}

/// Niveau de fiabilité de la date de décès / hiloula.
public enum Confidence: String, Codable, Sendable {
    /// Date de décès historiquement documentée.
    case high
    /// Date bien attestée mais avec une part d'incertitude érudite.
    case medium
    /// Date par tradition, non établie historiquement.
    case traditional
}

/// Date de hiloula dans le calendrier hébraïque.
public struct HilulaDate: Codable, Hashable, Sendable {
    public let day: Int
    /// Mois hébreu translittéré EN (ex. `"Iyyar"`, `"Tevet"`, `"Adar II"`).
    public let month: String

    public init(day: Int, month: String) {
        self.day = day
        self.month = month
    }
}

/// Lieu de sépulture (kever).
public struct Kever: Codable, Hashable, Sendable {
    public let place: String
    public let country: String

    public init(place: String, country: String) {
        self.place = place
        self.country = country
    }
}

/// Fiche d'un tsadik. Champs optionnels alignés sur le dataset web
/// (`epithet`, `hilulaNote`, `yearGregorian`, `kever`, `works`).
public struct Tsadik: Codable, Identifiable, Hashable, Sendable {
    public var id: String { slug }

    public let slug: String
    public let names: LocalizedText
    public let epithet: LocalizedText?
    public let category: TsadikCategory
    public let hilula: HilulaDate
    /// Note contextuelle de hiloula (ex. « Lag BaOmer », « Pessah Sheni »).
    public let hilulaNote: LocalizedText?
    public let yearGregorian: Int?
    public let kever: Kever?
    public let works: [String]?
    /// Biographie longue, trilingue, sourcée.
    public let bio: LocalizedText
    public let confidence: Confidence
    /// Liens de référence (Wikipedia / Sefaria).
    public let sources: [String]

    public init(
        slug: String,
        names: LocalizedText,
        epithet: LocalizedText?,
        category: TsadikCategory,
        hilula: HilulaDate,
        hilulaNote: LocalizedText?,
        yearGregorian: Int?,
        kever: Kever?,
        works: [String]?,
        bio: LocalizedText,
        confidence: Confidence,
        sources: [String]
    ) {
        self.slug = slug
        self.names = names
        self.epithet = epithet
        self.category = category
        self.hilula = hilula
        self.hilulaNote = hilulaNote
        self.yearGregorian = yearGregorian
        self.kever = kever
        self.works = works
        self.bio = bio
        self.confidence = confidence
        self.sources = sources
    }
}
