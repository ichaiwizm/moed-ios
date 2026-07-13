//
//  EngineModels.swift
//  Moed
//
//  MODULE « Models » — racine du graphe de dépendances (CONTRACTS.md §1).
//
//  Vocabulaire de données PUR : structs immuables (sorties moteur) + enums
//  `Codable` (catégories / préférences persistées). Zéro logique de calcul —
//  aucune conversion de date, aucun zman, aucune règle halakhique n'est
//  résolue ici. Ces types sont CONSOMMÉS par tous les autres modules
//  (Zmanim, CalendarEngine, Data, Store, Screens, Widgets) et PRODUITS par le
//  moteur ; leurs noms de types et de champs sont GELÉS (toute divergence =
//  build cassé). Seuls sont admis ici les helpers strictement lexicaux exigés
//  par le contrat (mapping i18n, direction de mise en page, sous-ensembles
//  d'affichage figés).
//
//  Conventions (CONTRACTS.md) :
//    • Toutes les `Date` sont des instants absolus (jamais arrondis avant la fin).
//    • Un zman absent (latitude extrême) est `nil`, JAMAIS `NaN`.
//    • `struct` immuables pour les sorties moteur, `enum String Codable` pour
//      les catégories, valeurs par défaut portées 1:1 depuis le moteur web.
//
//  Aucune dépendance runtime hormis Foundation (types de base) et SwiftUI
//  (uniquement pour `LayoutDirection`, requis par la signature `Lang.dir`).
//

import Foundation
import SwiftUI

// MARK: - 1.1 Transverses i18n / géo

/// Langue active du produit. Hébreu = langue primaire (RTL).
/// Défaut de code : `fr` ; au premier lancement on suit la langue système
/// (`fromSystem()`), sinon `en`.
public enum Lang: String, Codable, CaseIterable, Sendable {
    case he
    case fr
    case en

    /// Mappe la langue système vers he / fr / en. Repli ultime : `en`.
    /// (Un `Settings.lang == nil` signifie « suivre le système au 1er lancement ».)
    public static func fromSystem() -> Lang {
        for identifier in Locale.preferredLanguages {
            // Normalise « he-IL », « iw », « fr-CA », « en_US »… vers le code langue.
            let code = identifier
                .replacingOccurrences(of: "_", with: "-")
                .split(separator: "-")
                .first
                .map { String($0).lowercased() } ?? ""
            switch code {
            case "he", "iw": return .he   // « iw » = ancien code ISO de l'hébreu
            case "fr":       return .fr
            case "en":       return .en
            default:         continue
            }
        }
        return .en
    }

    /// Direction de mise en page pour cette langue. RTL uniquement pour l'hébreu.
    public var dir: LayoutDirection {
        self == .he ? .rightToLeft : .leftToRight
    }

    /// Étiquette BCP-47 pour le formatage (`DateFormatter`, `Locale`, VoiceOver).
    public var bcp47: String {
        switch self {
        case .he: return "he-IL"
        case .fr: return "fr-FR"
        case .en: return "en-US"
        }
    }
}

/// Chaîne trilingue à parité. Décodable directement depuis les JSON `{he,fr,en}`
/// (villes, tsadikim) et les tables de noms maison (mois, jours, fêtes).
public struct LocalizedText: Codable, Hashable, Sendable {
    public let he: String
    public let fr: String
    public let en: String

    public init(he: String, fr: String, en: String) {
        self.he = he
        self.fr = fr
        self.en = en
    }

    /// Sélectionne la variante de la langue active. Usage : `names(lang)`.
    public func callAsFunction(_ lang: Lang) -> String {
        switch lang {
        case .he: return he
        case .fr: return fr
        case .en: return en
        }
    }
}

/// Contexte géographique consommé par le moteur solaire.
/// La timezone IANA PILOTE le DST ; l'élévation n'agit sur lever/coucher que si `> 0`.
public struct GeoContext: Hashable, Sendable {
    public let lat: Double
    public let lng: Double
    /// Mètres au-dessus du niveau de la mer. `0` = niveau mer (aligne le défaut lat/lng).
    /// Utilisée pour lever/coucher SEULEMENT si `> 0`.
    public let elevation: Double
    /// Identifiant IANA (ex. `"Asia/Jerusalem"`). Source de vérité pour le DST.
    public let timeZone: String
    /// Libellé lisible optionnel (nom de ville), pour affichage/fallback.
    public let name: String?

    public init(lat: Double, lng: Double, elevation: Double, timeZone: String, name: String?) {
        self.lat = lat
        self.lng = lng
        self.elevation = elevation
        self.timeZone = timeZone
        self.name = name
    }
}

