//
//  AppState.swift
//  Moed
//
//  État applicatif racine (Observation framework, iOS 17) injecté en
//  `.environment`. Détient les préférences, le carnet familial et l'instant
//  courant (`now`, tick 1 s), expose des dérivés synchrones (ville/geo/langue/
//  direction) et une façade d'API que les vues consomment SANS jamais appeler
//  le moteur directement (CONTRACTS.md §4.2 / §4.3).
//
//  Orchestration pure : agrège CalendarEngine / ZmanimEngine / CandleEngine /
//  HebrewDateEngine / PersonalEngine / StaticData. Aucun calcul halakhique n'est
//  refait ici — tout provient des moteurs déterministes offline. Aucun réseau.
//
//  Contrat gelé (CONTRACTS.md §4.2) :
//      @Observable final class AppState {
//          var settings: Settings
//          var family: [PersonRecord]
//          var now: Date
//          var city: City ; var geo: GeoContext ; var lang: Lang ; var layoutDirection: LayoutDirection
//          func today() -> TodayModel
//          func zmanim(date: Date) -> ZmanimResult
//          func calendar(monthOffset: Int) -> [CalendarDay]
//          func occurrences(_ p: PersonRecord) -> [Occurrence]
//          func addPerson(_ p: PersonRecord) ; func removePerson(id: String) ; func update(settings: Settings)
//      }
//

import Foundation
import Observation
import SwiftUI

@Observable
final class AppState {

    // MARK: - État persisté / temps

    /// Préférences utilisateur (persistées via `SettingsStore`, App Group).
    var settings: Settings {
        didSet { SettingsStore.save(settings) }
    }

    /// Carnet familial local (persisté via `FamilyStore`, App Group).
    var family: [PersonRecord] {
        didSet { FamilyStore.save(family) }
    }

    /// Instant courant, rafraîchi chaque seconde par un `Timer` → pilote le
    /// compte à rebours d'allumage et la mise en évidence du prochain zman.
    var now: Date

    // MARK: - Timer 1 s

    @ObservationIgnored private var ticker: Timer?

    // MARK: - Dérivés synchrones (recalculés instantanément, offline)

    /// Ville active (fallback `paris` si le slug est inconnu — cf. `StaticData`).
    var city: City { StaticData.city(slug: settings.citySlug) }

    /// Contexte géographique dérivé de la ville + du mode d'allumage courant.
    var geo: GeoContext { city.geoContext(candleMode: settings.candle) }

    /// Langue effective : préférence explicite, sinon langue système au 1er lancement.
    var lang: Lang { settings.lang ?? Lang.fromSystem() }

    /// Direction de lecture : RTL en hébreu, LTR sinon.
    var layoutDirection: LayoutDirection { lang == .he ? .rightToLeft : .leftToRight }

    /// Région effective pour le calendrier des fêtes / parasha / haftara.
    /// `.auto` suit le flag `israel` de la ville active (Israël vs diaspora).
    var effectiveRegion: Region {
        switch settings.region {
        case .auto:     return city.israel ? .il : .diaspora
        case .il:       return .il
        case .diaspora: return .diaspora
        }
    }

    // MARK: - Init

    /// Charge l'état persisté et démarre le tick. Les paramètres permettent
    /// l'injection dans les tests / previews (état figé sans horloge).
    init(
        settings: Settings? = nil,
        family: [PersonRecord]? = nil,
        now: Date = Date(),
        startTicking: Bool = true
    ) {
        self.settings = settings ?? SettingsStore.load()
        self.family = family ?? FamilyStore.load()
        self.now = now
        if startTicking {
            startTick()
        }
        // Replanifie la fenêtre glissante de notifications au démarrage
        // (les échéances sont déterministes — aucune dépendance réseau/push).
        rescheduleNotifications()
    }

    deinit {
        ticker?.invalidate()
    }

    // MARK: - Contrôle du tick (appelé aussi par le scenePhase depuis RootView)

