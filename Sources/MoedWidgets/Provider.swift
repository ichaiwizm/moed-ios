//
//  Provider.swift
//  MoedWidgets — extension WidgetKit
//
//  Les trois `TimelineProvider` (Allumage / Zmanim / Omer). Chacun RECALCULE
//  localement via `WidgetEngine` (App Group partagé, moteurs déterministes
//  offline) — aucun réseau, aucune dépendance à l'app en cours d'exécution
//  (CONTRACTS §4.4 / DESIGN §11).
//
//  Stratégie de timeline commune :
//   • Le compte à rebours d'allumage utilise `Text(_, style: .timer)` (mise à
//     jour système, pas d'entrée par seconde).
//   • On pose des entrées AUX INSTANTS DE TRANSITION utiles seulement :
//       – Zmanim : à chaque zman qui arrive (le surlignage « prochain » avance) ;
//       – Omer   : au coucher (bascule du jour hébraïque) ;
//       – Tous   : au prochain minuit (rollover date / parasha / Omer).
//   • `.after(nextMidnight)` déclenche un rechargement quotidien garanti.
//

import WidgetKit
import SwiftUI

// MARK: - Entries

/// Entrée du widget « Allumage ».
struct CandleEntry: TimelineEntry {
    let date: Date
    let snapshot: CandleSnapshot
}

/// Entrée du widget « Zmanim du jour ».
struct ZmanimEntry: TimelineEntry {
    let date: Date
    let snapshot: ZmanimSnapshot
}

/// Entrée du widget « Omer ».
struct OmerEntry: TimelineEntry {
    let date: Date
    let snapshot: OmerSnapshot
}

// MARK: - Provider : Allumage

struct CandleProvider: TimelineProvider {

    func placeholder(in context: Context) -> CandleEntry {
        CandleEntry(date: .now, snapshot: SampleData.candle)
    }

