//
//  ZmanimWidget.swift
//  MoedWidgets — extension WidgetKit
//
//  Widget « Zmanim du jour » (medium) : 4 zmanim clés en colonne tabular, le
//  PROCHAIN à venir surligné `nerWash` (DESIGN §11.2). Fond parchment gradient,
//  jamais de verre. Horaires tabular, forcés LTR (RTL hébreu géré).
//

import WidgetKit
import SwiftUI

struct ZmanimWidget: Widget {
    static let kind = "com.wizycode.moed.widget.zmanim"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ZmanimProvider()) { entry in
            ZmanimWidgetView(entry: entry)
        }
        .configurationDisplayName("Moed — Zmanim du jour")
        .description("Les zmanim clés du jour pour votre ville, le prochain surligné.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Vue

struct ZmanimWidgetView: View {
    var entry: ZmanimEntry
    private var s: ZmanimSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // En-tête : icône soleil (non directionnelle) + ville
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(WidgetPalette.ner)
                Text(s.cityName(s.lang))
                    .font(WidgetFont.title(s.lang, size: 15))
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .widgetHebrewBalanced(s.lang)
                Spacer(minLength: 0)
            }

            VStack(spacing: 4) {
                ForEach(s.lines) { line in
                    ZmanLineRow(line: line, lang: s.lang, timeZone: s.timeZone)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .moedWidgetContainer(family: .systemMedium)
        .environment(\.layoutDirection, s.lang.dir)
    }
}

// MARK: - Ligne de zman

private struct ZmanLineRow: View {
    let line: WidgetZmanLine
    let lang: Lang
    let timeZone: String

    var body: some View {
        HStack(spacing: 8) {
            Text(WidgetStrings.zmanLabel(line.key, lang))
                .font(line.isUpcoming ? WidgetFont.labelEmph(lang) : WidgetFont.label(lang))
                .foregroundStyle(line.isUpcoming ? WidgetPalette.nerStrong : WidgetPalette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .widgetHebrewBalanced(lang)

            Spacer(minLength: 8)

            WidgetLTR {
                Text(timeText)
                    .font(WidgetFont.time(lang, size: 17))
                    .foregroundStyle(line.isUpcoming ? WidgetPalette.nerStrong : WidgetPalette.ink)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            if line.isUpcoming {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(WidgetPalette.nerWash)
            }
        }
    }

    private var timeText: String {
        guard let date = line.date else { return WidgetStrings.unavailable(lang) }
        return WidgetFormat.time(date, timeZone: timeZone, lang: lang)
    }
}
