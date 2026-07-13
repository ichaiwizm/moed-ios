//
//  ShabbatCard.swift
//  Moed — Components (transverses, sans état)
//
//  Carte Chabbat « héros » (DESIGN §5.2) — l'UNIQUE porteuse de flamme pleine de l'écran.
//  Conteneur radiusLg, fond `surface`, bordure `lineStrong`, ombre `e2` + `glowNer`,
//  filet de braise en haut (`nerGlow → ner`, 3 pt), motif bougie symbolique en trailing,
//  heure d'allumage en `hero` (40 pt, ner, tabular), `CountdownCapsule` verre, havdala discrète.
//
//  Stateless : `shabbat` (ShabbatModel) + `now` (tick AppState) + `timeZone` de la ville.
//

import SwiftUI

struct ShabbatCard: View {

    let shabbat: ShabbatModel
    /// « Maintenant » (tick 1 s de l'AppState) pour le compte à rebours.
    let now: Date
    /// Fuseau IANA de la ville pour l'affichage HH:MM (allumage/havdala).
    var timeZone: TimeZone = .current

    @Environment(\.moedLang) private var lang

    var body: some View {
        let card = VStack(alignment: .leading, spacing: MoedSpace.s16) {
            header
            candleBlock
            if let havdalah = shabbat.havdalah {
                havdalaLine(havdalah)
            }
        }
        .padding(MoedSpace.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoedColor.surface, in: RoundedRectangle(cornerRadius: MoedRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MoedRadius.lg, style: .continuous)
                .strokeBorder(MoedColor.lineStrong, lineWidth: 1)
        }
        // Filet de braise en tête, clippé aux coins hauts de la carte.
        .overlay(alignment: .top) { emberStrip }
        .clipShape(RoundedRectangle(cornerRadius: MoedRadius.lg, style: .continuous))

        // Héros = e2 + glow flamme (le seul élément fort de l'écran à porter le ner plein).
        MoedElevation.glowNer(MoedElevation.e2(card))
    }

    // MARK: Sous-vues

    private var emberStrip: some View {
        LinearGradient(
            colors: [MoedColor.nerGlow, MoedColor.ner],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: MoedSpace.s4) {
                Text(L10n.t("home.nextShabbat", lang).uppercased())
                    .font(MoedFont.caption(lang))
                    .tracking(0.8)
                    .foregroundStyle(MoedColor.inkMute)
                Text(shabbat.parashaName(lang))
                    .font(MoedFont.title3(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
            }
            Spacer(minLength: MoedSpace.s12)
            candleMotif
        }
    }

    /// Motif bougie symbolique + halo `nerGlow` — jamais un « portrait » ; icône non directionnelle.
    private var candleMotif: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(MoedColor.nerGlow.opacity(0.2))
                .blur(radius: 10)
            Image(systemName: "flame.fill")
                .font(.system(size: 30))
                .foregroundStyle(
                    LinearGradient(colors: [MoedColor.nerGlow, MoedColor.ner],
                                   startPoint: .top, endPoint: .bottom)
                )
        }
        .accessibilityHidden(true)
    }

    private var candleBlock: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s8) {
            HStack(alignment: .firstTextBaseline, spacing: MoedSpace.s12) {
                // Heure d'allumage : chiffres LTR + tabular, flamme pleine.
                ForceLTR {
                    Text(MoedFmt.time(shabbat.candleLighting, tz: timeZone))
                        .font(MoedFont.hero(lang))
                        .monospacedDigit()
                        .foregroundStyle(MoedColor.ner)
                }
                Text(L10n.t("home.candleLighting", lang))
                    .font(MoedFont.micro(lang))
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .foregroundStyle(MoedColor.inkMute)
                    .accessibilityHidden(true)
            }

            // Compte à rebours live dans une capsule verre flottante.
            CountdownCapsule(
                target: shabbat.candleLighting,
                now: now,
                label: L10n.t("home.candleLightingIn", lang),
                icon: "flame.fill"
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(L10n.t("home.candleLighting", lang)) \(MoedFmt.time(shabbat.candleLighting, tz: timeZone))"
        )
    }

    private func havdalaLine(_ havdalah: Date) -> some View {
        HStack(spacing: MoedSpace.s8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundStyle(MoedColor.twilight)
                .accessibilityHidden(true)
            Text(L10n.t("home.havdalah", lang))
                .font(MoedFont.callout(lang))
                .foregroundStyle(MoedColor.twilight)
            ForceLTR {
                Text(MoedFmt.time(havdalah, tz: timeZone))
                    .font(MoedFont.callout(lang))
                    .monospacedDigit()
                    .foregroundStyle(MoedColor.twilight)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
