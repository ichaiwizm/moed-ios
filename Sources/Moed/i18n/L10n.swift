//
//  L10n.swift
//  Moed — i18n module
//
//  Traductions embarquées, portées de `src/messages/{he,fr,en}.json` vers des
//  `Localizable.strings` (une table par langue, dossiers `*.lproj`). Clés à plat
//  en notation pointée (ex. `home.omerDay`, `zmanim.pageTitle`). Sections :
//  meta brand nav common home zmanim converter personal tsadikim calendar settings.
//
//  Sélection de langue IN-APP (indépendante de la langue système) : on charge la
//  table de la `Lang` demandée, pas celle du système. Zéro réseau.
//
//  Dépend du module Models (`Lang`).
//

import Foundation

/// Point d'accès unique aux chaînes traduites.
///
/// Les tables sont chargées paresseusement et mises en cache par langue au
/// premier accès. Une clé absente est renvoyée telle quelle (repli visible,
/// jamais de chaîne vide — facilite le repérage des trous de traduction).
public enum L10n {

    /// Chaîne traduite pour `key` dans `lang`. Repli : la clé elle-même.
    public static func t(_ key: String, _ lang: Lang) -> String {
        Store.table(for: lang)[key] ?? key
    }

    /// Chaîne traduite avec interpolation de paramètres nommés.
    ///
    /// Les gabarits utilisent des jetons `{nom}` (ex. `"Omer — day {n}"`,
    /// `"Zmanim in {city}"`), identiques au moteur web. Chaque `{clé}` présent
    /// dans `args` est remplacé par sa valeur formatée ; les jetons non fournis
    /// sont laissés intacts (repérables). Ordre-agnostique (pas de `%1$@`).
    ///
    /// - Parameters:
    ///   - args: table `nom → valeur` (`{n}` → entier, `{city}`/`{name}` → texte…).
    public static func t(_ key: String, _ lang: Lang, _ args: [String: CVarArg]) -> String {
        var result = t(key, lang)
        for (name, value) in args {
            result = result.replacingOccurrences(of: "{\(name)}", with: format(value))
        }
        return result
    }

    /// Formatage d'une valeur de paramètre en chaîne d'affichage.
    /// Entiers → sans décimale ; le reste via `String(describing:)`.
    private static func format(_ value: CVarArg) -> String {
        switch value {
        case let i as Int:    return String(i)
        case let s as String: return s
        case let d as Double: return d == d.rounded() ? String(Int(d)) : String(d)
        default:              return String(describing: value)
        }
    }

    // MARK: - Chargement + cache des tables

    private enum Store {
        /// Cache `Lang → [clé: valeur]`. Protégé par un verrou pour la sûreté
        /// concurrente (widgets + app peuvent lire en parallèle).
        /// `nonisolated(unsafe)` : accès sérialisé manuellement par `lock`
        /// (strict concurrency ne peut pas le prouver seul).
        nonisolated(unsafe) private static var cache: [Lang: [String: String]] = [:]
        private static let lock = NSLock()

        static func table(for lang: Lang) -> [String: String] {
            lock.lock()
            defer { lock.unlock() }
            if let cached = cache[lang] { return cached }
            let loaded = load(lang)
            cache[lang] = loaded
            return loaded
        }

        /// Charge `<bundle>/<lang>.lproj/Localizable.strings`. Le fichier `.strings`
        /// est un property list ancienne syntaxe : lu directement en `NSDictionary`.
        /// Repli : dictionnaire vide (les clés retomberont sur elles-mêmes).
        private static func load(_ lang: Lang) -> [String: String] {
            for bundle in candidateBundles {
                guard
                    let lprojPath = bundle.path(forResource: lang.rawValue, ofType: "lproj"),
                    let lproj = Bundle(path: lprojPath),
                    let url = lproj.url(forResource: "Localizable", withExtension: "strings"),
                    let dict = NSDictionary(contentsOf: url) as? [String: String]
                else { continue }
                return dict
            }
            return [:]
        }

        /// Mêmes bundles candidats que le chargeur de datasets (app + widget).
        private static var candidateBundles: [Bundle] {
            var seen = Set<String>()
            var result: [Bundle] = []
            for bundle in [Bundle(for: L10nBundleToken.self), .main] {
                if seen.insert(bundle.bundlePath).inserted { result.append(bundle) }
            }
            return result
        }
    }
}

/// Ancre pour `Bundle(for:)` — résout le bundle de la cible courante.
private final class L10nBundleToken {}
