//
//  MoedColor.swift
//  Moed — DesignSystem
//
//  Tokens de couleur sémantiques (DESIGN.md §2 / CONTRACTS.md §2.1).
//  Un color set Asset Catalog par token, avec variantes Any (light) / Dark.
//  Le dark est PRÉSENT dans l'asset catalog mais NON branché en v1
//  (la racine force `.preferredColorScheme(.light)`, DESIGN §9). Les `Material`
//  Apple s'inverseront seuls le jour où le dark sera activé.
//
//  La couleur n'est jamais décorative : chaque token porte un sens (DESIGN §2).
//  Ne dépend d'aucune logique métier.
//

import SwiftUI

/// Palette sémantique de Moed. Chaque propriété lit un color set du bundle.
///
/// Les noms de tokens sont **contractuels** (CONTRACTS §2.1) : tous les
/// composants et écrans les référencent tels quels.
public enum MoedColor {

    /// Charge un color set du catalogue DesignSystem par son nom de token.
    /// Le catalogue est compilé dans le bundle principal de l'app (et dupliqué
    /// dans la cible widgets via double target membership, cf. CONTRACTS §4.4).
    @inline(__always)
    private static func token(_ name: String) -> Color {
        Color(name, bundle: .main)
    }

    // MARK: Fond / surfaces
    public static let canvas               = token("canvas")
    public static let canvasGradientTop    = token("canvasGradientTop")
    public static let canvasGradientBottom = token("canvasGradientBottom")
    public static let surface              = token("surface")
    public static let surfaceDeep          = token("surfaceDeep")
    public static let line                 = token("line")
    public static let lineStrong           = token("lineStrong")

    // MARK: Encre (texte)
    public static let ink     = token("ink")
    public static let inkSoft = token("inkSoft")
    public static let inkMute = token("inkMute")

    // MARK: Flamme (ner) — l'or sacré, rare
    public static let ner       = token("ner")
    public static let nerStrong = token("nerStrong")
    public static let nerGlow   = token("nerGlow")
    public static let nerWash   = token("nerWash")

    // MARK: Crépuscule & sémantique
    public static let twilight     = token("twilight")
    public static let twilightWash = token("twilightWash")
    public static let sage         = token("sage")
    public static let sageWash     = token("sageWash")
    public static let rose         = token("rose")
    public static let roseWash     = token("roseWash")
    public static let focus        = token("focus")
}
