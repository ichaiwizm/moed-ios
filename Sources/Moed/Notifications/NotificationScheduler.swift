//
//  NotificationScheduler.swift
//  Moed — MODULE « Notifications » (CONTRACTS.md §4.4, SPEC §9, PLAN §8)
//
//  Rappels 100 % LOCAUX, planifiés à l'avance, ZÉRO serveur.
//  ------------------------------------------------------------------------
//  Toutes les échéances de Moed sont DÉTERMINISTES et calculables offline
//  (allumage du Chabbat, Omer, hiloula, yahrzeit, fêtes/jeûnes). On n'a donc
//  besoin d'aucun push VAPID : chaque occurrence future est convertie en un
//  `UNCalendarNotificationTrigger` daté, planifié dans `UNUserNotificationCenter`.
//
//  Stratégie « fenêtre glissante » (SPEC §9 / PLAN §8) :
//    • On planifie les N prochaines occurrences de chaque type (fenêtre bornée).
//    • La fenêtre est RE-REMPLIE à chaque ouverture de l'app (AppState) et par
//      `BackgroundRefresh` (BGTaskScheduler) — voir BackgroundRefresh.swift.
//    • iOS plafonne à 64 notifications EN ATTENTE par app : on respecte un
//      budget strict (`Budget`) largement sous cette limite, avec des quotas
//      par catégorie pour qu'aucune (ex. les 49 jours du Omer) n'affame les
//      autres, puis un plafond global par ordre chronologique.
//
//  Contenu LOCALISÉ dans la langue active (`lang`) via `L10n` — indépendant de
//  la langue système. RTL hébreu : le texte hébreu impose naturellement une
//  base RTL (premier caractère fort) ; les HEURES sont isolées en LTR
//  (U+2066…U+2069) pour ne pas être disloquées par l'algorithme bidi.
//
//  Détermination halakhique CORRECTE (offline, déterministe) :
//    • Allumage : `day.candleLighting != nil` (le CalendarEngine décide QUELS
//      jours ont un allumage — Chabbat + Yom Tov, en tenant compte de la région
//      Israël/Diaspora, 2ᵉ jour de fête en 'houts la'aretz), puis l'HEURE exacte
//      est recalculée par `CandleEngine` pour respecter le minhag d'allumage
//      (18/20/30/40 min) de l'utilisateur — repli sur l'heure du calendrier.
//    • Omer : le compte se fait LA NUIT. Le rappel du jour N est donc planifié
//      le soir qui INAUGURE la date hébraïque du jour N — c.-à-d. à la tombée de
//      la nuit (tzeit) de la veille civile du `CalendarDay` dont `omer == N`.
//    • Jeûnes : rappel à l'heure de début dérivée des zmanim (`FastTiming.start`).
//    • Yahrzeit : occurrences issues de `PersonalEngine` (règles Cheshvan-30 /
//      Kislev-30 / Adar en année embolismique gérées par le moteur).
//
//  Note « Liquid Glass / .glassEffect » : purement UI (DesignSystem/
//  GlassBackground.swift). Ce module est SANS interface (planificateur headless)
//  — aucun rendu de verre ne s'y applique. La seule surface visible produite ici
//  est la bannière système iOS, dont l'apparence n'est pas contrôlable par l'app.
//
//  Dépendances : Engine (CalendarEngine, CandleEngine, ZmanimEngine,
//  PersonalEngine), Data (StaticData, City), Store (Settings, PersonRecord),
//  i18n (L10n). Aucune dépendance réseau.
//

import Foundation
import UserNotifications

/// Planificateur de notifications locales. `enum` sans cas : espace de noms pur.
public enum NotificationScheduler {

    // MARK: - Budget de la fenêtre glissante
    //
    // Somme des quotas = 54 ≤ `maxTotal` (60) ≤ 64 (plafond iOS). On garde une
    // marge sous 64 pour ne jamais voir iOS rejeter silencieusement des rappels.

