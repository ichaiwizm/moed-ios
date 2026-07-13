//
//  OmerWidget.swift
//  MoedWidgets — extension WidgetKit
//
//  Widget « Omer » : « Jour N » du compte du Omer, grand chiffre Display en
//  `sage` (DESIGN §11.3). Familles : `.systemSmall` + Lock Screen
//  (`.accessoryCircular` jauge N/49, `.accessoryRectangular`). Hors période :
//  état neutre « pas de Omer aujourd'hui ». RTL hébreu géré (lettres hébraïques).
//

import WidgetKit
import SwiftUI

struct OmerWidget: Widget {
    static let kind = "com.wizycode.moed.widget.omer"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: OmerProvider()) { entry in
            OmerWidgetView(entry: entry)
        }
        .configurationDisplayName("Moed — Omer")
        .description("Le compte du Omer du jour.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Vue racine (dispatch par famille)

struct OmerWidgetView: View {
    var entry: OmerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                OmerCircularView(snapshot: entry.snapshot)
            case .accessoryRectangular:
                OmerRectangularView(snapshot: entry.snapshot)
            default:
                OmerSmallView(snapshot: entry.snapshot)
            }
        }
        .moedWidgetContainer(family: family)
        .environment(\.layoutDirection, entry.snapshot.lang.dir)
    }
}

// MARK: - Petit (home screen)

private struct OmerSmallView: View {
    let snapshot: OmerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")           // motif non directionnel
                    .font(.system(size: 13))
                    .foregroundStyle(WidgetPalette.sage)
                Text(WidgetStrings.omerTitle(snapshot.lang))
                    .font(WidgetFont.caption(snapshot.lang))
                    .textCase(.uppercase)
                    .foregroundStyle(WidgetPalette.inkMute)
                    .widgetHebrewBalanced(snapshot.lang)
            }

            Spacer(minLength: 0)

            if let day = snapshot.day {
                WidgetLTR {
                    Text("\(day)")
                        .font(WidgetFont.hero(snapshot.lang, size: 52))
                        .foregroundStyle(WidgetPalette.sage)
                }
                Text(dayLabel(day))
                    .font(WidgetFont.label(snapshot.lang))
                    .foregroundStyle(WidgetPalette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetHebrewBalanced(snapshot.lang)
            } else {
                Text(WidgetStrings.omerNone(snapshot.lang))
                    .font(WidgetFont.label(snapshot.lang))
                    .foregroundStyle(WidgetPalette.inkMute)
                    .widgetHebrewBalanced(snapshot.lang)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// « jour du Omer » ; en hébreu on préfixe le jour en lettres (ex. « ל״ג »).
    private func dayLabel(_ day: Int) -> String {
        if snapshot.lang == .he {
            return "\(snapshot.hebrewDay) \(WidgetStrings.omerDayLabel(snapshot.lang))"
        }
        return WidgetStrings.omerDayLabel(snapshot.lang)
    }
}

// MARK: - Lock Screen circulaire (jauge N / 49)

private struct OmerCircularView: View {
    let snapshot: OmerSnapshot

    var body: some View {
        if let day = snapshot.day {
            Gauge(value: Double(day), in: 1...49) {
                Text(WidgetStrings.omerTitle(snapshot.lang))
            } currentValueLabel: {
                WidgetLTR { Text("\(day)").monospacedDigit() }
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        } else {
            // Hors période : glyphe discret.
            Image(systemName: "leaf")
                .font(.title3)
                .widgetAccentable()
        }
    }
}

// MARK: - Lock Screen rectangulaire

private struct OmerRectangularView: View {
    let snapshot: OmerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(WidgetStrings.omerTitle(snapshot.lang))
                .font(.caption2)
                .textCase(.uppercase)
                .widgetAccentable()
                .widgetHebrewBalanced(snapshot.lang)

            if let day = snapshot.day {
                WidgetLTR {
                    HStack(spacing: 6) {
                        Text("\(day)")
                            .font(.title.monospacedDigit())
                        if snapshot.lang == .he {
                            Text(snapshot.hebrewDay).font(.body)
                        }
                    }
                }
                Text(WidgetStrings.omerDayLabel(snapshot.lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .widgetHebrewBalanced(snapshot.lang)
            } else {
                Text(WidgetStrings.omerNone(snapshot.lang))
                    .font(.body)
                    .widgetHebrewBalanced(snapshot.lang)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
