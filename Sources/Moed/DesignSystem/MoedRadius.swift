//
//  MoedRadius.swift
//  Moed — DesignSystem
//
//  Rayons continus (squircle Apple) et échelle d'espacement.
//  (DESIGN.md §4.1 & §4.4 / CONTRACTS.md §2.3.)
//
//  Règle : TOUJOURS `RoundedRectangle(cornerRadius:, style: .continuous)`.
//  Pour les pilules, utiliser `Capsule()`. Aucune logique métier ici.
//

import SwiftUI

/// Rayons de coins (points). Valeurs gelées (CONTRACTS §2.3).
public enum MoedRadius {
    /// 10 — chips, champs, petits badges.
    public static let sm: CGFloat = 10
    /// 16 — cartes de contenu.
    public static let md: CGFloat = 16
    /// 26 — sheets, modales, carte Chabbat feature.
    public static let lg: CGFloat = 26

    /// Forme continue prête à l'emploi pour un rayon donné.
    public static func shape(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

/// Échelle d'espacement 4 px et marges clés (DESIGN §4.4 / CONTRACTS §2.3).
public enum MoedSpace {
    public static let s2:  CGFloat = 2
    public static let s4:  CGFloat = 4
    public static let s8:  CGFloat = 8
    public static let s12: CGFloat = 12
    public static let s16: CGFloat = 16
    public static let s20: CGFloat = 20
    public static let s24: CGFloat = 24
    public static let s32: CGFloat = 32
    public static let s40: CGFloat = 40
    public static let s56: CGFloat = 56
    public static let s72: CGFloat = 72
    public static let s96: CGFloat = 96

    /// Marge de page mobile = 20.
    public static let pagePadding: CGFloat = 20
    /// Espacement inter-cartes = 16.
    public static let interCard: CGFloat = 16
    /// Padding interne de carte = 20 (16 en compact).
    public static let cardPadding: CGFloat = 20
    public static let cardPaddingCompact: CGFloat = 16
}
