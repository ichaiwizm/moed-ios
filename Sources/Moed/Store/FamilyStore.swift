//
//  FamilyStore.swift
//  Moed
//
//  Persistance du carnet familial (`[PersonRecord]`) en JSON, dans le
//  répertoire Documents de l'app. Aucune donnée ne quitte l'appareil
//  (privacy by design — NATIVE_SPEC §7.2). Les widgets ne lisent pas le carnet
//  familial ; ils recalculent zmanim/dates via les moteurs déterministes.
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
/// `moed_family.json` dans le répertoire Documents de l'app. Écriture
/// atomique + protection de fichier (chiffré au repos) puisque ce sont des
/// données personnelles (noms, dates de décès/naissance).
enum FamilyStore {

    /// Nom du fichier (clé logique `moed_family`).
    private static let fileName = "moed_family.json"

    /// URL du fichier dans le répertoire Documents local de l'app.
    private static var fileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
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
