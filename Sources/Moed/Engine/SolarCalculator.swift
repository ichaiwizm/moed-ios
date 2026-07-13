//
//  SolarCalculator.swift
//  Moed — Engine (source de vérité halakhique)
//
//  Calcul solaire natif en Swift pur — port fidèle de l'algorithme NOAA de
//  KosherJava (`NOAACalculator`), le moteur derrière `kosher-zmanim` (web) et
//  `KosherJava 2.5.0` (Android). AUCUNE dépendance externe : la position du
//  soleil (déclinaison, équation du temps, angle horaire) est dérivée des
//  équations de Meeus, d'où les instants de lever/coucher réels et les
//  crépuscules à un angle de dépression donné.
//
//  Parité STRICTE avec `kosher-zmanim` (validée à la milliseconde contre
//  `Fixtures/kosher_zmanim_reference.json`) :
//   • Zénith géométrique = 90° + réfraction (34′) + rayon solaire (16′) +
//     correction d'élévation (uniquement si élévation > 0).
//   • Les zmanim à angle (alot 16.1°, misheyakir 11.5°/10.2°, tzeit 8.5°…)
//     utilisent le zénith `90° + dépression`, sans correction d'élévation
//     (exactement comme `getSunriseOffsetByDegrees` / `getSunsetOffsetByDegrees`).
//   • Bascule de jour (`getDateFromTime`) reproduite : l'heure UTC est repliée
//     dans [0, 24) puis corrigée d'un jour selon la longitude, ce qui rend les
//     instants absolus identiques à `kosher-zmanim` (y compris quand le coucher
//     tombe sur le jour UTC suivant, ex. Los Angeles).
//
//  Invariants (CONTRACTS §1.3, NATIVE_SPEC §3.4) :
//   • Instants `Date` BRUTS (aucun arrondi ici — fait à l'affichage).
//   • Fuseau piloté par l'identifiant IANA de la ville (`geo.timeZone`).
//   • Aux latitudes extrêmes (le soleil n'atteint jamais l'angle requis), le
//     zman vaut `nil`, JAMAIS `NaN`.
//   • 100 % offline, déterministe, aucun appel réseau, aucun état global.
//

import Foundation

// MARK: - Calculateur solaire (une journée civile, un lieu)

/// Position solaire NOAA pour un jour civil `Y/M/D` (tel que vu dans le fuseau
/// de la ville) à une latitude / longitude / élévation données.
///
/// Expose des méthodes aux noms parlants (`sunrise()`, `sunset()`,
/// `alos16Point1Degrees()`…) consommées par `ZmanimEngine` / `CandleEngine`.
struct SolarTime {

    let year: Int
    let month: Int          // 1..12
    let day: Int            // 1..31
    let latitude: Double
    let longitude: Double   // est positif (convention `GeoContext.lng`)
    let elevation: Double   // mètres (≥ 0 ; 0 = niveau de la mer)

    // MARK: Constantes (défauts `AstronomicalCalculator` de KosherJava)

    private static let refraction  = 34.0 / 60.0     // réfraction atmosphérique
    private static let solarRadius = 16.0 / 60.0     // demi-diamètre solaire
    private static let earthRadius = 6356.9          // km
    private static let geometricZenith = 90.0

    private static let julianDayJan1_2000 = 2_451_545.0
    private static let julianDaysPerCentury = 36_525.0

    // MARK: - API (noms parlants, consommés par les moteurs)

    /// Lever du soleil (netz) à l'horizon géométrique, corrigé de l'élévation
    /// (uniquement si `elevation > 0`).
    func sunrise() -> Date? { riseOrSet(zenith: Self.geometricZenith, rise: true, adjustForElevation: true) }

    /// Coucher du soleil (shkia), corrigé de l'élévation si `elevation > 0`.
    func sunset() -> Date? { riseOrSet(zenith: Self.geometricZenith, rise: false, adjustForElevation: true) }

    /// Alot hashachar 16.1° (aube) — dépression de 16.1° sous l'horizon.
    func alos16Point1Degrees() -> Date? { riseOrSet(zenith: Self.geometricZenith + 16.1, rise: true, adjustForElevation: false) }

    /// Misheyakir 11.5°.
    func misheyakir11Point5Degrees() -> Date? { riseOrSet(zenith: Self.geometricZenith + 11.5, rise: true, adjustForElevation: false) }

    /// Misheyakir machmir 10.2°.
    func misheyakir10Point2Degrees() -> Date? { riseOrSet(zenith: Self.geometricZenith + 10.2, rise: true, adjustForElevation: false) }

    /// Tzeit hakochavim 8.5° (« 3 étoiles », Geonim).
    func tzaisGeonim8Point5Degrees() -> Date? { riseOrSet(zenith: Self.geometricZenith + 8.5, rise: false, adjustForElevation: false) }

