//
//  FloatingAddButton.swift
//  Moed — Components (transverses, sans état)
//
//  Bouton d'action flottant (DESIGN §5.4) : verre `glassFloat` teinté ner + halo `glowNer`,
//  icône `plus`, cible tactile 56 pt. Ancré bottom-trailing (→ bottom-leading auto en RTL
//  grâce aux alignements logiques). Ouvre une sheet côté écran (action injectée).
//
//  Stateless côté données ; un `@State` local ne sert qu'à déclencher l'haptique de sélection.
//

import SwiftUI

struct FloatingAddButton: View {

    /// Action déclenchée au tap (ex. présenter `AddPersonSheet`).
    let action: () -> Void
    /// Icône SF Symbol (non directionnelle par défaut : « plus »).
    var systemImage: String = "plus"
    /// Libellé d'accessibilité (déjà localisé).
    var accessibilityTitle: String

    @Environment(\.moedLang) private var lang
    @State private var taps = 0

    var body: some View {
        Button {
            taps &+= 1
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MoedColor.nerStrong)
                .frame(width: 56, height: 56)
                // Verre flottant teinté flamme (chrome/contrôle → verre autorisé).
                .glass(.float, tint: MoedColor.ner.opacity(0.14))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        // Halo flamme réservé aux éléments d'allumage / action forte.
        .modifier(GlowNerModifier())
        .haptic(.selection, trigger: taps)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityAddTraits(.isButton)
    }
}

/// Applique le glow flamme sanctionné (`MoedElevation.glowNer`) en conservant le type de vue.
private struct GlowNerModifier: ViewModifier {
    func body(content: Content) -> some View {
        MoedElevation.glowNer(content)
    }
}
