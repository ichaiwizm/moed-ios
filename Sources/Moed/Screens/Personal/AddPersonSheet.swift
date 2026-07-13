//
//  AddPersonSheet.swift
//  Moed — Screens / Personal
//
//  Feuille d'ajout d'un proche au carnet familial (DESIGN §5.5, SPEC §2.3).
//  Segmented type (Anniversaire / Yahrzeit), champ nom (`cardInset`), DatePicker
//  `.graphical`, toggle « après le coucher du soleil » (ancre correctement la
//  date hébraïque), bouton de validation capsule flamme (`ner` → `nerStrong` au
//  press), haptique de succès à l'ajout.
//
//  Présentée en `.sheet` avec `.presentationDetents([.medium, .large])`, fond
//  `glassSheet` (material régulier), coins `radiusLg`, poignée visible
//  (CONTRACTS §4.1 / DESIGN §5.5).
//
//  Produit un `PersonRecord` (CONTRACTS §1.5) et le confie à l'API contractuelle
//  `AppState.addPerson(_:)` (persiste on-device + replanifie les notifs). Le
//  calcul des occurrences hébraïques est fait en aval par le moteur — cette
//  feuille ne calcule rien : elle ne fait que SAISIR la date grégorienne
//  d'origine + le flag `afterSunset`.
//

import SwiftUI

/// Formulaire d'ajout d'un proche (anniversaire hébraïque ou yahrzeit).
struct AddPersonSheet: View {

    @Environment(AppState.self) private var app
    @Environment(\.moedLang) private var lang
    @Environment(\.dismiss) private var dismiss

    // Saisie
    @State private var type: PersonType = .yahrzeit
    @State private var name: String = ""
    @State private var date: Date = Date()
    @State private var afterSunset: Bool = false

    /// Déclencheur d'haptique de succès (change une fois l'ajout confirmé).
    @State private var savedTick = 0

    @FocusState private var nameFocused: Bool

