//
//  ScrollGlassHeader.swift
//  Moed — Components (transverses, sans état)
//
//  Bandeau de navigation qui apparaît au scroll (DESIGN §5.1) : au-delà de ~12 pt de défilement,
//  un chrome `glassChrome` glisse depuis le haut avec un titre condensé (`title3`). Transition
//  `.smooth` (fondu + glissement depuis le haut). Respecte Reduce Motion (cross-fade simple).
//
//  Stateless : `visible` est piloté par l'écran via l'offset mesuré (helper `trackScrollOffset`).
//  Le verre appartient au chrome flottant — jamais sous du contenu de lecture.
//

import SwiftUI

// MARK: - Mesure d'offset de scroll (utilitaire d'écran)

/// PreferenceKey remontant l'offset vertical d'un `ScrollView` pour piloter l'apparition du header.
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// À placer en tête du contenu scrollable (dans un `ScrollView` ayant `.coordinateSpace(name:)`).
    /// Émet l'offset via `ScrollOffsetKey` ; l'écran lit la préférence et calcule `visible`.
    func trackScrollOffset(in space: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetKey.self,
                    value: -geo.frame(in: .named(space)).minY
                )
            }
        )
    }
}

// MARK: - ScrollGlassHeader

struct ScrollGlassHeader: View {

    /// Titre condensé (ex. date hébraïque courte). Déjà localisé.
    let title: String
    /// Sous-titre optionnel (ex. ville) affiché en `caption`.
    var subtitle: String? = nil
    /// Piloté par l'écran : true dès que l'offset dépasse le seuil (≈ 12 pt).
    let visible: Bool

    @Environment(\.moedLang) private var lang
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if visible {
                content
                    .transition(headerTransition)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.5), value: visible)
    }

    private var content: some View {
        VStack(spacing: MoedSpace.s2) {
            Text(title)
                .font(MoedFont.title3(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(MoedFont.caption(lang))
                    .foregroundStyle(MoedColor.inkMute)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MoedSpace.s20)
        .padding(.vertical, MoedSpace.s12)
        // Chrome verre qui réfracte le contenu passant dessous ; Reduce Transparency → surface opaque.
        .glass(.chrome)
        .accessibilityAddTraits(.isHeader)
    }

    private var headerTransition: AnyTransition {
        if reduceMotion {
            return .opacity // pas de glissement si Reduce Motion
        }
        return .opacity.combined(with: .move(edge: .top))
    }
}