    /// Coucher à un zénith absolu déjà exprimé en `90° + dépression`
    /// (équivalent de `getSunsetOffsetByDegrees` de KosherJava / kosher-zmanim).
    /// Utilisé pour la havdala en degrés (`90° + 8.5°`).
    func sunsetOffset(byDegrees zenith: Double) -> Date? {
        riseOrSet(zenith: zenith, rise: false, adjustForElevation: false)
    }

    // MARK: - Cœur : heure UTC → instant absolu

    /// Résout l'instant absolu du lever (`rise = true`) ou du coucher pour un
    /// zénith donné. `nil` si le soleil n'atteint jamais cet angle (polaire).
    private func riseOrSet(zenith: Double, rise: Bool, adjustForElevation: Bool) -> Date? {
        let adjusted = Self.adjustZenith(zenith, elevation: adjustForElevation ? elevation : 0)
        let jd = Self.julianDay(year: year, month: month, day: day)
        // NOAA travaille en longitude ouest-positive → on passe `-longitude`.
        let minutes = Self.timeUTC(julianDay: jd, latitude: latitude, longitude: -longitude,
                                   zenith: adjusted, rise: rise)
        guard minutes.isFinite else { return nil }

        // Repli dans [0, 24) puis correction de bascule de jour (parité
        // `kosher-zmanim` getDateFromTime).
        var hours = minutes / 60.0
        while hours < 0 { hours += 24 }
        while hours >= 24 { hours -= 24 }

        return dateFrom(utcHours: hours, rise: rise)
    }

    /// Construit l'instant UTC pour l'heure `utcHours ∈ [0, 24)` appliquée au jour
    /// civil `Y/M/D`, avec la correction de jour dépendante de la longitude.
    private func dateFrom(utcHours: Double, rise: Bool) -> Date? {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        guard let midnight = utc.date(from: comps) else { return nil }

        var date = midnight.addingTimeInterval(utcHours * 3600.0)

        // Correction de bascule de jour : `localTimeHours = trunc(longitude / 15)`.
        let hoursInt = Int(utcHours)                     // trunc (utcHours ≥ 0)
        let localTimeHours = Int((longitude / 15.0).rounded(.towardZero))
        if rise, localTimeHours + hoursInt > 18 {
            date = utc.date(byAdding: .day, value: -1, to: date) ?? date
        } else if !rise, localTimeHours + hoursInt < 6 {
            date = utc.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    // MARK: - Ajustement du zénith (réfraction / rayon solaire / élévation)

    /// Ajoute réfraction + rayon solaire (+ élévation) UNIQUEMENT au zénith
    /// géométrique (90°). Les zmanim à angle passent inchangés.
    private static func adjustZenith(_ zenith: Double, elevation: Double) -> Double {
        guard zenith == geometricZenith else { return zenith }
        let elevationAdjustment = toDegrees(acos(earthRadius / (earthRadius + elevation / 1000.0)))
        return zenith + solarRadius + refraction + elevationAdjustment
    }

    // MARK: - Algorithme NOAA (Meeus) — port de `NOAACalculator`

    /// Jour julien à 0h UT pour une date grégorienne.
    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = y / 100
        let b = 2 - a + a / 4
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + Double(b) - 1524.5
    }

    private static func julianCenturies(fromJulianDay jd: Double) -> Double {
        (jd - julianDayJan1_2000) / julianDaysPerCentury
    }

    private static func julianDay(fromJulianCenturies t: Double) -> Double {
        t * julianDaysPerCentury + julianDayJan1_2000
    }

    private static func toDegrees(_ radians: Double) -> Double { radians * 180.0 / .pi }
    private static func toRadians(_ degrees: Double) -> Double { degrees * .pi / 180.0 }

    private static func sunGeometricMeanLongitude(_ t: Double) -> Double {
        var longitude = 280.46646 + t * (36000.76983 + 0.0003032 * t)
        longitude = longitude.truncatingRemainder(dividingBy: 360.0)
        if longitude < 0 { longitude += 360.0 }
        return longitude
    }

    private static func sunGeometricMeanAnomaly(_ t: Double) -> Double {
        357.52911 + t * (35999.05029 - 0.0001537 * t)
    }

    private static func earthOrbitEccentricity(_ t: Double) -> Double {
        0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    }

    private static func sunEquationOfCenter(_ t: Double) -> Double {
        let m = toRadians(sunGeometricMeanAnomaly(t))
        return sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * m) * (0.019993 - 0.000101 * t)
            + sin(3 * m) * 0.000289
    }

    private static func sunTrueLongitude(_ t: Double) -> Double {
        sunGeometricMeanLongitude(t) + sunEquationOfCenter(t)
    }

    private static func sunApparentLongitude(_ t: Double) -> Double {
        let omega = 125.04 - 1934.136 * t
        return sunTrueLongitude(t) - 0.00569 - 0.00478 * sin(toRadians(omega))
    }

