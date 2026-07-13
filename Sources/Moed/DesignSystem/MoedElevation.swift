//
//  MoedElevation.swift
//  Moed — DesignSystem
//
//  Élévations = ombres TEINTÉES encre (`ink`), jamais noires (DESIGN.md §4.3 /
//  CONTRACTS.md §2.3). Le glow flamme (`glowNer`) est réservé au zman clé et à
//  l'allumage — un seul élément fort par écran (DESIGN §12).
//
//  Conversion blur → rayon SwiftUI : `.shadow(radius:)` ≈ (blur CSS) / 2.
//  Aucune logique métier ici.
//

import SwiftUI

public enum MoedElevation {

    /// Carte au repos — y 2, blur 10, `ink` @0.06.
    public static func e1<V: View>(_ v: V) -> some View {
        v.shadow(color: MoedColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    /// Carte active / popover / verre flottant — y 6, blur 22, `ink` @0.10.
    public static func e2<V: View>(_ v: V) -> some View {
        v.shadow(color: MoedColor.ink.opacity(0.10), radius: 11, x: 0, y: 6)
    }

    /// Sheet / modale — y 16, blur 44, `ink` @0.16.
    public static func e3<V: View>(_ v: V) -> some View {
        v.shadow(color: MoedColor.ink.opacity(0.16), radius: 22, x: 0, y: 16)
    }

    /// **Zman clé / allumage UNIQUEMENT** — y 0, blur 30, `nerGlow` @0.30.
    /// Un seul par écran (DESIGN §12).
    public static func glowNer<V: View>(_ v: V) -> some View {
        v.shadow(color: MoedColor.nerGlow.opacity(0.30), radius: 15, x: 0, y: 0)
    }
}

// MARK: - Sucre syntaxique (chaînage)

public extension View {
    /// Applique une élévation Moed. `.moedElevation(.e2)`
    func moedElevation(_ level: MoedElevationLevel) -> some View {
        switch level {
        case .e1:      return AnyView(MoedElevation.e1(self))
        case .e2:      return AnyView(MoedElevation.e2(self))
        case .e3:      return AnyView(MoedElevation.e3(self))
        case .glowNer: return AnyView(MoedElevation.glowNer(self))
        }
    }
}

public enum MoedElevationLevel { case e1, e2, e3, glowNer }
