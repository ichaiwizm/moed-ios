//
//  ZmanRow.swift
//  Moed — Components (transverses, sans état)
//
//  Ligne de zman lisible (DESIGN §5.3) : icône · label · shita · heure tabulaire trailing.
//  Contenu de LECTURE → jamais de verre ici. Le zman clé du jour est surligné `nerWash`
//  + `glowNer` (un seul par liste). Une heure absente (latitude extrême) affiche « — »,
//  jamais « NaN », jamais de ligne vide.
//
//  Dépend de DesignSystem (MoedColor/MoedFont/MoedSpace/MoedElevation/ForceLTR) + Models (Zman/ZmanKey/Lang/L10n).
//

import SwiftUI

// MARK: - Formatage partagé (interne au module Components)

/// Utilitaires de formatage **déterministes**, timezone-aware, sans état.
/// Toutes les `Date` du moteur sont des instants absolus : l'affichage HH:MM se fait
/// dans le fuseau IANA de la ville (paramètre `tz`), jamais l'offset device.
enum MoedFmt {

    /// Heure locale « HH:MM » 24 h, chiffres LTR + tabular assurés par la police `zmanTime`.
    static func time(_ date: Date, tz: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// Nombre de jours civils (dans `tz`) séparant deux instants — pour « dans X jours ».
    static func days(from: Date, to: Date, tz: TimeZone = .current) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let a = cal.startOfDay(for: from)
        let b = cal.startOfDay(for: to)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// Date grégorienne localisée courte (ex. « 14 juil. 2026 »), langue active.
    static func gregorian(_ date: Date, lang: Lang, tz: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.locale = Locale(identifier: lang.bcp47)
        f.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return f.string(from: date)
    }

    private struct Units { let h: String; let m: String; let s: String }

    private static func units(_ lang: Lang) -> Units {
        switch lang {
        case .he: return Units(h: "שע׳", m: "דק׳", s: "שנ׳")
        case .fr, .en: return Units(h: "h", m: "min", s: "s")
        }
    }

    /// Compte à rebours « 2 h 14 min » (≥ 1 h) / « 14 min 22 s » (< 1 h) / « 22 s » (< 1 min).
    /// Granularité seconde sous l'heure → justifie la mise à jour chaque seconde de la capsule.
    static func countdown(remaining: TimeInterval, lang: Lang) -> String {
        let total = max(0, Int(remaining.rounded(.towardZero)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        let u = units(lang)
        if h > 0 { return "\(h) \(u.h) \(m) \(u.m)" }
        if m > 0 { return "\(m) \(u.m) \(sec) \(u.s)" }
        return "\(sec) \(u.s)"
    }
}

// MARK: - Présentation d'un ZmanKey (icône SF Symbol non directionnelle)

extension ZmanKey {
    /// Symbole SF **non directionnel** (jamais miroité en RTL).
    var sfSymbol: String {
        switch self {
        case .alotHashachar, .alotHashachar72: return "sun.horizon"
        case .misheyakir, .misheyakirMachmir: return "eye"
        case .hanetzHachama: return "sunrise.fill"
        case .sofZmanShmaMGA, .sofZmanShmaGRA: return "book"
        case .sofZmanTfilaMGA, .sofZmanTfilaGRA: return "hands.and.sparkles"
        case .chatzot: return "sun.max"
        case .minchaGedola: return "sun.min"
        case .minchaKetana: return "sun.min.fill"
        case .plagHamincha: return "sun.haze"
        case .shkiaHachama: return "sunset.fill"
        case .tzeitHakochavim: return "moon.stars.fill"
        case .tzeit72: return "sparkles"
        }
    }

    /// Clé i18n du label affiché (le rendu FR ne vient jamais de la lib de calcul).
    ///
    /// Le libellé est SÉMANTIQUE, pas dérivé du `rawValue` : plusieurs shitot
    /// partagent un même libellé (ex. `alotHashachar` 16.1° et `alotHashachar72`
    /// 72 min → « Aube » ; c'est la ligne `shita`, toujours affichée, qui les
    /// distingue). Les clés existent dans `Localizable.strings` (section `zmanim`).
    var l10nLabelKey: String {
        switch self {
        case .alotHashachar, .alotHashachar72:   return "zmanim.alot"
        case .misheyakir, .misheyakirMachmir:    return "zmanim.misheyakir"
        case .hanetzHachama:                     return "zmanim.sunrise"
        case .sofZmanShmaMGA:                    return "zmanim.sofShmaMGA"
        case .sofZmanShmaGRA:                    return "zmanim.sofShmaGRA"
        case .sofZmanTfilaMGA, .sofZmanTfilaGRA: return "zmanim.sofTefila"
        case .chatzot:                           return "zmanim.chatzot"
        case .minchaGedola:                      return "zmanim.minchaGedola"
        case .minchaKetana:                      return "zmanim.minchaKetana"
        case .plagHamincha:                      return "zmanim.plag"
        case .shkiaHachama:                      return "zmanim.sunset"
        case .tzeitHakochavim:                   return "zmanim.tzeit"
        case .tzeit72:                           return "zmanim.tzeitRT"
        }
    }
}

// MARK: - ZmanRow

/// Une ligne de la liste de zmanim. Stateless : tout dérive de `zman` + `isKey`.
struct ZmanRow: View {

    let zman: Zman
    /// Surligne cette ligne comme « zman clé » du jour (fond `nerWash` + `glowNer`). Un seul par liste.
    var isKey: Bool = false
    /// Fuseau IANA de la ville (pilote l'affichage HH:MM et le DST).
    var timeZone: TimeZone = .current

    @Environment(\.moedLang) private var lang

    private var kind: ZmanKey? { ZmanKey(rawValue: zman.key) }
    private var label: String { L10n.t(kind?.l10nLabelKey ?? "zmanim.\(zman.key)", lang) }
    private var icon: String { kind?.sfSymbol ?? "clock" }

    private var timeString: String? {
        guard let d = zman.date else { return nil }
        return MoedFmt.time(d, tz: timeZone)
    }

    var body: some View {
        let row = HStack(alignment: .firstTextBaseline, spacing: MoedSpace.s12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(isKey ? MoedColor.ner : MoedColor.inkSoft)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MoedSpace.s2) {
                Text(label)
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
                Text(zman.shita) // shita TOUJOURS affichée — transparence halakhique
                    .font(MoedFont.caption(lang))
                    .foregroundStyle(MoedColor.inkMute)
            }

            Spacer(minLength: MoedSpace.s8)

            timeView
        }
        .padding(.horizontal, MoedSpace.s16)
        .padding(.vertical, MoedSpace.s12)
        .frame(minHeight: 44) // cible tactile / lisibilité
        .background {
            if isKey {
                RoundedRectangle(cornerRadius: MoedRadius.sm, style: .continuous)
                    .fill(MoedColor.nerWash)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel)

        // Le glow flamme n'orne QUE le zman clé (DESIGN §4.3).
        if isKey {
            MoedElevation.glowNer(row)
        } else {
            row
        }
    }

    @ViewBuilder private var timeView: some View {
        if let t = timeString {
            // Les chiffres restent LTR même en hébreu → « 18:42 » jamais inversé.
            ForceLTR {
                Text(t)
                    .font(MoedFont.zmanTime(lang))
                    .monospacedDigit()
                    .foregroundStyle(isKey ? MoedColor.ner : MoedColor.ink)
            }
        } else {
            // Latitude extrême : le soleil n'atteint pas l'angle → « — », jamais NaN.
            Text("—")
                .font(MoedFont.zmanTime(lang))
                .monospacedDigit()
                .foregroundStyle(MoedColor.inkMute)
                .accessibilityLabel(L10n.t("zmanim.unavailable", lang))
        }
    }

    private var voiceOverLabel: String {
        // Ordre de lecture DESIGN §10 : « [label], [shita], [heure] ».
        let value = timeString ?? L10n.t("zmanim.unavailable", lang)
        return "\(label), \(zman.shita), \(value)"
    }
}
