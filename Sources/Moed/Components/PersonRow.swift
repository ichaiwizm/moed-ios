//
//  PersonRow.swift
//  Moed — Components (transverses, sans état)
//
//  Ligne du carnet familial (DESIGN §5.4). Leading : pastille de type — cercle `nerWash`
//  (anniversaire, icône `gift`) ou `twilightWash` (yahrzeit, icône `flame`). Titre : nom
//  (`bodyEmph`, ink). Sous-titre : prochaine occurrence (grég + héb, `caption`, inkSoft).
//  Trailing : badge « dans X jours » (capsule `surfaceDeep`).
//
//  Stateless : `person` + `next` (Occurrence calculée par PersonalEngine) + `now` (référence de comptage).
//

import SwiftUI

struct PersonRow: View {

    let person: PersonRecord
    /// Prochaine occurrence (déjà calculée en amont). nil si non résolue → sous-titre masqué.
    var next: Occurrence?
    /// Référence pour « dans X jours » (aujourd'hui).
    var now: Date = Date()
    var timeZone: TimeZone = .current

    @Environment(\.moedLang) private var lang

    private var isBirthday: Bool { person.type == .birthday }

    var body: some View {
        HStack(spacing: MoedSpace.s12) {
            typePastille
            VStack(alignment: .leading, spacing: MoedSpace.s2) {
                Text(person.name)
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
                    .lineLimit(1)
                if let subtitle = occurrenceSubtitle {
                    Text(subtitle)
                        .font(MoedFont.caption(lang))
                        .foregroundStyle(MoedColor.inkSoft)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: MoedSpace.s8)
            if let badge = daysBadge {
                Text(badge)
                    .font(MoedFont.caption(lang))
                    .foregroundStyle(MoedColor.inkSoft)
                    .padding(.horizontal, MoedSpace.s12)
                    .padding(.vertical, 6)
                    .background(MoedColor.surfaceDeep, in: Capsule(style: .continuous))
            }
        }
        .padding(.vertical, MoedSpace.s4)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel)
    }

    // MARK: Sous-vues

    private var typePastille: some View {
        ZStack {
            Circle()
                .fill(isBirthday ? MoedColor.nerWash : MoedColor.twilightWash)
            // Icônes bougie / cadeau NON directionnelles → jamais miroitées.
            Image(systemName: isBirthday ? "gift" : "flame")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(isBirthday ? MoedColor.ner : MoedColor.twilight)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    // MARK: Dérivés

    /// « 14 juil. 2026 · ט״ו תמוז תשפ״ו »
    private var occurrenceSubtitle: String? {
        guard let next else { return nil }
        let greg = MoedFmt.gregorian(next.gregorian, lang: lang, tz: timeZone)
        let heb = "\(next.hebrew.dayHebrew) \(next.hebrew.monthName(lang)) \(next.hebrew.yearHebrew)"
        return "\(greg) · \(heb)"
    }

    private var daysBadge: String? {
        guard let next else { return nil }
        let d = MoedFmt.days(from: now, to: next.gregorian, tz: timeZone)
        if d <= 0 { return L10n.t("common.today", lang) }
        return L10n.t("personal.inDays", lang, ["n": d])
    }

    private var voiceOverLabel: String {
        let type = L10n.t(isBirthday ? "personal.typeBirthday" : "personal.typeYahrzeit", lang)
        var parts = [person.name, type]
        if let occurrenceSubtitle { parts.append(occurrenceSubtitle) }
        if let daysBadge { parts.append(daysBadge) }
        return parts.joined(separator: ", ")
    }
}
