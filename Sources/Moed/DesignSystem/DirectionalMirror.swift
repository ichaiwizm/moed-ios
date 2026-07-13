import SwiftUI

/// Miroir horizontal automatique en RTL (hébreu) pour les éléments directionnels
/// — chevrons, flèches de navigation, icônes de progression (DESIGN §8).
/// S'applique sur n'importe quelle vue (Image ou autre) : la vue est retournée
/// sur l'axe X uniquement quand la direction de layout est `.rightToLeft`.
private struct DirectionalMirror: ViewModifier {
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.scaleEffect(
            x: layoutDirection == .rightToLeft ? -1 : 1,
            y: 1,
            anchor: .center
        )
    }
}

extension View {
    /// Miroite horizontalement l'élément en RTL (voir `DirectionalMirror`).
    func directionalMirror() -> some View {
        modifier(DirectionalMirror())
    }
}
