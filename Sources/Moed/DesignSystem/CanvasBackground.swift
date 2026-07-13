//
//  CanvasBackground.swift
//  Moed — DesignSystem
//
//  Fond racine immobile « parchemin d'aube » (DESIGN.md §2.3 / CONTRACTS.md §2.5).
//
//  Le fond n'est JAMAIS plat et JAMAIS blanc pur : dégradé vertical très subtil
//  (`canvasGradientTop` → `canvasGradientBottom`) surmonté d'un halo d'aube radial
//  extrêmement diffus en haut, teinté `nerGlow` à 3 % d'opacité, derrière le
//  header. Aucun mouvement — c'est « la lumière fixée ». Le verre du chrome
//  réfracte ce dégradé au scroll.
//
//  Aucune logique métier ici.
//

import SwiftUI

/// Fond racine à poser sous tout le contenu (posé une fois au niveau `RootView`).
public struct CanvasBackground: View {

    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [MoedColor.canvasGradientTop, MoedColor.canvasGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // Halo d'aube : radial très diffus, teinté flamme à 3 %, ancré en haut.
            RadialGradient(
                colors: [MoedColor.nerGlow.opacity(0.03), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

#Preview("Canvas") {
    CanvasBackground()
}
