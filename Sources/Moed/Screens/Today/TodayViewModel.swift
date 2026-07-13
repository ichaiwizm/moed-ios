//
//  TodayViewModel.swift
//  Moed — Écran « Aujourd'hui »
//
//  ViewModel LÉGER (CONTRACTS §4.3) : il NE recalcule RIEN. Il consomme
//  `AppState.today() -> TodayModel` et n'expose que du *formatage localisé*
//  et de la *mise en forme d'affichage* déterministe et offline :
//    • heures HH:MM (fuseau IANA de la ville — jamais l'offset device),
//    • date hébraïque / grégorienne dans la langue active (tables maison),
//    • compte à rebours d'allumage (tabular, LTR),
//    • mapping ZmanKey → libellé i18n + symbole SF,
//    • badges d'en-tête (Omer / fête / Roch Hodech).
//
//  Aucune Date n'est arrondie ici ; on lit les instants absolus du moteur.
//  Un zman absent (latitude extrême) reste `nil` → affiché « — », jamais NaN.
//

import Foundation

@MainActor
struct TodayViewModel {

    // MARK: - Modèles d'affichage (dérivés, pas de recalcul moteur)

    /// Une ligne de zman prête à peindre par la vue.
    struct ZmanDisplay: Identifiable, Equatable {
        let id: String          // ZmanKey.rawValue
        let symbol: String      // SF Symbol (icône non directionnelle)
        let labelKey: String    // clé L10n (section "zmanim")
        let time: String        // "18:42" ou "—"
        let shita: String       // TOUJOURS affichée (transparence halakhique)
        let isKey: Bool         // le zman clé surligné (un seul par liste)
        let available: Bool     // false → « — » + tooltip côté vue
    }

    enum BadgeKind: Equatable { case omer, holiday, roshchodesh }

    struct BadgeDisplay: Identifiable, Equatable {
        let id: String
        let kind: BadgeKind
        let text: String
        let symbol: String
    }

    // MARK: - Catalogue d'affichage HOME (parité DESIGN §5.1 / ZmanCatalog.home)

    /// Métadonnées de présentation figées par clé de zman.
    private static let meta: [String: (symbol: String, labelKey: String)] = [
        ZmanKey.hanetzHachama.rawValue:    ("sunrise.fill",    "zmanim.sunrise"),
        ZmanKey.sofZmanShmaGRA.rawValue:   ("book.closed.fill","zmanim.sofShmaGRA"),
        ZmanKey.chatzot.rawValue:          ("sun.max.fill",    "zmanim.chatzot"),
        ZmanKey.minchaGedola.rawValue:     ("sun.min.fill",    "zmanim.minchaGedola"),
        ZmanKey.shkiaHachama.rawValue:     ("sunset.fill",     "zmanim.sunset"),
        ZmanKey.tzeitHakochavim.rawValue:  ("moon.stars.fill", "zmanim.tzeit"),
    ]

    // MARK: - Formateurs (mémoïsés — main thread only, coût nul)

    private static var timeCache: [String: DateFormatter] = [:]
    private static var gregCache: [String: DateFormatter] = [:]

