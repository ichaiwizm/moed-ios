//
//  GlassBackground.swift
//  Moed — DesignSystem
//
//  Abstraction du « Liquid Glass » (DESIGN.md §4.2 / CONTRACTS.md §2.4).
//
//  Le langage Liquid Glass est une API iOS 26 (`.glassEffect`). Cible = iOS 17.
//  Stratégie (PLAN.md) : rendre `.glassEffect(.regular.tint(...))` sous
//  `#available(iOS 26)`, et retomber sur `.regularMaterial` + bordure `lineStrong`
//  + ombre `e2` en iOS 17–25. Aucune fonctionnalité ne dépend du verre : c'est un
//  habillage progressif.
//
//  ACCESSIBILITÉ — Reduce Transparency (DESIGN §10) : si activé, le verre est
//  remplacé par `surface` OPAQUE + bordure `lineStrong` (lisibilité TabBar/header
//  garantie). C'est prioritaire sur toute la logique de matériau.
//
//  Règle d'or DA : le verre = chrome / contrôles flottants uniquement, jamais
//  sous du contenu de lecture, jamais verre sur verre (DESIGN §12). Le contenu
//  lisible utilise une surface opaque (`cardSolid`, cf. Components).
//
//  Aucune logique métier ici.
//

import SwiftUI

/// Rôles de verre (CONTRACTS §2.4).
public enum GlassStyle {
    /// TabBar, header au scroll, toolbar. `.regularMaterial` + glassEffect(.regular).
    case chrome
    /// Bouton d'action flottant (FAB), capsule de compte à rebours — teinté `ner`.
    case float
    /// Fond de sheet / formulaire.
    case sheet
}

public struct GlassBackground: ViewModifier {

    let style: GlassStyle
    var tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(style: GlassStyle, tint: Color? = nil) {
        self.style = style
        self.tint = tint
    }

    // Forme selon le rôle : chrome/float = pilule flottante, sheet = grand rayon.
    private var cornerRadius: CGFloat {
        switch style {
        case .chrome, .float: return MoedRadius.lg   // approché ; les vraies pilules passent une Capsule
        case .sheet:          return MoedRadius.lg
        }
    }

    private var shape: RoundedRectangle { MoedRadius.shape(cornerRadius) }

    // Teinte effective : le verre flottant (`float`) reçoit un halo flamme par défaut.
    private var effectiveTint: Color? {
        if let tint { return tint }
        return style == .float ? MoedColor.ner.opacity(0.14) : nil
    }

    public func body(content: Content) -> some View {
        // (1) Reduce Transparency : surface opaque, priorité absolue.
        if reduceTransparency {
            content
                .background(MoedColor.surface, in: shape)
                .overlay(shape.strokeBorder(MoedColor.lineStrong, lineWidth: 1))
                .modifier(_Elevation(style: style))
        } else if #available(iOS 26.0, *) {
            // (2) iOS 26+ : vrai Liquid Glass.
            content
                .glassEffect(glassConfig, in: shape)
        } else {
            // (3) iOS 17–25 : material + bordure + ombre (habillage progressif).
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    if let effectiveTint {
                        shape.fill(effectiveTint)
                    }
                }
                .overlay(shape.strokeBorder(MoedColor.lineStrong.opacity(0.6), lineWidth: 1))
                .modifier(_Elevation(style: style))
        }
    }

    @available(iOS 26.0, *)
    private var glassConfig: Glass {
        if let effectiveTint {
            return Glass.regular.tint(effectiveTint)
        }
        return Glass.regular
    }
}

/// Ombre associée au rôle de verre (fallback iOS 17–25 & Reduce Transparency).
/// Le verre `sheet` monte en `e3` (modale) ; chrome/float en `e2`.
private struct _Elevation: ViewModifier {
    let style: GlassStyle
    func body(content: Content) -> some View {
        switch style {
        case .sheet:          return AnyView(MoedElevation.e3(content))
        case .chrome, .float: return AnyView(MoedElevation.e2(content))
        }
    }
}

public extension View {
    /// Applique un fond de verre Moed. Ex. `.glass(.chrome)`, `.glass(.float, tint: .ner)`.
    func glass(_ style: GlassStyle, tint: Color? = nil) -> some View {
        modifier(GlassBackground(style: style, tint: tint))
    }
}
