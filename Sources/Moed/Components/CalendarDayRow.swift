//
//  CalendarDayRow.swift
//  Moed — Components (transverses, sans état)
//
//  Ligne d'un jour du calendrier mensuel (DESIGN §5.4). Leading : jour hébraïque (lettres)
//  prominent + jour grégorien. Trailing : badges d'événements colorés par catégorie
//  (fête=ner, jeûne=rose, roch hodech=twilight, omer=sage, autre=neutre). Sur `cardSolid`.
//
//  Stateless : tout dérive du `CalendarDay`. `isToday` surligne le jour courant.
//

import SwiftUI

struct CalendarDayRow: View {

    let day: CalendarDay
    var isToday: Bool = false
    var timeZone: TimeZone = .current

    @Environment(\.moedLang) private var lang

    /// Événements affichables (on écarte `parasha`/`other` sans titre du flux de badges principal).
    private var badgeEvents: [CalEvent] {
        day.events.filter { $0.category != .parasha }
    }

    var body: some View {
        HStack(alignment: .top, spacing: MoedSpace.s16) {
            dateColumn
            VStack(alignment: .leading, spacing: MoedSpace.s8) {
                if !badgeEvents.isEmpty {
                    badgeWrap
                }
                if let omer = day.omer {
                    Badge(text: L10n.t("home.omerDay", lang, ["n": omer]), style: .omer)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MoedSpace.s16)
        .padding(.vertical, MoedSpace.s12)
        .frame(minHeight: 44)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: MoedRadius.sm, style: .continuous)
                    .fill(MoedColor.nerWash)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(voiceOverLabel)
    }

    // MARK: Colonne date

    private var dateColumn: some View {
        VStack(alignment: .center, spacing: MoedSpace.s2) {
            // Jour hébraïque en lettres (ex. « ט״ו ») — RTL naturel, hébreu équilibré.
            Text(day.hebrew.dayHebrew)
                .font(MoedFont.title3(lang))
                .foregroundStyle(isToday ? MoedColor.ner : MoedColor.ink)
                .hebrewBalanced(lang)
            // Jour grégorien : chiffres LTR + tabular.
            ForceLTR {
                Text(gregorianDayNumber)
                    .font(MoedFont.caption(lang))
                    .monospacedDigit()
                    .foregroundStyle(MoedColor.inkMute)
            }
        }
        .frame(width: 44)
    }

    private var badgeWrap: some View {
        // Enroulement flexible des badges (max lisible ; le reste tronqué par le layout parent).
        FlowLayout(spacing: MoedSpace.s4) {
            ForEach(badgeEvents) { event in
                Badge(event: event, lang: lang)
            }
        }
    }

    // MARK: Dérivés

    private var gregorianDayNumber: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return String(cal.component(.day, from: day.date))
    }

    private var voiceOverLabel: String {
        var parts: [String] = [
            "\(day.hebrew.dayHebrew) \(day.hebrew.monthName(lang))",
            MoedFmt.gregorian(day.date, lang: lang, tz: timeZone)
        ]
        parts.append(contentsOf: badgeEvents.map { $0.title(lang) })
        if let omer = day.omer { parts.append(L10n.t("home.omerDay", lang, ["n": omer])) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - FlowLayout (enroulement des chips, respecte la direction de lecture)

/// Layout d'enroulement horizontal minimal (iOS 16+ `Layout`). Respecte `layoutDirection`
/// via les alignements logiques de SwiftUI — les badges partent du bord `leading`.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [CGFloat] = [0]
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rows.append(0)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