    private static func meanObliquityOfEcliptic(_ t: Double) -> Double {
        let seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))
        return 23.0 + (26.0 + seconds / 60.0) / 60.0
    }

    private static func obliquityCorrection(_ t: Double) -> Double {
        let omega = 125.04 - 1934.136 * t
        return meanObliquityOfEcliptic(t) + 0.00256 * cos(toRadians(omega))
    }

    private static func sunDeclination(_ t: Double) -> Double {
        let sint = sin(toRadians(obliquityCorrection(t))) * sin(toRadians(sunApparentLongitude(t)))
        return toDegrees(asin(sint))
    }

    /// Équation du temps, en minutes de temps.
    private static func equationOfTime(_ t: Double) -> Double {
        let epsilon = obliquityCorrection(t)
        let l0 = sunGeometricMeanLongitude(t)
        let e = earthOrbitEccentricity(t)
        let m = sunGeometricMeanAnomaly(t)
        var y = tan(toRadians(epsilon) / 2.0)
        y *= y
        let sin2l0 = sin(2.0 * toRadians(l0))
        let sinm = sin(toRadians(m))
        let cos2l0 = cos(2.0 * toRadians(l0))
        let sin4l0 = sin(4.0 * toRadians(l0))
        let sin2m = sin(2.0 * toRadians(m))
        let eqTime = y * sin2l0 - 2.0 * e * sinm + 4.0 * e * y * sinm * cos2l0
            - 0.5 * y * y * sin4l0 - 1.25 * e * e * sin2m
        return toDegrees(eqTime) * 4.0
    }

    /// Angle horaire (radians) au lever pour une latitude / déclinaison / zénith.
    /// `NaN` (via `acos` hors domaine) aux latitudes où le soleil n'atteint pas
    /// le zénith requis → propagé en `nil`.
    private static func sunHourAngleAtSunrise(latitude: Double, solarDeclination: Double, zenith: Double) -> Double {
        let latRad = toRadians(latitude)
        let sdRad = toRadians(solarDeclination)
        let x = cos(toRadians(zenith)) / (cos(latRad) * cos(sdRad)) - tan(latRad) * tan(sdRad)
        return acos(x)
    }

    /// Midi solaire UTC (minutes) pour la longitude (ouest-positive) donnée.
    private static func solarNoonUTC(_ t: Double, longitude: Double) -> Double {
        let tnoon = julianCenturies(fromJulianDay: julianDay(fromJulianCenturies: t) + longitude / 360.0)
        var eqTime = equationOfTime(tnoon)
        var solNoon = 720.0 + longitude * 4.0 - eqTime
        let newt = julianCenturies(fromJulianDay: julianDay(fromJulianCenturies: t) - 0.5 + solNoon / 1440.0)
        eqTime = equationOfTime(newt)
        solNoon = 720.0 + longitude * 4.0 - eqTime
        return solNoon
    }

    /// Heure UTC (minutes) du lever/coucher (double passe NOAA).
    private static func timeUTC(julianDay jd: Double, latitude: Double, longitude: Double,
                               zenith: Double, rise: Bool) -> Double {
        let t = julianCenturies(fromJulianDay: jd)
        let noon = solarNoonUTC(t, longitude: longitude)

        func pass(_ tCent: Double) -> Double {
            let eqTime = equationOfTime(tCent)
            let solarDec = sunDeclination(tCent)
            var hourAngle = sunHourAngleAtSunrise(latitude: latitude, solarDeclination: solarDec, zenith: zenith)
            if !rise { hourAngle = -hourAngle }
            let delta = longitude - toDegrees(hourAngle)
            return 720.0 + 4.0 * delta - eqTime
        }

        // 1re passe ancrée sur le midi solaire, 2nde passe raffinée.
        let tnoon = julianCenturies(fromJulianDay: jd + noon / 1440.0)
        let first = pass(tnoon)
        let newt = julianCenturies(fromJulianDay: julianDay(fromJulianCenturies: t) + first / 1440.0)
        return pass(newt)
    }
}

// MARK: - Fabrique (jour civil + lieu → SolarTime)

/// Prépare un `SolarTime` pour le jour civil de `date` vu dans le fuseau IANA de
/// `geo`, et exécute `body` avec lui. Le calcul est purement natif et sans état
/// global de process : rien à sérialiser, résultat déterministe.
enum SolarCalendar {

    /// - Returns: la valeur produite par `body` (ex. `Date?`).
    static func withCalendar<T>(date: Date, geo: GeoContext, _ body: (SolarTime) -> T) -> T {
        let timeZone = TimeZone(identifier: geo.timeZone) ?? TimeZone(identifier: "UTC")!
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let ymd = gregorian.dateComponents([.year, .month, .day], from: date)

        // Élévation prise en compte SEULEMENT si strictement positive.
        let elevation = geo.elevation > 0 ? geo.elevation : 0

        let solar = SolarTime(year: ymd.year ?? 2000,
                              month: ymd.month ?? 1,
                              day: ymd.day ?? 1,
                              latitude: geo.lat,
                              longitude: geo.lng,
                              elevation: elevation)
        return body(solar)
    }
}