    /// L'ajout est possible dès qu'un nom non vide est saisi (la date est toujours
    /// valide — issue d'un `DatePicker`, jamais d'une saisie libre).
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Libellé du champ date selon le type (décès pour un yahrzeit, naissance sinon).
    private var dateLabelKey: String {
        type == .yahrzeit ? "personal.deathDate" : "personal.birthDate"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MoedSpace.s20) {
                    typeField
                    nameField
                    dateField
                    afterSunsetField
                }
                .padding(.horizontal, MoedSpace.pagePadding)
                .padding(.top, MoedSpace.s8)
                .padding(.bottom, MoedSpace.s24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { saveBar }
            .background(Color.clear)
            .navigationTitle(Text(L10n.t("personal.addTitle", lang)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel", lang)) { dismiss() }
                        .tint(MoedColor.inkSoft)
                }
            }
            // Poignée + material régulier + coins arrondis (DESIGN §5.5).
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(MoedRadius.lg)
            // Haptique de succès à l'ajout (DESIGN §7).
            .haptic(.success, trigger: savedTick)
            // Haptique de sélection au changement de segmented (DESIGN §7).
            .haptic(.selection, trigger: type)
        }
    }

    // MARK: Champs

    // Segmented type — Yahrzeit / Anniversaire, teinté flamme.
    private var typeField: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s8) {
            fieldLabel(L10n.t("personal.type", lang))
            Picker(L10n.t("personal.type", lang), selection: $type) {
                Text(L10n.t("personal.addYahrzeit", lang)).tag(PersonType.yahrzeit)
                Text(L10n.t("personal.addBirthday", lang)).tag(PersonType.birthday)
            }
            .pickerStyle(.segmented)
            .tint(MoedColor.ner)
        }
    }

    // Champ nom — surface enfoncée (`cardInset`), rayon `sm`.
    private var nameField: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s8) {
            fieldLabel(L10n.t("personal.name", lang))
            TextField(L10n.t("personal.name", lang), text: $name)
                .font(MoedFont.body(lang))
                .foregroundStyle(MoedColor.ink)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit { if canSave { save() } }
                .padding(.horizontal, MoedSpace.s12)
                .padding(.vertical, MoedSpace.s12)
                .background {
                    MoedRadius.shape(MoedRadius.sm).fill(MoedColor.surfaceDeep)
                }
                .overlay {
                    MoedRadius.shape(MoedRadius.sm)
                        .strokeBorder(nameFocused ? MoedColor.ner : MoedColor.lineStrong, lineWidth: 1)
                }
        }
    }

    // DatePicker graphique — dates passées uniquement (naissance / décès).
    private var dateField: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s8) {
            fieldLabel(L10n.t(dateLabelKey, lang))
            DatePicker(
                L10n.t(dateLabelKey, lang),
                selection: $date,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(MoedColor.ner)
            .environment(\.locale, Locale(identifier: lang.bcp47))
            .padding(MoedSpace.s8)
            .background {
                MoedRadius.shape(MoedRadius.md).fill(MoedColor.surface)
            }
            .overlay {
                MoedRadius.shape(MoedRadius.md).strokeBorder(MoedColor.line, lineWidth: 1)
            }
        }
    }

    // Toggle « après le coucher du soleil » + explication (ancre la date hébraïque).
    private var afterSunsetField: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s4) {
            Toggle(isOn: $afterSunset) {
                Text(L10n.t("personal.afterSunset", lang))
                    .font(MoedFont.body(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
            }
            .tint(MoedColor.ner)
            Text(afterSunsetHint)
                .font(MoedFont.caption(lang))
                .foregroundStyle(MoedColor.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, MoedSpace.cardPaddingCompact)
        .padding(.vertical, MoedSpace.s12)
        .background {
            MoedRadius.shape(MoedRadius.md).fill(MoedColor.surface)
        }
        .overlay {
            MoedRadius.shape(MoedRadius.md).strokeBorder(MoedColor.line, lineWidth: 1)
        }
    }

    // MARK: Barre de validation (capsule flamme)

    private var saveBar: some View {
        Button(action: save) {
            Text(L10n.t("common.save", lang))
                .font(MoedFont.bodyEmph(lang))
                .foregroundStyle(MoedColor.surface)
        }
        .buttonStyle(NerCapsuleStyle())
        .disabled(!canSave)
        .padding(.horizontal, MoedSpace.pagePadding)
        .padding(.top, MoedSpace.s8)
        .padding(.bottom, MoedSpace.s12)
        .background(.regularMaterial)
    }

    // MARK: Actions

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let record = PersonRecord(
            id: UUID().uuidString,
            type: type,
            name: trimmed,
            date: date,
            afterSunset: afterSunset
        )
        app.addPerson(record)          // persiste on-device + replanifie les notifs
        savedTick &+= 1                // → haptique de succès
        dismiss()
    }

    // MARK: Helpers présentation

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(MoedFont.caption(lang))
            .foregroundStyle(MoedColor.inkSoft)
            .hebrewBalanced(lang)
    }

    /// Explication localisée du flag `afterSunset` (déterministe, hors clés i18n
    /// paramétrées absentes).
    private var afterSunsetHint: String {
        switch lang {
        case .he: return "אם המאורע התרחש אחרי השקיעה, התאריך העברי מתקדם ביום אחד."
        case .fr: return "Si l’événement a eu lieu après le coucher du soleil, la date hébraïque avance d’un jour."
        case .en: return "If the event occurred after sunset, the Hebrew date advances by one day."
        }
    }
}

// MARK: - Style de la capsule de validation (flamme, ner → nerStrong)

/// Capsule pleine largeur : fond `ner` (→ `nerStrong` au press, `lineStrong` si
/// désactivé — DESIGN §5.5), léger enfoncement au toucher. Le fond est porté par
/// le style (et non le label) pour refléter proprement press + état désactivé.
private struct NerCapsuleStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        Body(configuration: configuration)
    }

    private struct Body: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isEnabled) private var isEnabled

        private var fill: Color {
            if !isEnabled { return MoedColor.lineStrong }
            return configuration.isPressed ? MoedColor.nerStrong : MoedColor.ner
        }

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity)
                .padding(.vertical, MoedSpace.s16)
                .background { Capsule().fill(fill) }
                .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
                .animation(.snappy(duration: 0.22), value: configuration.isPressed)
        }
    }
}

#if DEBUG
#Preview("Ajout d'un proche") {
    AddPersonSheet()
        .environment(AppState())
        .environment(\.moedLang, .fr)
        .preferredColorScheme(.light)
}
#endif