    private enum Budget {
        /// Profondeur d'énumération du calendrier hébraïque (jours).
        static let calendarWindowDays = 45
        /// Quotas par catégorie (occurrences les plus proches conservées).
        static let candle = 6
        static let fast = 6
        static let omer = 24
        static let hilula = 6
        static let person = 12
        /// Occurrences planifiées par proche (yahrzeit / anniversaire).
        static let perPersonOccurrences = 2
        /// Plafond global (marge sous la limite dure de 64 d'iOS).
        static let maxTotal = 60

        /// Avance du rappel d'allumage avant l'heure d'allumage (minutes).
        static let candleLeadMinutes = 30
        /// Heure locale (murale) du rappel de yahrzeit / anniversaire.
        static let personHour = 8
        /// Heure locale du rappel de hiloula.
        static let hilulaHour = 8
        /// Repli du rappel du Omer si le tzeit est indisponible (latitude extrême).
        static let omerFallbackHour = 21
    }

    /// Préfixe commun à TOUS les identifiants de requêtes Moed — permet de ne
    /// purger que nos rappels (jamais ceux d'autres sous-systèmes futurs).
    private static let idPrefix = "moed."

    /// Clé `userInfo` transportant le type de rappel (deep-linking éventuel).
    private static let typeKey = "moedType"

    // MARK: - API publique

    /// Replanifie l'intégralité de la fenêtre glissante à partir de l'état courant.
    ///
    /// Non bloquant : le travail (asynchrone, sérialisé) est délégué à un `Task`.
    /// Appelée par `AppState` à l'ouverture, au changement de réglages, et à
    /// l'ajout/suppression d'un proche (CONTRACTS §4.2).
    ///
    /// Contrat GELÉ (CONTRACTS §4.4) :
    /// `reschedule(settings:family:geo:lang:)`.
    public static func reschedule(settings: Settings, family: [PersonRecord], geo: GeoContext, lang: Lang) {
        Task {
            _ = await Coordinator.shared.run {
                await apply(settings: settings, family: family, geo: geo, lang: lang)
            }
        }
    }

    /// Demande l'autorisation système. À appeler AU MOMENT DE L'OPT-IN (bascule
    /// d'un toggle de notification dans Réglages), jamais au lancement (SPEC §9).
    /// - Returns: `true` si l'utilisateur a accordé alerte + son.
    @discardableResult
    public static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Variante attendable, utilisée par `BackgroundRefresh` pour clôturer sa
    /// tâche BGTask une fois la fenêtre re-remplie.
    /// - Returns: nombre de rappels effectivement planifiés.
    @discardableResult
    static func rescheduleAndWait(settings: Settings, family: [PersonRecord], geo: GeoContext, lang: Lang) async -> Int {
        await Coordinator.shared.run {
            await apply(settings: settings, family: family, geo: geo, lang: lang)
        }
    }

    /// Purge tous les rappels Moed en attente (ex. l'utilisateur coupe tout).
    public static func cancelAll() {
        Task { await Coordinator.shared.run { await removeAllMoed(); return 0 } }
    }

    // MARK: - Sérialisation

    /// Sérialise les replanifications : `removeAll` puis `add` ne doivent jamais
    /// s'entrelacer entre deux appels concurrents (double changement de réglage,
    /// ouverture + BGTask simultanés). Un `actor` garantit l'exclusion mutuelle.
    private actor Coordinator {
        static let shared = Coordinator()
        func run(_ body: @Sendable () async -> Int) async -> Int { await body() }
    }

    // MARK: - Cœur : construction + application

