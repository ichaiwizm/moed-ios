//
//  Badge.swift
//  Moed — Components (transverses, sans état)
//
//  Badges & chips par catégorie (DESIGN §5.6). Capsule, padding H12/V6, texte `caption`.
//  | Type          | Fond          | Texte      | Icône       |
//  | Omer          | sageWash      | sage       | leaf        |
//  | Fête/Yom Tov  | nerWash       | nerStrong  | flame       |
//  | Roch Hodech   | twilightWash  | twilight   | moon        |
//  | Jeûne         | rose@0.12     | rose       | moon.stars  |
//  | Neutre        | surfaceDeep   | inkSoft    | —           |
//
//  Toutes les icônes de badge sont NON directionnelles → jamais miroitées en RTL.
//

import SwiftUI

/// Palette sémantique d'un badge. La couleur signale la catégorie, elle n'est jamais décorative.
enum BadgeStyle: Equatable {
    case omer
    case festival      // fête / Yom Tov
    case roshChodesh
    case fast          // jeûne
    case neutral

    /// Mapping depuis la catégorie d'événement du moteur.
    init(category: EventCategory) {
        switch category {
        case .omer: self = .omer
        case .holiday, .yomtov: self = .festival
        case .roshchodesh: self = .roshChodesh
        case .fast: self = .fast
        case .parasha, .other: self = .neutral
        }
    }

    var fill: Color {
        switch self {
        case .omer: return MoedColor.sageWash
        case .festival: return MoedColor.nerWash
        case .roshChodesh: return MoedColor.twilightWash
        case .fast: return MoedColor.rose.opacity(0.12)
        case .neutral: return MoedColor.surfaceDeep
        }
    }

    var textColor: Color {
        switch self {
        case .omer: return MoedColor.sage
        case .festival: return MoedColor.nerStrong
        case .roshChodesh: return MoedColor.twilight
        case .fast: return MoedColor.rose
        case .neutral: return MoedColor.inkSoft
        }
    }

    /// Icône SF Symbol non directionnelle, ou nil (neutre).
    var icon: String? {
        switch self {
        case .omer: return "leaf"
        case .festival: return "flame"
        case .roshChodesh: return "moon"
        case .fast: return "moon.stars"
        case .neutral: return nil
        }
    }
}

/// Chip capsule compacte. Le texte est fourni tel quel (déjà localisé par l'appelant).
struct Badge: View {

    let text: String
    var style: BadgeStyle = .neutral
    /// Force le masquage de l'icône même si le style en propose une.
    var showsIcon: Bool = true

    @Environment(\.moedLang) private var lang

    /// Fabrique un badge à partir d'un événement calendaire (titre localisé + style dérivé).
    init(event: CalEvent, lang: Lang) {
        self.text = event.title(lang)
        self.style = BadgeStyle(category: event.category)
        self.showsIcon = true
    }

    init(text: String, style: BadgeStyle = .neutral, showsIcon: Bool = true) {
        self.text = text
        self.style = style
        self.showsIcon = showsIcon
    }

    var body: some View {
        HStack(spacing: MoedSpace.s4) {
            if showsIcon, let icon = style.icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(MoedFont.caption(lang))
                .hebrewBalanced(lang)
                .lineLimit(1)
        }
        .foregroundStyle(style.textColor)
        .padding(.horizontal, MoedSpace.s12)
        .padding(.vertical, 6)
        .background(style.fill, in: Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