    /// Démarre l'horloge 1 s. Sans effet si déjà active.
    func startTick() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common) // continue de battre pendant le scroll
        ticker = timer
    }

    /// Arrête l'horloge (ex. app en arrière-plan) pour économiser l'énergie.
    func stopTick() {
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - API façade consommée par les vues (§4.2)

    /// Agrège l'écran « Aujourd'hui » : date hébraïque, badges, Chabbat à venir,
    /// zmanim clés (avec le prochain surligné), parasha, Daf Yomi, jeûne actif.
    /// Tout est calculé pour `now` et la ville/minhag/langue courants.
    func today() -> TodayModel {
        let ref = now
        let geo = self.geo
        let region = effectiveRegion
        let lang = self.lang

        // Zmanim du jour civil courant (une seule passe, réutilisée).
        let z = ZmanimEngine.zmanim(date: ref, geo: geo, settings: settings)

        // Le jour hébraïque commence au coucher : après la shkia, on avance d'un
        // jour pour l'en-tête ET les événements, afin qu'ils restent cohérents
        // (NATIVE_SPEC §3.4). Les zmanim, eux, restent ceux du jour solaire.
        let sunset = z.byKey[ZmanKey.shkiaHachama.rawValue]?.date
        let afterSunset = sunset.map { ref >= $0 } ?? false

        let hebrew = HebrewDateEngine.convert(ref, afterSunset: afterSunset, geo: geo, lang: lang)

        let hebrewDayCivil = afterSunset
            ? (civilCalendar.date(byAdding: .day, value: 1, to: ref) ?? ref)
            : ref
        let todayCal = CalendarEngine.day(hebrewDayCivil, geo: geo, region: region, lang: lang)

        // Événements pertinents du jour (fêtes / Yom Tov / Roch Hodech / jeûne).
        let relevant: Set<EventCategory> = [.holiday, .yomtov, .roshchodesh, .fast]
        let events = todayCal.events.filter { relevant.contains($0.category) }

        // Zmanim clés (sous-ensemble HOME) résolus dans l'ordre du catalogue.
        let homeZmanim: [Zman] = ZmanCatalog.home.compactMap { z.byKey[$0.rawValue] }

        // Zman clé surligné = le prochain à venir parmi les HOME zmanim.
        let keyZmanKey: ZmanKey? = ZmanCatalog.home
            .compactMap { key -> (ZmanKey, Date)? in
                guard let d = z.byKey[key.rawValue]?.date else { return nil }
                return (key, d)
            }
            .filter { $0.1 > ref }
            .min { $0.1 < $1.1 }?
            .0

        // Prochain Chabbat : allumage (vendredi), havdala + parasha (samedi).
        let friday = nextWeekday(.friday, onOrAfter: ref)
        let saturday = nextWeekday(.saturday, onOrAfter: ref)
        let candle = CandleEngine.candleLighting(
            date: friday, geo: geo, candle: settings.candle, cityMinutes: city.candleMinutes
        )
        let havdalah = CandleEngine.havdalah(date: saturday, geo: geo, tzeit: settings.tzeit)
        let weekParasha = CalendarEngine.parasha(week: saturday, region: region)

        // La carte Chabbat n'a de sens que si l'allumage est calculable (non-nil
        // hors latitudes polaires).
        let shabbat: ShabbatModel? = candle.map { c in
            ShabbatModel(
                parashaName: localizedParasha(weekParasha),
                candleLighting: c,
                havdalah: havdalah
            )
        }

        // Jeûne actif : un jeûne du jour dont la fin n'est pas encore passée.
        let activeFast: FastTiming? = todayCal.events
            .compactMap { $0.fast }
            .first { ft in
                guard let end = ft.end else { return false }
                return ref <= end
            }

        return TodayModel(
            city: city,
            hebrew: hebrew,
            gregorian: ref,
            omer: todayCal.omer,
            events: events,
            shabbat: shabbat,
            homeZmanim: homeZmanim,
            keyZmanKey: keyZmanKey,
            parasha: weekParasha,
            dafYomi: todayCal.dafYomi,
            activeFast: activeFast
        )
    }

    /// Zmanim complets d'une date arbitraire (page ville détaillée, widgets).
    func zmanim(date: Date) -> ZmanimResult {
        ZmanimEngine.zmanim(date: date, geo: geo, settings: settings)
    }

    /// Jours d'un mois calendaire, décalé de `monthOffset` par rapport au mois
    /// courant (négatif = passé, positif = futur). Le mois est borné dans le
    /// fuseau de la ville active (le DST est piloté par l'IANA de la ville).
    func calendar(monthOffset: Int) -> [CalendarDay] {
        let cal = civilCalendar
        let base = cal.date(byAdding: .month, value: monthOffset, to: now) ?? now
        var comps = cal.dateComponents([.year, .month], from: base)
        comps.day = 1
        guard let start = cal.date(from: comps) else { return [] }
        let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
        return CalendarEngine.range(
            start: start, end: end, geo: geo, region: effectiveRegion, lang: lang
        )
    }

    /// Prochaines occurrences (grég + héb) d'un yahrzeit / anniversaire, à partir
    /// d'aujourd'hui. Règles Cheshvan-30 / Kislev-30 / Adar gérées par le moteur.
    func occurrences(_ p: PersonRecord) -> [Occurrence] {
        PersonalEngine.occurrences(of: p, from: now, count: 5, geo: geo, lang: lang)
    }

    // MARK: - Mutations

    /// Ajoute un proche au carnet (dédupliqué par id), persiste, replanifie.
    func addPerson(_ p: PersonRecord) {
        if let idx = family.firstIndex(where: { $0.id == p.id }) {
            family[idx] = p
        } else {
            family.append(p)
        }
        rescheduleNotifications()
    }

    /// Retire un proche par id, persiste, replanifie.
    func removePerson(id: String) {
        family.removeAll { $0.id == id }
        rescheduleNotifications()
    }

    /// Remplace les préférences : persiste (via `didSet`), recalcule les dérivés
    /// (synchrones) et replanifie les notifications avec la nouvelle langue/ville.
    func update(settings: Settings) {
        self.settings = settings
        rescheduleNotifications()
    }

    // MARK: - Notifications (fenêtre glissante, locale)

    private func rescheduleNotifications() {
        NotificationScheduler.reschedule(
            settings: settings, family: family, geo: geo, lang: lang
        )
    }

    // MARK: - Helpers date (fuseau de la ville → DST correct)

    /// Calendrier grégorien caler sur le fuseau IANA de la ville active. Le DST
    /// est piloté par l'identifiant IANA (NATIVE_SPEC §3.4), pas par l'offset
    /// fixe de l'appareil.
    private var civilCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: geo.timeZone) ?? .current
        return cal
    }

    /// Jour de semaine grégorien (1 = dimanche … 7 = samedi), aligné sur
    /// `Calendar.component(.weekday:)` d'Apple.
    private enum Weekday: Int {
        case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    }

    /// Prochaine occurrence de `weekday` à partir de `date` (incluse si `date`
    /// tombe déjà ce jour-là), au début de journée dans le fuseau de la ville.
    private func nextWeekday(_ weekday: Weekday, onOrAfter date: Date) -> Date {
        let cal = civilCalendar
        let startToday = cal.startOfDay(for: date)
        let current = cal.component(.weekday, from: startToday)
        let delta = (weekday.rawValue - current + 7) % 7
        return cal.date(byAdding: .day, value: delta, to: startToday) ?? startToday
    }

    /// Construit un `LocalizedText` (he/fr/en) à partir d'une `ParashaInfo`
    /// (dont `name` n'est que en/he). Le français retombe sur l'anglais — les
    /// noms de parasha ne sont pas traduits en FR par la lib (hebcal en/he only).
    private func localizedParasha(_ p: ParashaInfo?) -> LocalizedText {
        guard let p else { return LocalizedText(he: "", fr: "", en: "") }
        return LocalizedText(he: p.name.he, fr: p.name.en, en: p.name.en)
    }
}