    /// Construit la fenêtre glissante et l'installe dans le centre de notifications.
    private static func apply(settings: Settings, family: [PersonRecord], geo: GeoContext, lang: Lang) async -> Int {
        let center = UNUserNotificationCenter.current()

        // 1. Ne rien planifier si non autorisé — mais purger l'existant (l'utilisateur
        //    a pu révoquer l'autorisation dans Réglages iOS).
        let auth = await center.notificationSettings()
        guard auth.authorizationStatus == .authorized || auth.authorizationStatus == .provisional else {
            await removeAllMoed()
            return 0
        }

        // 2. Rien d'activé → purge et sortie.
        let prefs = settings.notif
        guard prefs.shabbat || prefs.omer || prefs.hilula || prefs.yahrzeit else {
            await removeAllMoed()
            return 0
        }

        let now = Date()
        let tz = TimeZone(identifier: geo.timeZone) ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let city = StaticData.city(slug: settings.citySlug)

        // 3. Énumération unique du calendrier hébraïque sur la fenêtre.
        let end = cal.date(byAdding: .day, value: Budget.calendarWindowDays, to: now) ?? now
        let days = CalendarEngine.range(start: now, end: end, geo: geo, region: settings.region, lang: lang)

        var planned: [Planned] = []

        // 4. Allumage Chabbat / Yom Tov (canal « calendrier » = toggle shabbat).
        if prefs.shabbat {
            planned += candleReminders(days: days, city: city, settings: settings, geo: geo, lang: lang, now: now, cal: cal, tz: tz)
            planned += fastReminders(days: days, lang: lang, now: now, cal: cal, tz: tz)
        }
        // 5. Omer quotidien (49 j), fenêtré.
        if prefs.omer {
            planned += omerReminders(days: days, settings: settings, geo: geo, lang: lang, now: now, cal: cal, tz: tz)
        }
        // 6. Hiloula du jour.
        if prefs.hilula {
            planned += hilulaReminders(days: days, lang: lang, now: now, cal: cal, tz: tz)
        }
        // 7. Yahrzeit + anniversaire hébraïque (canal « personnel » = toggle yahrzeit).
        if prefs.yahrzeit {
            planned += personReminders(family: family, geo: geo, lang: lang, now: now, cal: cal, tz: tz)
        }

        // 8. Plafond global chronologique (les plus proches d'abord).
        let selected = planned
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(Budget.maxTotal)

        // 9. Remplacement atomique : purge des rappels Moed puis (ré)ajout.
        await removeAllMoed()
        for item in selected {
            let request = item.request(tz: tz)
            try? await center.add(request)
        }
        return selected.count
    }

    /// Supprime uniquement les requêtes en attente appartenant à Moed.
    private static func removeAllMoed() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Générateurs par catégorie

    /// Allumage du Chabbat / Yom Tov. On se fie au calendrier pour savoir QUELS
    /// jours ont un allumage (région-conscient), et à `CandleEngine` pour l'HEURE
    /// exacte respectant le minhag d'allumage de l'utilisateur.
    private static func candleReminders(
        days: [CalendarDay], city: City, settings: Settings, geo: GeoContext,
        lang: Lang, now: Date, cal: Calendar, tz: TimeZone
    ) -> [Planned] {
        var out: [Planned] = []
        for day in days where day.candleLighting != nil {
            // Heure précise selon le minhag ; repli sur l'heure du calendrier.
            let candle = CandleEngine.candleLighting(
                date: day.date, geo: geo, candle: settings.candle, cityMinutes: city.candleMinutes
            ) ?? day.candleLighting
            guard let lighting = candle else { continue }

            // Le rappel se déclenche `candleLeadMinutes` AVANT l'allumage.
            let lead = cal.date(byAdding: .minute, value: -Budget.candleLeadMinutes, to: lighting) ?? lighting
            let fire = lead > now ? lead : lighting
            guard fire > now else { continue }

            let time = ltr(timeString(lighting, lang: lang, tz: tz))
            // Yom Tov nommé si présent, sinon Chabbat.
            let yomTov = day.events.first { $0.isYomTov || $0.category == .yomtov || $0.category == .holiday }
            let title: String
            let body: String
            if let yt = yomTov {
                title = L10n.t("notif.yomtov.title", lang, ["name": yt.title(lang)])
                body = L10n.t("notif.yomtov.body", lang, ["time": time])
            } else {
                title = L10n.t("notif.shabbat.title", lang)
                body = L10n.t("notif.shabbat.body", lang, ["time": time])
            }
            out.append(Planned(
                id: idPrefix + "candle." + dayKey(day.date, cal: cal),
                type: "shabbat", fireDate: fire, title: title, body: body
            ))
            if out.count >= Budget.candle { break }
        }
        return Array(out.prefix(Budget.candle))
    }

