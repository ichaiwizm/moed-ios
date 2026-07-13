//
//  EmptyStateView.swift
//  Moed — Components (transverses, sans état)
//
//  État vide illustré (DESIGN §5.4 : carnet familial vide, hiloula « personne aujourd'hui »,
//  recherche sans résultat). Illustration symbolique + titre + message + CTA optionnel
//  (capsule pleine `ner → nerStrong` au press, texte `surface`).
//
//  Stateless : contenu et action injectés par l'appelant (déjà localisés).
//

import SwiftUI

struct EmptyStateView: View {

    /// Nom d'asset d'illustration (ex. « empty.family »). Fallback SF Symbol si absent via `systemFallback`.
    var illustration: String? = nil
    /// SF Symbol de secours (toujours rendu si `illustration` est nil) — non directionnel.
    var systemFallback: String = "sparkles"
    let title: String
    var message: String? = nil
    /// Libellé du CTA. Si nil (ou action nil) : pas de bouton.
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.moedLang) private var lang
    @State private var taps = 0

    var body: some View {
        VStack(spacing: MoedSpace.s16) {
            illustrationView

            VStack(spacing: MoedSpace.s8) {
                Text(title)
                    .font(MoedFont.title3(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .font(MoedFont.callout(lang))
                        .foregroundStyle(MoedColor.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle, let action {
                Button {
                    taps &+= 1
                    action()
                } label: {
                    Text(actionTitle)
                        .font(MoedFont.bodyEmph(lang))
                        .foregroundStyle(MoedColor.surface)
                        .padding(.horizontal, MoedSpace.s24)
                        .padding(.vertical, MoedSpace.s12)
                        .background(MoedColor.ner, in: Capsule(style: .continuous))
                }
                .buttonStyle(PressableCapsuleStyle())
                .haptic(.selection, trigger: taps)
                .padding(.top, MoedSpace.s4)
                .accessibilityLabel(actionTitle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(MoedSpace.s32)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var illustrationView: some View {
        Group {
            if let illustration {
                Image(illustration)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: systemFallback)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(MoedColor.inkMute)
            }
        }
        .frame(maxWidth: 120, maxHeight: 120)
        .opacity(0.9)
        .accessibilityHidden(true)
    }
}

/// Bouton capsule : teinte `nerStrong` au press (DESIGN §5.5), retour `.snappy`.
private struct PressableCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? MoedColor.nerStrong : Color.clear,
                in: Capsule(style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.96 : 1.0)
            .animation(.snappy(duration: 0.22), value: configuration.isPressed)
    }
}