// MARK: - 1.2 Date hébraïque

/// Résultat d'une conversion grégorien → hébreu, prêt à l'affichage.
/// `monthName` / `weekdayName` proviennent des tables maison (he/fr/en) —
/// jamais du rendu `fr` d'une lib (hebcal/KosherJava ne connaissent que en/he).
public struct HebrewDateResult: Hashable, Sendable {
    public let year: Int
    /// 1..13 (13 = Adar II en année embolismique).
    public let month: Int
    /// 1..30.
    public let day: Int
    /// 1 = dimanche … 7 = samedi.
    public let dayOfWeek: Int
    public let isLeapYear: Bool
    public let monthName: LocalizedText
    public let weekdayName: LocalizedText
    /// Année en lettres hébraïques, ex. `"תשפ״ה"`.
    public let yearHebrew: String
    /// Jour en lettres hébraïques, ex. `"ט״ו"`.
    public let dayHebrew: String

    public init(
        year: Int,
        month: Int,
        day: Int,
        dayOfWeek: Int,
        isLeapYear: Bool,
        monthName: LocalizedText,
        weekdayName: LocalizedText,
        yearHebrew: String,
        dayHebrew: String
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.dayOfWeek = dayOfWeek
        self.isLeapYear = isLeapYear
        self.monthName = monthName
        self.weekdayName = weekdayName
        self.yearHebrew = yearHebrew
        self.dayHebrew = dayHebrew
    }
}

// MARK: - 1.3 Zmanim

/// Catalogue FIGÉ des 16 zmanim. Les clés sont celles du moteur web /
/// des getters KosherJava (parité de calcul inter-plateformes).
public enum ZmanKey: String, CaseIterable, Sendable {
    case alotHashachar
    case alotHashachar72
    case misheyakir
    case misheyakirMachmir
    case hanetzHachama
    case sofZmanShmaMGA
    case sofZmanShmaGRA
    case sofZmanTfilaMGA
    case sofZmanTfilaGRA
    case chatzot
    case minchaGedola
    case minchaKetana
    case plagHamincha
    case shkiaHachama
    case tzeitHakochavim
    case tzeit72
}

/// Un zman résolu. `date == nil` aux latitudes polaires (le soleil n'atteint
/// jamais l'angle requis) → l'UI affiche « — », jamais `NaN`.
public struct Zman: Identifiable, Hashable, Sendable {
    public var id: String { key }
    /// `rawValue` d'un `ZmanKey`.
    public let key: String
    /// Instant absolu, ou `nil` (latitude extrême).
    public let date: Date?
    /// Libellé de shita TOUJOURS affiché (transparence halakhique),
    /// ex. `"16.1°"`, `"72 min"`, `"GRA"`.
    public let shita: String

    public init(key: String, date: Date?, shita: String) {
        self.key = key
        self.date = date
        self.shita = shita
    }
}

/// Ensemble des zmanim d'un jour civil pour un lieu donné.
public struct ZmanimResult: Sendable {
    /// Ordre catalogue (`ZmanKey.allCases`).
    public let zmanim: [Zman]
    /// Accès O(1) par `ZmanKey.rawValue`.
    public let byKey: [String: Zman]
    public let location: GeoContext
    /// Jour civil calculé.
    public let date: Date
    /// `sunset − candleMinutes` (si veille de Chabbat / Yom Tov), sinon `nil`.
    public let candleLighting: Date?
    /// 8.5° ou offset minutes (selon `TzeitMethod`), sinon `nil`.
    public let havdalah: Date?

    public init(
        zmanim: [Zman],
        byKey: [String: Zman],
        location: GeoContext,
        date: Date,
        candleLighting: Date?,
        havdalah: Date?
    ) {
        self.zmanim = zmanim
        self.byKey = byKey
        self.location = location
        self.date = date
        self.candleLighting = candleLighting
        self.havdalah = havdalah
    }
}

/// Sous-ensembles d'affichage FIGÉS (DESIGN §5.1 / §5.3).
public enum ZmanCatalog {
    /// Zmanim clés de l'écran « Aujourd'hui ».
    public static let home: [ZmanKey] = [
        .hanetzHachama,
        .sofZmanShmaGRA,
        .chatzot,
        .minchaGedola,
        .shkiaHachama,
        .tzeitHakochavim,
    ]
    /// Catalogue complet (page ville détaillée).
    public static let all: [ZmanKey] = ZmanKey.allCases
}