    /// Jeûnes à venir : rappel à l'heure de début (dérivée des zmanim par le moteur).
    private static func fastReminders(
        days: [CalendarDay], lang: Lang, now: Date, cal: Calendar, tz: TimeZone
    ) -> [Planned] {
        var out: [Planned] = []
        for day in days {
            for event in day.events where event.category == .fast {
                guard let start = event.fast?.start, start > now else { continue }
                let time = ltr(timeString(start, lang: lang, tz: tz))
                out.append(Planned(
                    id: idPrefix + "fast." + slug(event.desc),
                    type: "holiday", fireDate: start,
                    title: L10n.t("notif.fast.title", lang, ["name": event.title(lang)]),
                    body: L10n.t("notif.fast.body", lang, ["time": time])
                ))
            }
            if out.count >= Budget.fast { break }
        }
        return Array(out.prefix(Budget.fast))
    }

    /// Omer quotidien. Le compte se fait la NUIT : le rappel du jour N est planifié
    /// à la tombée de la nuit de la VEILLE civile du `CalendarDay` porteur de `omer`.
    private static func omerReminders(
        days: [CalendarDay], settings: Settings, geo: GeoContext,
        lang: Lang, now: Date, cal: Calendar, tz: TimeZone
    ) -> [Planned] {
        var out: [Planned] = []
        for day in days {
            guard let omer = day.omer else { continue }
            // Soir qui inaugure la date hébraïque du jour N = veille civile.
            let eve = cal.date(byAdding: .day, value: -1, to: day.date) ?? day.date
            let tzeit = ZmanimEngine.zmanim(date: eve, geo: geo, settings: settings)
                .byKey[ZmanKey.tzeitHakochavim.rawValue]?.date
            let fire = tzeit ?? wallClock(eve, hour: Budget.omerFallbackHour, minute: 0, cal: cal)
            guard let fireDate = fire, fireDate > now else { continue }

            out.append(Planned(
                id: idPrefix + "omer.\(omer)." + dayKey(eve, cal: cal),
                type: "omer", fireDate: fireDate,
                title: L10n.t("notif.omer.title", lang),
                body: L10n.t("notif.omer.body", lang, ["n": omer])
            ))
            if out.count >= Budget.omer { break }
        }
        return Array(out.prefix(Budget.omer))
    }

    /// Hiloula du jour : tsadikim dont la hiloula tombe à la date hébraïque du jour.
    /// Rappel le matin (heure murale locale).
    private static func hilulaReminders(
        days: [CalendarDay], lang: Lang, now: Date, cal: Calendar, tz: TimeZone
    ) -> [Planned] {
        var out: [Planned] = []
        for day in days {
            let tsadikim = StaticData.hilulotToday(hebrew: day.hebrew)
            guard let first = tsadikim.first else { continue }
            guard let fire = wallClock(day.date, hour: Budget.hilulaHour, minute: 0, cal: cal), fire > now else { continue }

            let name = first.names(lang)
            let body: String
            if tsadikim.count > 1 {
                body = L10n.t("notif.hilula.bodyMore", lang, ["name": name, "n": tsadikim.count - 1])
            } else {
                body = L10n.t("notif.hilula.body", lang, ["name": name])
            }
            out.append(Planned(
                id: idPrefix + "hilula." + dayKey(day.date, cal: cal),
                type: "hilula", fireDate: fire,
                title: L10n.t("notif.hilula.title", lang, ["name": name]),
                body: body
            ))
            if out.count >= Budget.hilula { break }
        }
        return Array(out.prefix(Budget.hilula))
    }

