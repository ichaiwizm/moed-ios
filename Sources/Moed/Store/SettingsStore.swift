//
//  SettingsStore.swift
//  Moed
//
//  Persistance des préférences utilisateur (`Settings`) dans le domaine
//  `UserDefaults` de l'App Group `group.com.wizycode.moed`, partagé entre
//  l'app et les widgets WidgetKit. Rien ne quitte l'appareil.
//
//  Contrat : CONTRACTS.md §4.2 —
//      enum SettingsStore { static func load() -> Settings ; static func save(_:) }
//
//  100 % offline, synchrone, déterministe. Aucun réseau.
//

import Foundation

/// Identifiant de l'App Group partagé app ↔ widgets (CONTRACTS.md §4.2).
/// Utilisé par `SettingsStore` (UserDefaults) et `FamilyStore` (container fichier).
enum AppGroup {
    static let identifier = "group.com.wizycode.moed"
}

/// Encodeurs/décodeurs JSON partagés, configurés pour une sérialisation stable
/// et cross-plateforme (dates ISO-8601, clés triées pour des diffs déterministes).
enum MoedJSON {
    // `nonisolated(unsafe)` : JSONEncoder/JSONDecoder ne sont pas Sendable, mais
    // ces instances partagées ne sont utilisées qu'en configuration figée
    // (encode/decode ponctuels) — sûr, et requis pour compiler en Swift 6.
    nonisolated(unsafe) static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    nonisolated(unsafe) static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// Store des préférences (`Settings`) — CONTRACTS.md §4.2.
///
/// Stockage : une seule entrée `Data` (JSON de `Settings`) sous la clé
/// `moed_settings` dans le `UserDefaults` de l'App Group. Le format `Data`
/// (plutôt que des clés éclatées) garantit l'atomicité et suit l'évolution du
/// type `Settings` sans migration de clés.
enum SettingsStore {

    /// Clé de stockage dans le `UserDefaults` de l'App Group.
    private static let key = "moed_settings"

    /// `UserDefaults` de l'App Group ; retombe sur `.standard` si l'entitlement
    /// App Group n'est pas disponible (ex. tests unitaires hors sandbox signé),
    /// afin de ne jamais crasher au chargement.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    /// Charge les préférences persistées. Retourne `Settings()` (défauts du
    /// contrat : ville `paris`, allumage `.auto`, tzeit `.degrees`,
    /// région `.auto`, langue `nil` = système, notifications toutes `false`)
    /// si rien n'est encore stocké ou si le décodage échoue.
    static func load() -> Settings {
        guard
            let data = defaults.data(forKey: key),
            let settings = try? MoedJSON.decoder.decode(Settings.self, from: data)
        else {
            return Settings()
        }
        return settings
    }

    /// Persiste les préférences. Silencieux en cas d'échec d'encodage
    /// (impossible pour un `Settings` bien formé) — on ne casse jamais l'UI.
    static func save(_ settings: Settings) {
        guard let data = try? MoedJSON.encoder.encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