    private static func timeFormatter(tz: String, lang: Lang) -> DateFormatter {
        let key = "\(tz)|\(lang.bcp47)"
        if let f = timeCache[key] { return f }
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.bcp47)
        f.timeZone = TimeZone(identifier: tz) ?? TimeZone(secondsFromGMT: 0)!
        f.dateFormat = "HH:mm"
        timeCache[key] = f
        return f
    }

    private static func gregorianFormatter(tz: String, lang: Lang) -> DateFormatter {
        let key = "\(tz)|\(lang.bcp47)"
        if let f = gregCache[key] { return f }
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.bcp47)
        f.timeZone = TimeZone(identifier: tz) ?? TimeZone(secondsFromGMT: 0)!
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMMyyyy")
        gregCache[key] = f
        return f
    }

    // MARK: - Heures

    /// "18:42" dans le fuseau de la ville, ou « — » si le zman est absent (nil).
    func time(_ date: Date?, tz: String, lang: Lang) -> String {
        guard let date else { return "—" }
        return Self.timeFormatter(tz: tz, lang: lang).string(from: date)
    }

    /// Date grégorienne complète, localisée, première lettre capitalisée.
    func gregorian(_ date: Date, tz: String, lang: Lang) -> String {
        let raw = Self.gregorianFormatter(tz: tz, lang: lang).string(from: date)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    /// Date hébraïque dans la langue active.
    /// he → « ט״ו שבט תשפ״ה » (lettres hébraïques, RTL) ;
    /// fr/en → « 15 Shevat 5785 » (chiffres latins + nom translittéré).
    func hebrew(_ h: HebrewDateResult, lang: Lang) -> String {
        switch lang {
        case .he:
            return "\(h.dayHebrew) \(h.monthName(.he)) \(h.yearHebrew)"
        case .fr, .en:
            return "\(h.day) \(h.monthName(lang)) \(h.year)"
        }
    }

    // MARK: - Compte à rebours d'allumage (tabular, mis à jour chaque seconde)

    /// Secondes restantes (≥ 0) jusqu'à `target`.
    func remaining(to target: Date, now: Date) -> TimeInterval {
        max(0, target.timeIntervalSince(now))
    }

    /// « 2:14:07 » (≥ 1 h) ou « 14:07 » (< 1 h). Toujours en chiffres tabular,
    /// la vue l'enveloppe dans `ForceLTR` pour rester lisible en hébreu.
    func countdown(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    /// Version « minute » throttlée pour VoiceOver (pas d'annonce à la seconde).
    func countdownCoarse(_ interval: TimeInterval, lang: Lang) -> String {
        let total = Int(interval.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h) h \(m) min" }
        return "\(m) min"
    }

    // MARK: - Zmanim HOME

    /// Transforme `TodayModel.homeZmanim` en lignes d'affichage prêtes à peindre.
    func zmanRows(_ model: TodayModel, lang: Lang) -> [ZmanDisplay] {
        let tz = model.city.tz
        let keyRaw = model.keyZmanKey?.rawValue
        return model.homeZmanim.map { z in
            let m = Self.meta[z.key] ?? ("clock.fill", "zmanim." + z.key)
            return ZmanDisplay(
                id: z.key,
                symbol: m.symbol,
                labelKey: m.labelKey,
                time: time(z.date, tz: tz, lang: lang),
                shita: z.shita,
                isKey: z.key == keyRaw,
                available: z.date != nil
            )
        }
    }

    /// Shita du tzeit (pour le disclaimer halakhique) — fallback « 8.5° ».
    func tzeitShita(_ model: TodayModel) -> String {
        model.homeZmanim.first { $0.key == ZmanKey.tzeitHakochavim.rawValue }?.shita ?? "8.5°"
    }

    // MARK: - Badges d'en-tête (Omer / fête / Roch Hodech), max 3

    func badges(_ model: TodayModel, lang: Lang) -> [BadgeDisplay] {
        var out: [BadgeDisplay] = []

        if let omer = model.omer {
            out.append(BadgeDisplay(
                id: "omer",
                kind: .omer,
                text: L10n.t("home.omerDay", lang, ["n": omer]),
                symbol: "leaf.fill"
            ))
        }

        for e in model.events {
            switch e.category {
            case .yomtov, .holiday:
                out.append(BadgeDisplay(
                    id: e.desc,
                    kind: .holiday,
                    text: e.title(lang),
                    symbol: "flame.fill"
                ))
            case .roshchodesh:
                out.append(BadgeDisplay(
                    id: e.desc,
                    kind: .roshchodesh,
                    text: e.title(lang),
                    symbol: "moon.fill"
                ))
            default:
                break
            }
        }

        return Array(out.prefix(3))
    }

    // MARK: - Parasha / Daf Yomi (ParashaInfo/DafYomiInfo ne fournissent que en/he)

    func parashaName(_ p: ParashaInfo, lang: Lang) -> String {
        lang == .he ? p.name.he : p.name.en
    }

    func dafName(_ d: DafYomiInfo, lang: Lang) -> String {
        lang == .he ? d.render.he : d.render.en
    }

    // MARK: - État de jeûne

    /// Libellé du jeûne actif (via l'événement `.fast` s'il existe), sinon « Jeûne ».
    func fastTitle(_ model: TodayModel, lang: Lang) -> String {
        if let ev = model.events.first(where: { $0.category == .fast }) {
            return ev.title(lang)
        }
        return L10n.t("calendar.fast", lang)
    }
}