    func getSnapshot(in context: Context, completion: @escaping (CandleEntry) -> Void) {
        let ctx = WidgetEngine.context()
        completion(CandleEntry(date: .now, snapshot: WidgetEngine.candle(for: .now, ctx)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CandleEntry>) -> Void) {
        let ctx = WidgetEngine.context()
        let now = Date.now
        let midnight = WidgetEngine.nextMidnight(after: now, ctx)

        // Instants notables : maintenant, l'allumage à venir (bascule
        // « dans X » → « à HH:MM »), puis minuit.
        var instants: [Date] = [now]
        let snap = WidgetEngine.candle(for: now, ctx)
        if let candle = snap.candleLighting, candle > now, candle < midnight {
            instants.append(candle)
        }
        instants.append(midnight)
        instants = dedupSorted(instants, upperBound: midnight)

        let entries = instants.map { CandleEntry(date: $0, snapshot: WidgetEngine.candle(for: $0, ctx)) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Provider : Zmanim

struct ZmanimProvider: TimelineProvider {

    func placeholder(in context: Context) -> ZmanimEntry {
        ZmanimEntry(date: .now, snapshot: SampleData.zmanim)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZmanimEntry) -> Void) {
        let ctx = WidgetEngine.context()
        completion(ZmanimEntry(date: .now, snapshot: WidgetEngine.zmanim(for: .now, ctx)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZmanimEntry>) -> Void) {
        let ctx = WidgetEngine.context()
        let now = Date.now
        let midnight = WidgetEngine.nextMidnight(after: now, ctx)

        // Une entrée à chaque zman à venir aujourd'hui → le surlignage
        // « prochain » se déplace pile au bon moment, plus minuit.
        var instants: [Date] = [now]
        instants.append(contentsOf: WidgetEngine.zmanTransitions(after: now, ctx))
        instants.append(midnight)
        instants = dedupSorted(instants, upperBound: midnight)

        let entries = instants.map { ZmanimEntry(date: $0, snapshot: WidgetEngine.zmanim(for: $0, ctx)) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Provider : Omer

struct OmerProvider: TimelineProvider {

    func placeholder(in context: Context) -> OmerEntry {
        OmerEntry(date: .now, snapshot: SampleData.omer)
    }

    func getSnapshot(in context: Context, completion: @escaping (OmerEntry) -> Void) {
        let ctx = WidgetEngine.context()
        completion(OmerEntry(date: .now, snapshot: WidgetEngine.omer(for: .now, ctx)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OmerEntry>) -> Void) {
        let ctx = WidgetEngine.context()
        let now = Date.now
        let midnight = WidgetEngine.nextMidnight(after: now, ctx)

        // Le compte du Omer bascule au coucher : entrée à la shkia à venir, si
        // elle tombe avant minuit, puis minuit.
        var instants: [Date] = [now]
        let transitions = WidgetEngine.zmanTransitions(after: now, ctx)
        instants.append(contentsOf: transitions)   // inclut la shkia du jour
        instants.append(midnight)
        instants = dedupSorted(instants, upperBound: midnight)

        let entries = instants.map { OmerEntry(date: $0, snapshot: WidgetEngine.omer(for: $0, ctx)) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Conteneur de fond (parchemin home / neutre lock)

extension View {
    /// Applique le fond du widget selon la famille (CONTRACTS iOS 17 :
    /// `containerBackground(for: .widget)` OBLIGATOIRE). Home screen → parchemin
    /// gradient ; Lock Screen → fond neutre (le système fournit le sien, rendu
    /// `.accented`). JAMAIS de verre (DESIGN §11/§12).
    @ViewBuilder
    func moedWidgetContainer(family: WidgetFamily) -> some View {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            self.containerBackground(for: .widget) { ParchmentBackground() }
        default:
            // Lock Screen (accessory*) : pas de fond opaque, contenu monochrome.
            self.containerBackground(for: .widget) { Color.clear }
        }
    }
}

// MARK: - Utilitaires timeline

/// Trie, déduplique et borne une liste d'instants (aucune entrée au-delà de
/// `upperBound`, qui reste toujours présent comme dernière entrée).
private func dedupSorted(_ dates: [Date], upperBound: Date) -> [Date] {
    var seen = Set<TimeInterval>()
    let filtered = dates
        .filter { $0 <= upperBound }
        .sorted()
        .filter { seen.insert($0.timeIntervalSinceReferenceDate.rounded()).inserted }
    return filtered.isEmpty ? [upperBound] : filtered
}

// MARK: - Données d'exemple (placeholders / previews)

/// Snapshots figés pour les placeholders WidgetKit et les previews Xcode.
/// Aucune donnée réseau ; valeurs plausibles pour Paris.
enum SampleData {
    private static let paris = LocalizedText(he: "פריז", fr: "Paris", en: "Paris")
    private static let tz = "Europe/Paris"

    static let candle = CandleSnapshot(
        cityName: paris, timeZone: tz, lang: Lang.fromSystem(),
        candleLighting: Date.now.addingTimeInterval(3 * 3600 + 12 * 60),
        havdalah: Date.now.addingTimeInterval(27 * 3600),
        parashaName: LocalizedText(he: "בְּרֵאשִׁית", fr: "Bereshit", en: "Bereshit"),
        reference: .now
    )

    static let zmanim = ZmanimSnapshot(
        cityName: paris, timeZone: tz, lang: Lang.fromSystem(),
        lines: [
            WidgetZmanLine(key: ZmanKey.hanetzHachama.rawValue,
                           date: Date.now.addingTimeInterval(-4 * 3600), isUpcoming: false),
            WidgetZmanLine(key: ZmanKey.chatzot.rawValue,
                           date: Date.now.addingTimeInterval(1 * 3600), isUpcoming: true),
            WidgetZmanLine(key: ZmanKey.shkiaHachama.rawValue,
                           date: Date.now.addingTimeInterval(6 * 3600), isUpcoming: false),
            WidgetZmanLine(key: ZmanKey.tzeitHakochavim.rawValue,
                           date: Date.now.addingTimeInterval(7 * 3600), isUpcoming: false),
        ],
        reference: .now
    )

    static let omer = OmerSnapshot(
        lang: Lang.fromSystem(), day: 33, hebrewDay: "ל״ג", reference: .now
    )
}