// MARK: - 1.4 Calendrier — événements, fête, jeûne, parasha, Daf, jour

/// Catégorie d'événement calendaire (colore les badges — DESIGN §5.4 / §5.6).
public enum EventCategory: String, Sendable {
    case holiday
    case yomtov
    case fast
    case roshchodesh
    case omer
    case parasha
    case other
}

/// Fenêtre temporelle d'un jeûne, dérivée des zmanim.
public struct FastTiming: Hashable, Sendable {
    public let start: Date?
    public let end: Date?
    /// `true` = jeûne de 25 h (Kippour / 9 Av : coucher de la veille → tzeit) ;
    /// `false` = jeûne mineur (alot → tzeit).
    public let is25Hour: Bool

    public init(start: Date?, end: Date?, is25Hour: Bool) {
        self.start = start
        self.end = end
        self.is25Hour = is25Hour
    }
}

/// Un événement du calendrier hébraïque pour un jour donné.
public struct CalEvent: Identifiable, Sendable {
    /// Identifiant hebcal, ex. `"Rosh Hashana"` — sert aussi d'`id`.
    public var id: String { desc }
    public let desc: String
    public let category: EventCategory
    public let title: LocalizedText
    public let emoji: String?
    public let isYomTov: Bool
    public let fast: FastTiming?

    public init(
        desc: String,
        category: EventCategory,
        title: LocalizedText,
        emoji: String?,
        isYomTov: Bool,
        fast: FastTiming?
    ) {
        self.desc = desc
        self.category = category
        self.title = title
        self.emoji = emoji
        self.isYomTov = isYomTov
        self.fast = fast
    }
}

/// Parashat hashavoua + haftarot. hebcal ne fournit que en/he pour le nom.
public struct ParashaInfo: Sendable {
    public let name: (en: String, he: String)
    public let torah: String?
    /// Haftara ashkénaze.
    public let haftara: String?
    /// Haftara sépharade (table statique `HaftaraSephardic` si la lib est incomplète).
    public let haftaraSephardic: String?

    public init(
        name: (en: String, he: String),
        torah: String?,
        haftara: String?,
        haftaraSephardic: String?
    ) {
        self.name = name
        self.torah = torah
        self.haftara = haftara
        self.haftaraSephardic = haftaraSephardic
    }
}

/// Page de Daf Yomi du jour.
public struct DafYomiInfo: Sendable {
    public let masechet: String
    public let daf: String
    public let render: (en: String, he: String)

    public init(masechet: String, daf: String, render: (en: String, he: String)) {
        self.masechet = masechet
        self.daf = daf
        self.render = render
    }
}

/// Agrégat complet d'un jour calendaire (produit par `CalendarEngine.day`).
public struct CalendarDay: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let hebrew: HebrewDateResult
    public let events: [CalEvent]
    /// 1..49, ou `nil` hors période du Omer.
    public let omer: Int?
    public let dafYomi: DafYomiInfo
    /// Renseigné uniquement le Chabbat.
    public let parasha: ParashaInfo?
    public let candleLighting: Date?
    public let havdalah: Date?

    public init(
        date: Date,
        hebrew: HebrewDateResult,
        events: [CalEvent],
        omer: Int?,
        dafYomi: DafYomiInfo,
        parasha: ParashaInfo?,
        candleLighting: Date?,
        havdalah: Date?
    ) {
        self.date = date
        self.hebrew = hebrew
        self.events = events
        self.omer = omer
        self.dafYomi = dafYomi
        self.parasha = parasha
        self.candleLighting = candleLighting
        self.havdalah = havdalah
    }
}

// MARK: - 1.5 Personnel — yahrzeit / anniversaire

public enum PersonType: String, Codable, Sendable {
    case yahrzeit
    case birthday
}

/// Fiche du carnet familial (persistée on-device, rien ne quitte l'appareil).
/// Mutable sur ses champs éditables ; `id` figé.
public struct PersonRecord: Codable, Identifiable, Hashable, Sendable {
    /// UUID sous forme de chaîne.
    public let id: String
    public var type: PersonType
    public var name: String
    /// Date grégorienne d'origine (décès / naissance).
    public var date: Date
    /// Avance la date hébraïque d'un jour (événement survenu après la tombée de la nuit).
    public var afterSunset: Bool

    public init(id: String, type: PersonType, name: String, date: Date, afterSunset: Bool) {
        self.id = id
        self.type = type
        self.name = name
        self.date = date
        self.afterSunset = afterSunset
    }
}

