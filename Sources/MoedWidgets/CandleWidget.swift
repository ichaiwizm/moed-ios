//
//  CandleWidget.swift
//  MoedWidgets — extension WidgetKit
//
//  Widget « Allumage » : heure d'allumage du prochain Chabbat + compte à rebours
//  live + nom de la parasha (DESIGN §11.1). Familles : `.systemSmall`,
//  `.systemMedium` et Lock Screen `.accessoryRectangular` (iOS 16+).
//
//  DA : fond parchment gradient (JAMAIS de verre — DESIGN §11/§12), UNE flamme
//  `ner`. Heure en Display tabular ; compte à rebours via `Text(style:.timer)`
//  (mise à jour système). Chiffres toujours forcés LTR (RTL hébreu géré).
//

import WidgetKit
import SwiftUI

struct CandleWidget: Widget {
    static let kind = "com.wizycode.moed.widget.candle"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CandleProvider()) { entry in
            CandleWidgetView(entry: entry)
        }
        .configurationDisplayName("Moed — Allumage")
        .description("Allumage du prochain Chabbat et compte à rebours.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Vue racine (dispatch par famille)

struct CandleWidgetView: View {
    var entry: CandleEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                CandleLockScreenView(entry: entry)
            case .systemMedium:
                CandleMediumView(entry: entry)
            default:
                CandleSmallView(entry: entry)
            }
        }
        .moedWidgetContainer(family: family)   // fond parchemin (home) / rien (lock)
        .environment(\.layoutDirection, entry.snapshot.lang.dir)
    }
}

// MARK: - Petit (home screen)

private struct CandleSmallView: View {
    let entry: CandleEntry
    private var s: CandleSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(WidgetPalette.ner)      // flamme non directionnelle : pas de miroir
                Text(WidgetStrings.nextShabbat(s.lang))
                    .font(WidgetFont.caption(s.lang))
                    .textCase(.uppercase)
                    .foregroundStyle(WidgetPalette.inkMute)
                    .widgetHebrewBalanced(s.lang)
            }

            Spacer(minLength: 0)

            CandleTime(snapshot: s, timeSize: 30)
            CandleCountdown(snapshot: s, referenceDate: entry.date)

            Spacer(minLength: 0)

            if !parasha.isEmpty {
                Text(parasha)
                    .font(WidgetFont.label(s.lang))
                    .foregroundStyle(WidgetPalette.twilight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetHebrewBalanced(s.lang)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var parasha: String { s.parashaName(s.lang) }
}

// MARK: - Medium (home screen)

private struct CandleMediumView: View {
    let entry: CandleEntry
    private var s: CandleSnapshot { entry.snapshot }

    var body: some View {
        HStack(spacing: 16) {
            // Colonne gauche : contexte
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(WidgetPalette.ner)
                    Text(WidgetStrings.nextShabbat(s.lang))
                        .font(WidgetFont.title(s.lang, size: 16))
                        .foregroundStyle(WidgetPalette.ink)
                        .widgetHebrewBalanced(s.lang)
                }
                Text(s.cityName(s.lang))
                    .font(WidgetFont.label(s.lang))
                    .foregroundStyle(WidgetPalette.inkMute)
                    .widgetHebrewBalanced(s.lang)

                Spacer(minLength: 0)

                if !s.parashaName(s.lang).isEmpty {
                    Text(s.parashaName(s.lang))
                        .font(WidgetFont.labelEmph(s.lang))
                        .foregroundStyle(WidgetPalette.twilight)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .widgetHebrewBalanced(s.lang)
                }
            }

            Spacer(minLength: 0)

            // Colonne droite : allumage + havdala
            VStack(alignment: .trailing, spacing: 6) {
                CandleTime(snapshot: s, timeSize: 34)
                CandleCountdown(snapshot: s, referenceDate: entry.date)

                if let havdalah = s.havdalah {
                    HStack(spacing: 4) {
                        Text(WidgetStrings.havdala(s.lang))
                            .font(WidgetFont.caption(s.lang))
                            .foregroundStyle(WidgetPalette.inkMute)
                            .widgetHebrewBalanced(s.lang)
                        WidgetLTR {
                            Text(WidgetFormat.time(havdalah, timeZone: s.timeZone, lang: s.lang))
                                .font(WidgetFont.caption(s.lang, size: 12).monospacedDigit())
                                .foregroundStyle(WidgetPalette.inkSoft)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lock Screen (accessoryRectangular)

private struct CandleLockScreenView: View {
    let entry: CandleEntry
    private var s: CandleSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text(WidgetStrings.nextShabbat(s.lang))
                    .font(.headline)
                    .widgetHebrewBalanced(s.lang)
            }
            .widgetAccentable()                       // teinté par le rendu .accented

            if let candle = s.candleLighting {
                WidgetLTR {
                    HStack(spacing: 4) {
                        Text(WidgetFormat.time(candle, timeZone: s.timeZone, lang: s.lang))
                            .font(.title3.monospacedDigit())
                        if candle > entry.date {
                            Text(candle, style: .timer)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text(WidgetStrings.unavailable(s.lang)).font(.title3)
            }

            if !s.parashaName(s.lang).isEmpty {
                Text(s.parashaName(s.lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .widgetHebrewBalanced(s.lang)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Sous-vues partagées

/// Heure d'allumage en Display tabular (ou « — » aux latitudes extrêmes).
private struct CandleTime: View {
    let snapshot: CandleSnapshot
    var timeSize: CGFloat

    var body: some View {
        if let candle = snapshot.candleLighting {
            WidgetLTR {
                Text(WidgetFormat.time(candle, timeZone: snapshot.timeZone, lang: snapshot.lang))
                    .font(WidgetFont.time(snapshot.lang, size: timeSize))
                    .foregroundStyle(WidgetPalette.nerStrong)
            }
        } else {
            Text(WidgetStrings.unavailable(snapshot.lang))
                .font(WidgetFont.time(snapshot.lang, size: timeSize))
                .foregroundStyle(WidgetPalette.inkMute)
        }
    }
}

/// « Allumage dans HH:MM:SS » (compte à rebours live) quand l'allumage est à
/// venir ; sinon rien (l'heure fixe suffit).
private struct CandleCountdown: View {
    let snapshot: CandleSnapshot
    let referenceDate: Date

    var body: some View {
        if let candle = snapshot.candleLighting, candle > referenceDate {
            HStack(spacing: 4) {
                Text(WidgetStrings.candleInPrefix(snapshot.lang))
                    .font(WidgetFont.caption(snapshot.lang))
                    .foregroundStyle(WidgetPalette.inkMute)
                    .widgetHebrewBalanced(snapshot.lang)
                WidgetLTR {
                    Text(candle, style: .timer)
                        .font(WidgetFont.caption(snapshot.lang, size: 12).monospacedDigit())
                        .foregroundStyle(WidgetPalette.ner)
                }
            }
        }
    }
}
