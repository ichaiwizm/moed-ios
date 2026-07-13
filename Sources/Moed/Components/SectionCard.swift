//
//  SectionCard.swift
//  Moed — Components (transverses, sans état)
//
//  Conteneur de CONTENU lisible (DESIGN §4.2 `cardSolid`) : surface OPAQUE + bordure
//  `lineStrong` + rayon md + élévation `e1`. JAMAIS de verre ici (verre = chrome
//  uniquement ; le contenu de lecture se pose sur une surface calme et opaque).
//
//  Générique sur son contenu, avec titre de section optionnel (`title2`) et pied optionnel.
//

import SwiftUI

struct SectionCard<Content: View, Footer: View>: View {

    var title: String? = nil
    /// Padding interne (20 par défaut ; 16 en compact — DESIGN §4.4).
    var padding: CGFloat = MoedSpace.s20
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    @Environment(\.moedLang) private var lang

    var body: some View {
        let card = VStack(alignment: .leading, spacing: MoedSpace.s16) {
            if let title {
                Text(title)
                    .font(MoedFont.title2(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            }
            content()
            footer()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoedColor.surface, in: RoundedRectangle(cornerRadius: MoedRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoedRadius.md, style: .continuous)
                .strokeBorder(MoedColor.lineStrong, lineWidth: 1)
        }

        MoedElevation.e1(card)
    }
}

// MARK: - Confort d'usage (sans pied de carte)

extension SectionCard where Footer == EmptyView {
    init(title: String? = nil,
         padding: CGFloat = MoedSpace.s20,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.padding = padding
        self.content = content
        self.footer = { EmptyView() }
    }
}

// MARK: - Séparateur fin réutilisable (couleur `line`)

/// Filet de séparation entre lignes de contenu dans une carte (DESIGN §5.3).
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(MoedColor.line)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