    /// Yahrzeit + anniversaire hébraïque du carnet familial. Rappel matinal ;
    /// le yahrzeit porte le rappel du Kaddish.
    private static func personReminders(
        family: [PersonRecord], geo: GeoContext, lang: Lang,
        now: Date, cal: Calendar, tz: TimeZone
    ) -> [Planned] {
        var out: [Planned] = []
        for person in family {
            let occ = PersonalEngine.occurrences(
                of: person, from: now, count: Budget.perPersonOccurrences, geo: geo, lang: lang
            )
            for occurrence in occ {
                guard let fire = wallClock(occurrence.gregorian, hour: Budget.personHour, minute: 0, cal: cal),
                      fire > now else { continue }
                let name = person.name.isEmpty ? "—" : person.name
                let title: String
                let body: String
                switch person.type {
                case .yahrzeit:
                    title = L10n.t("notif.yahrzeit.title", lang, ["name": name])
                    body = L10n.t("notif.yahrzeit.body", lang, ["name": name])
                case .birthday:
                    title = L10n.t("notif.birthday.title", lang, ["name": name])
                    body = L10n.t("notif.birthday.body", lang, ["name": name])
                }
                out.append(Planned(
                    id: idPrefix + "person.\(person.id)." + dayKey(occurrence.gregorian, cal: cal),
                    type: person.type.rawValue, fireDate: fire, title: title, body: body
                ))
            }
        }
        // Plus proches d'abord, quota global personnes.
        return Array(out.sorted { $0.fireDate < $1.fireDate }.prefix(Budget.person))
    }

    // MARK: - Modèle interne d'un rappel planifié

    /// Un rappel prêt à être matérialisé en `UNNotificationRequest`.
    /// `Sendable` : traversé par des frontières de concurrence (actor + Task).
    private struct Planned: Sendable {
        let id: String
        let type: String
        let fireDate: Date
        let title: String
        let body: String

        /// Matérialise la requête système avec un déclencheur calendaire ancré
        /// dans le fuseau de la ville (pilote le DST — SPEC §3.4).
        func request(tz: TimeZone) -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.threadIdentifier = type          // regroupement par canal
            content.userInfo = [NotificationScheduler.typeKey: type]
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .active
            }

            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            comps.timeZone = tz                       // fige le DST du lieu
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }
    }

    // MARK: - Helpers date / texte

    /// Instant d'une heure murale (`hour:minute`) au jour civil de `date`, dans le
    /// fuseau de `cal`. `nil` si la combinaison n'existe pas (bascule DST).
    private static func wallClock(_ date: Date, hour: Int, minute: Int, cal: Calendar) -> Date? {
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return cal.date(from: comps)
    }

    /// Clé de jour stable `yyyyMMdd` dans le fuseau du lieu (identifiants uniques).
    private static func dayKey(_ date: Date, cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Heure formatée courte dans la langue + le fuseau du lieu.
    private static func timeString(_ date: Date, lang: Lang, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.bcp47)
        f.timeZone = tz
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    /// Isole une sous-chaîne en LTR (LRI…PDI) : les heures/chiffres restent lisibles
    /// et alignés même enchâssés dans une phrase hébraïque RTL (SPEC §5).
    private static func ltr(_ s: String) -> String {
        "\u{2066}\(s)\u{2069}"   // LEFT-TO-RIGHT ISOLATE … POP DIRECTIONAL ISOLATE
    }

    /// Réduit un identifiant hebcal (`"Rosh Hashana"`) en fragment d'id stable.
    private static func slug(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