/// Une occurrence future (anniversaire / yahrzeit) résolue.
public struct Occurrence: Identifiable, Sendable {
    public var id: Date { gregorian }
    public let gregorian: Date
    public let hebrew: HebrewDateResult
    public let hebrewYear: Int

    public init(gregorian: Date, hebrew: HebrewDateResult, hebrewYear: Int) {
        self.gregorian = gregorian
        self.hebrew = hebrew
        self.hebrewYear = hebrewYear
    }
}

// MARK: - 1.6 Préférences persistées — Settings

/// Minhag d'allumage : `auto` (= minhag de la ville) ou offset fixe en minutes
/// (18 / 20 / 30 / 40). Codable auto-synthétisé (enum à valeur associée).
public enum CandleMode: Codable, Equatable, Sendable {
    case auto
    case minutes(Int)
}

/// Shita de tzeit / havdala : 8.5° (« 3 étoiles ») ou offset fixe en minutes.
public enum TzeitMethod: String, Codable, Sendable {
    case degrees
    case minutes
}

/// Sélection du calendrier des fêtes : selon la ville, ou forcé Israël / Diaspora.
public enum Region: String, Codable, Sendable {
    case auto
    case il
    case diaspora
}

/// Préférences de rappels (tous opt-in, tous `false` par défaut).
public struct NotifPrefs: Codable, Equatable, Sendable {
    public var shabbat: Bool
    public var omer: Bool
    public var hilula: Bool
    public var yahrzeit: Bool

    public init(shabbat: Bool = false, omer: Bool = false, hilula: Bool = false, yahrzeit: Bool = false) {
        self.shabbat = shabbat
        self.omer = omer
        self.hilula = hilula
        self.yahrzeit = yahrzeit
    }
}

/// Réglages persistés (UserDefaults App Group). Valeurs par défaut portées du web.
public struct Settings: Codable, Equatable, Sendable {
    public var citySlug: String
    public var candle: CandleMode
    public var tzeit: TzeitMethod
    public var region: Region
    /// `nil` = suivre la langue système au 1er lancement.
    public var lang: Lang?
    public var notif: NotifPrefs

    public init(
        citySlug: String = "paris",
        candle: CandleMode = .auto,
        tzeit: TzeitMethod = .degrees,
        region: Region = .auto,
        lang: Lang? = nil,
        notif: NotifPrefs = NotifPrefs()
    ) {
        self.citySlug = citySlug
        self.candle = candle
        self.tzeit = tzeit
        self.region = region
        self.lang = lang
        self.notif = notif
    }
}

// MARK: - 1.7 Modèle d'écran « Aujourd'hui »

/// Sortie agrégée consommée par `TodayView` (produite par `AppState.today()`),
/// figée pour que la vue ne rappelle pas le moteur pièce par pièce.
public struct TodayModel: Sendable {
    public let city: City
    public let hebrew: HebrewDateResult
    public let gregorian: Date
    public let omer: Int?
    /// Fêtes / RH / jeûne du jour.
    public let events: [CalEvent]
    /// `nil` si trop loin ou non pertinent.
    public let shabbat: ShabbatModel?
    /// `ZmanCatalog.home` résolus.
    public let homeZmanim: [Zman]
    /// Le « zman clé » surligné (prochain à venir).
    public let keyZmanKey: ZmanKey?
    public let parasha: ParashaInfo?
    public let dafYomi: DafYomiInfo
    public let activeFast: FastTiming?

    public init(
        city: City,
        hebrew: HebrewDateResult,
        gregorian: Date,
        omer: Int?,
        events: [CalEvent],
        shabbat: ShabbatModel?,
        homeZmanim: [Zman],
        keyZmanKey: ZmanKey?,
        parasha: ParashaInfo?,
        dafYomi: DafYomiInfo,
        activeFast: FastTiming?
    ) {
        self.city = city
        self.hebrew = hebrew
        self.gregorian = gregorian
        self.omer = omer
        self.events = events
        self.shabbat = shabbat
        self.homeZmanim = homeZmanim
        self.keyZmanKey = keyZmanKey
        self.parasha = parasha
        self.dafYomi = dafYomi
        self.activeFast = activeFast
    }
}

/// Bloc « prochain Chabbat » de l'écran d'accueil.
public struct ShabbatModel: Sendable {
    public let parashaName: LocalizedText
    public let candleLighting: Date
    public let havdalah: Date?

    public init(parashaName: LocalizedText, candleLighting: Date, havdalah: Date?) {
        self.parashaName = parashaName
        self.candleLighting = candleLighting
        self.havdalah = havdalah
    }
}
