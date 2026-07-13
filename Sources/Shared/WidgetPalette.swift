//
//  WidgetPalette.swift
//  Moed — Shared (double target membership : Moed + MoedWidgets)
//
//  Palette et fond « parchemin » DÉDIÉS aux widgets (DESIGN.md §11).
//
//  Pourquoi une palette locale plutôt que `MoedColor` ?
//  ────────────────────────────────────────────────────
//  `MoedColor` lit un Asset Catalog compilé dans le bundle de l'app. Une
//  extension WidgetKit possède son PROPRE bundle : `Color(name, bundle: .main)`
//  n'y résout pas le catalogue de l'app. On fige donc ici les mêmes valeurs
//  hexadécimales que les color sets (`Assets.xcassets/*.colorset`) sous forme de
//  `Color(.sRGB, …)` — zéro ressource, zéro réseau, résolution garantie dans
//  l'extension. Les valeurs sont copiées 1:1 de la DA (DESIGN.md §2) ; toute
//  dérive = incohérence visuelle app ↔ widget.
//
//  DA widgets (DESIGN.md §11) : fond parchment gradient, JAMAIS de verre — un
//  widget ne réfracte rien d'utile. Une seule flamme (ner) par widget.
//

import SwiftUI

/// Tokens couleur figés pour les widgets (miroir des color sets DesignSystem).
/// Light mode uniquement (les widgets home-screen suivent le fond du système,
/// mais le contenu parchemin reste clair — DA v1, DESIGN §9/§11).
enum WidgetPalette {

    @inline(__always)
    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }

    // Fond / surfaces (parchemin — jamais blanc pur en canvas)
    static let canvasTop    = rgb(0xFD, 0xFB, 0xF6)   // #FDFBF6
    static let canvasBottom = rgb(0xF4, 0xEC, 0xDC)   // #F4ECDC
    static let surface      = rgb(0xFF, 0xFF, 0xFF)   // #FFFFFF (carte only)
    static let line         = rgb(0xE7, 0xDE, 0xCB)   // #E7DECB
    static let lineStrong   = rgb(0xD8, 0xCB, 0xB0)   // #D8CBB0

    // Encre
    static let ink     = rgb(0x1A, 0x1B, 0x2E)        // #1A1B2E
    static let inkSoft = rgb(0x55, 0x56, 0x6E)        // #55566E
    static let inkMute = rgb(0x8A, 0x8A, 0xA0)        // #8A8AA0

    // Flamme (ner) — l'or sacré, rare : UNE occurrence forte par widget
    static let ner       = rgb(0xC0, 0x79, 0x2B)     // #C0792B
    static let nerStrong = rgb(0xA6, 0x63, 0x1C)     // #A6631C
    static let nerGlow   = rgb(0xF0, 0xB9, 0x5C)     // #F0B95C
    static let nerWash   = rgb(0xFB, 0xEF, 0xDA)     // #FBEFDA (surlignage zman à venir)

    // Crépuscule & sémantique
    static let twilight = rgb(0x35, 0x40, 0x6E)      // #35406E
    static let sage     = rgb(0x5F, 0x70, 0x50)      // #5F7050 (Omer / positif)
    static let sageWash = rgb(0xE5, 0xE4, 0xD9)      // #E5E4D9
}

/// Fond racine des widgets home-screen : « parchemin d'aube », immobile.
///
/// Réplique `CanvasBackground` (DESIGN §2.5) à l'échelle widget :
/// dégradé linéaire haut→bas + halo de flamme très discret en haut. Aucun verre.
/// À poser via `.containerBackground(for: .widget)` sur les familles `.systemSmall`
/// / `.systemMedium` (les familles Lock Screen n'ont PAS de fond — le système
/// fournit le sien, cf. `WidgetPalette` + rendu `.accented`).
struct ParchmentBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WidgetPalette.canvasTop, WidgetPalette.canvasBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [WidgetPalette.nerGlow.opacity(0.05), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 220
            )
        }
    }
}
