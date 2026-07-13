//
//  CountdownCapsule.swift
//  Moed — Components (transverses, sans état)
//
//  Capsule de compte à rebours flottante (DESIGN §5.2) : `glassFloat` teinté ner,
//  contenu `bodyEmph` tabulaire enveloppé `ForceLTR` (les chiffres restent LTR en RTL).
//  Pulse imperceptible (scale 1.0 ↔ 1.006, 2 s, easeInOut, repeatForever) — figée si Reduce Motion.
//
//  Stateless côté données : `now` et `target` sont fournis par l'appelant (tick 1 s de l'AppState).
//  Le seul `@State` est l'amorce d'animation de la pulse (présentation, non métier).
//

import SwiftUI

struct CountdownCapsule: View {

    /// Instant cible (ex. allumage du Chabbat).
    let target: Date
    /// « Maintenant » piloté par l'AppState (tick 1 s) — jamais un timer interne (déterminisme + widgets).
    let now: Date
    /// Préfixe optionnel (ex. « allumage dans »). Si nil : capsule nue (durée seule).
    var label: String? = nil
    /// Icône flamme (non directionnelle) affichée en tête. nil pour la masquer.
    var icon: String? = "flame.fill"

    @Environment(\.moedLang) private var lang
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pulsing = false

    private var remaining: TimeInterval { target.timeIntervalSince(now) }
    private var reached: Bool { remaining <= 0 }
    private var durationText: String { MoedFmt.countdown(remaining: remaining, lang: lang) }

    var body: some View {
        HStack(spacing: MoedSpace.s8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MoedColor.ner)
                    .accessibilityHidden(true)
            }
            if let label {
                Text(label)
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.inkSoft)
                    .hebrewBalanced(lang)
            }
            // Durée : chiffres LTR + tabular → pas de « saut » à chaque seconde.
            ForceLTR {
                Text(durationText)
                    .font(MoedFont.bodyEmph(lang))
                    .monospacedDigit()
                    .foregroundStyle(MoedColor.nerStrong)
            }
        }
        .padding(.horizontal, MoedSpace.s16)
        .padding(.vertical, MoedSpace.s8)
        // Verre flottant teinté flamme — c'est du chrome/contrôle, autorisé (DESIGN §4.2).
        .glass(.float, tint: MoedColor.ner.opacity(0.14))
        .clipShape(Capsule(style: .continuous))
        .scaleEffect(pulsing ? 1.006 : 1.0)
        .onAppear(perform: startPulse)
        .onChange(of: reduceMotion) { _, reduce in
            if reduce { pulsing = false } else { startPulse() }
        }
        .accessibilityElement(children: .ignore)
        // VoiceOver : annonce à la minute (throttle géré par le rythme de rafraîchissement de la vue).
        .accessibilityLabel(accessibilityText)
    }

    private func startPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }

    private var accessibilityText: String {
        if reached { return label ?? durationText }
        if let label { return "\(label) \(durationText)" }
        return durationText
    }
}
