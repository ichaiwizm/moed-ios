//
//  FamilyStore.swift
//  Moed
//
//  Persistance du carnet familial (`[PersonRecord]`) en JSON, dans le container
//  de l'App Group `group.com.wizycode.moed`. Aucune donnée ne quitte l'appareil
//  (privacy by design — NATIVE_SPEC §7.2). Le fichier étant dans l'App Group,
//  les widgets WidgetKit y accèdent en lecture pour recalculer localement.
//
//  Contrat : CONTRACTS.md §4.2 —
//      enum FamilyStore { static func load() -> [PersonRecord] ; static func save(_:) }
//
//  100 % offline, déterministe. Aucun réseau, aucun backend.
//

import Foundation

/// Store du carnet familial — CONTRACTS.md §4.2.
///
/// Format : un tableau JSON `[PersonRecord]` écrit dans
/// `moed_family.json` à la racine du container partagé App Group. Écriture
/// atomique + protection de fichier (chiffré au repos) puisque ce sont des
/// données personnelles (noms, dates de décès/naissance).
enum FamilyStore {

    /// Nom du fichier dans le container App Group (clé logique `moed_family`).
    private static let fileName = "moed_family.json"

    /// URL du fichier dans le container de l'App Group, ou `nil` si l'App Group
    /// n'est pas disponible (dans ce cas on retombe sur le répertoire Documents
    /// pour rester fonctionnel même sans entitlement — ex. tests).
    private static var fileURL: URL? {
        let fm = FileManager.default
        if let container = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            return container.appendingPathComponent(fileName)
        }
        // Repli : Documents locaux (l'app fonctionne, les widgets ne partagent
        // simplement pas le fichier tant que l'App Group n'est pas configuré).
        return fm.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    /// Charge le carnet. Retourne `[]` si le fichier n'existe pas encore ou si
    /// le décodage échoue (jamais de crash, jamais de `nil`).
    static func load() -> [PersonRecord] {
        guard
            let url = fileURL,
            let data = try? Data(contentsOf: url),
            let people = try? MoedJSON.decoder.decode([PersonRecord].self, from: data)
        else {
            return []
        }
        return people
    }

    /// Persiste le carnet de façon atomique et chiffrée au repos. Silencieux en
    /// cas d'échec (on ne bloque jamais l'UI sur une écriture disque).
    static func save(_ people: [PersonRecord]) {
        guard let url = fileURL else { return }
        do {
            let data = try MoedJSON.encoder.encode(people)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            // Écriture best-effort : une erreur disque ne doit pas propager.
        }
    }
}
