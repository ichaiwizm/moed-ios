//
//  LocationProvider.swift
//  Moed
//
//  Géolocalisation opt-in (« autour de moi ») : demande l'autorisation
//  CoreLocation au moment du tap, obtient une position, puis renvoie la ville
//  la plus proche du dataset statique embarqué (`StaticData.cities`).
//
//  Contrat : CONTRACTS.md §4.2 —
//      final class LocationProvider: NSObject {
//          func requestNearestCity(_ completion: @escaping (City?) -> Void)
//      }
//
//  100 % offline pour le *matching* ville : aucune requête réseau, aucun
//  géocodage inverse serveur. Seul CoreLocation fournit la position appareil ;
//  la ville la plus proche est calculée localement (distance orthodromique).
//

import Foundation
import CoreLocation

/// Fournisseur de la ville la plus proche via CoreLocation (opt-in).
///
/// Usage :
/// ```swift
/// let provider = LocationProvider()
/// provider.requestNearestCity { city in
///     if let city { appState.update(settings: appState.settings.with(citySlug: city.slug)) }
/// }
/// ```
/// L'autorisation « When In Use » est demandée à la volée (jamais au lancement,
/// NATIVE_SPEC §9). Le `completion` est **toujours** appelé une seule fois, sur
/// le thread principal, y compris en cas de refus ou d'erreur (→ `nil`).
final class LocationProvider: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var completion: ((City?) -> Void)?
    private var didFinish = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // une ville, pas un GPS fin
    }

    /// Demande la position et renvoie la ville la plus proche du dataset.
    /// - Si l'autorisation n'est pas encore déterminée : la demande, puis
    ///   enchaîne sur la localisation une fois accordée.
    /// - Si déjà accordée : localise immédiatement.
    /// - Si refusée/restreinte : `completion(nil)`.
    func requestNearestCity(_ completion: @escaping (City?) -> Void) {
        self.completion = completion
        self.didFinish = false

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization() // suite dans didChangeAuthorization
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(nil)
        @unknown default:
            finish(nil)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // On ne réagit que si une demande est en cours (completion non consommé).
        guard completion != nil, !didFinish else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(nil)
        case .notDetermined:
            break // en attente du choix utilisateur
        @unknown default:
            finish(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(nil)
            return
        }
        finish(nearestCity(to: location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }

    // MARK: - Matching offline

    /// Ville la plus proche par distance orthodromique (CoreLocation, mètres).
    /// Calcul purement local sur le dataset embarqué — aucun réseau.
    private func nearestCity(to location: CLLocation) -> City? {
        StaticData.cities.min { a, b in
            distance(from: location, toLat: a.lat, lng: a.lng)
                < distance(from: location, toLat: b.lat, lng: b.lng)
        }
    }

    private func distance(from location: CLLocation, toLat lat: Double, lng: Double) -> CLLocationDistance {
        CLLocation(latitude: lat, longitude: lng).distance(from: location)
    }

    // MARK: - Finalisation (une seule fois, sur le main thread)

    private func finish(_ city: City?) {
        guard !didFinish else { return }
        didFinish = true
        let cb = completion
        completion = nil
        if Thread.isMainThread {
            cb?(city)
        } else {
            DispatchQueue.main.async { cb?(city) }
        }
    }
}
