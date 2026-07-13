//
//  TsadikimView.swift
//  Moed — Écran « Tsadikim » (SPEC §2.4, DESIGN §5.4)
//
//  Hiloula du jour + répertoire. Porte SON propre `NavigationStack` (CONTRACTS
//  §4.1) et pousse `TsadikDetailView` en détail (navigation par valeur `Tsadik`).
//
//  Structure verticale (scroll) :
//    1. En-tête « Hiloulot » (titre + sous-titre).
//    2. Section « Hiloula du jour » : tsadikim dont `hilula` == date hébraïque
//       COURANTE (via `StaticData.hilulotToday`). Cartes `cardSolid` avec visuel
//       SYMBOLIQUE par catégorie (`TsadikMotif`) — JAMAIS de portrait
//       (exigence éditoriale). État vide si personne aujourd'hui.
//    3. Répertoire complet : grille 2 colonnes, vignette motif + nom trilingue
//       + épithète, chaque cellule pousse la fiche détail.
//
//  DA : contenu de LECTURE sur surface opaque (`SectionCard` / `cardSolid`),
//  jamais de verre sous le contenu (le verre = chrome/TabBar uniquement). RTL
//  hébreu géré par la direction posée à la racine ; motifs & flamme JAMAIS
//  miroités. Calcul 100 % offline & déterministe (date hébraïque du moteur).
//

import SwiftUI

struct TsadikimView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.moedLang) private var lang

    /// Grille répertoire : 2 colonnes fluides, gouttière = interCard.
    private let columns = [
        GridItem(.flexible(), spacing: MoedSpace.s16),
        GridItem(.flexible(), spacing: MoedSpace.s16),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MoedSpace.s24) {
                    header
                    hilulotTodaySection
                    directorySection
                }
                .padding(.horizontal, MoedSpace.pagePadding)
                .padding(.top, MoedSpace.s8)
                .padding(.bottom, MoedSpace.s40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle(L10n.t("tsadikim.title", lang))
            .navigationBarTitleDisplayMode(.inline)
            // Détail poussé par valeur (Tsadik est Hashable — CONTRACTS §3.3).
            .navigationDestination(for: Tsadik.self) { tsadik in
                TsadikDetailView(tsadik: tsadik)
            }
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s4) {
            Text(L10n.t("tsadikim.title", lang))
                .font(MoedFont.hero(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .accessibilityAddTraits(.isHeader)
            Text(L10n.t("tsadikim.subtitle", lang))
                .font(MoedFont.callout(lang))
                .foregroundStyle(MoedColor.inkSoft)
                .hebrewBalanced(lang)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hiloula du jour

    /// Date hébraïque COURANTE via la façade `AppState.today()` (source unique de
    /// vérité, gère déjà la bascule après le coucher du soleil) — puis filtre
    /// déterministe hors-ligne du dataset embarqué.
    private var hilulotToday: [Tsadik] {
        StaticData.hilulotToday(hebrew: appState.today().hebrew)
    }

    @ViewBuilder
    private var hilulotTodaySection: some View {
        let today = hilulotToday
        VStack(alignment: .leading, spacing: MoedSpace.s12) {
            sectionLabel(L10n.t("tsadikim.todayTitle", lang), symbol: "flame.fill")

            if today.isEmpty {
                emptyToday
            } else {
                ForEach(today) { tsadik in
                    NavigationLink(value: tsadik) {
                        HilulaTodayCard(tsadik: tsadik)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyToday: some View {
        SectionCard {
            HStack(spacing: MoedSpace.s12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(MoedColor.inkMute)
                    .accessibilityHidden(true)
                Text(L10n.t("tsadikim.noneToday", lang))
                    .font(MoedFont.body(lang))
                    .foregroundStyle(MoedColor.inkSoft)
                    .hebrewBalanced(lang)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Répertoire complet (grille 2 colonnes)

    private var directorySection: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s12) {
            sectionLabel(L10n.t("tsadikim.allTitle", lang), symbol: "square.grid.2x2.fill")

            LazyVGrid(columns: columns, spacing: MoedSpace.s16) {
                ForEach(StaticData.tsadikim) { tsadik in
                    NavigationLink(value: tsadik) {
                        DirectoryCell(tsadik: tsadik)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Libellé de section (micro + filet)

    private func sectionLabel(_ text: String, symbol: String) -> some View {
        HStack(spacing: MoedSpace.s8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MoedColor.ner)
                .accessibilityHidden(true)
            Text(text.uppercased())
                .font(MoedFont.micro(lang))
                .tracking(lang == .he ? 0 : 0.88)          // tracking hébreu = 0 (DESIGN §3.1)
                .foregroundStyle(MoedColor.inkMute)
                .hebrewBalanced(lang)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Carte « Hiloula du jour » (cardSolid, bio courte)

private struct HilulaTodayCard: View {

    let tsadik: Tsadik
    @Environment(\.moedLang) private var lang

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: MoedSpace.s12) {
                HStack(alignment: .top, spacing: MoedSpace.s16) {
                    TsadikMotif(category: tsadik.category, size: 64)

                    VStack(alignment: .leading, spacing: MoedSpace.s4) {
                        Text(tsadik.names(lang))
                            .font(MoedFont.title3(lang))
                            .foregroundStyle(MoedColor.ink)
                            .hebrewBalanced(lang)
                            .fixedSize(horizontal: false, vertical: true)

                        if let epithet = tsadik.epithet {
                            Text(epithet(lang))
                                .font(MoedFont.callout(lang))
                                .foregroundStyle(MoedColor.inkSoft)
                                .hebrewBalanced(lang)
                        }

                        if let note = tsadik.hilulaNote {
                            Badge(text: note(lang), style: .festival)
                                .padding(.top, MoedSpace.s2)
                        }
                    }
                    Spacer(minLength: 0)

                    // Chevron « voir la fiche » — DIRECTIONNEL → miroité en RTL.
                    // `directionalMirror()` s'applique sur l'`Image` (avant tout
                    // autre modifier qui la transformerait en `View`).
                    Image(systemName: "chevron.forward")
                        .directionalMirror()
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MoedColor.inkMute)
                        .accessibilityHidden(true)
                }

                // Amorce de biographie (2 lignes) — la fiche donne le texte complet.
                // Alignement naturel `.leading` : miroité automatiquement en RTL
                // (la racine pose `layoutDirection = .rightToLeft` en hébreu).
                Text(tsadik.bio(lang))
                    .font(MoedFont.body(lang))
                    .foregroundStyle(MoedColor.inkSoft)
                    .hebrewBalanced(lang)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Cellule de répertoire (grille 2 colonnes)

private struct DirectoryCell: View {

    let tsadik: Tsadik
    @Environment(\.moedLang) private var lang

    var body: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s12) {
            TsadikMotif(category: tsadik.category, size: nil)   // remplit la largeur

            VStack(alignment: .leading, spacing: MoedSpace.s2) {
                Text(tsadik.names(lang))
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let epithet = tsadik.epithet {
                    Text(epithet(lang))
                        .font(MoedFont.caption(lang))
                        .foregroundStyle(MoedColor.inkMute)
                        .hebrewBalanced(lang)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(MoedSpace.cardPaddingCompact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoedColor.surface, in: MoedRadius.shape(MoedRadius.md))
        .overlay(MoedRadius.shape(MoedRadius.md).strokeBorder(MoedColor.lineStrong, lineWidth: 1))
        .moedElevation(.e1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(tsadik.names(lang)))
    }
}

// MARK: - Motif SYMBOLIQUE par catégorie (jamais de portrait — DESIGN §5.4)

/// Emblème visuel abstrait, dérivé UNIQUEMENT de la catégorie (courant / époque).
/// Aucune image de personne : un glyphe SF non figuratif sur un lavis coloré.
/// Icône non directionnelle → JAMAIS miroitée en RTL.
struct TsadikMotif: View {

    let category: TsadikCategory
    /// Côté carré fixe (cartes) ; `nil` → carré fluide qui remplit la largeur (grille).
    var size: CGFloat?

    private var palette: TsadikVisual { TsadikVisual.of(category) }

    var body: some View {
        ZStack {
            // Lavis de fond doux, diagonale aube.
            LinearGradient(
                colors: [palette.wash, palette.wash.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Glyphe fantôme décoratif (grand, très atténué) → texture d'emblème.
            Image(systemName: palette.glyph)
                .font(.system(size: (size ?? 120) * 0.9, weight: .regular))
                .foregroundStyle(palette.accent.opacity(0.10))
                .offset(x: (size ?? 120) * 0.22, y: (size ?? 120) * 0.20)
                .accessibilityHidden(true)

            // Glyphe principal net, centré.
            Image(systemName: palette.glyph)
                .font(.system(size: (size ?? 120) * 0.42, weight: .semibold))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: size == nil ? .infinity : size)
        .aspectRatio(size == nil ? 1 : nil, contentMode: .fit)
        .clipShape(MoedRadius.shape(MoedRadius.sm))
        .overlay(MoedRadius.shape(MoedRadius.sm).strokeBorder(palette.accent.opacity(0.18), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

// MARK: - Palette & sémantique visuelle d'une catégorie

/// Table figée (glyphe symbolique + couleurs de lavis/accent) par courant.
/// Réutilise EXCLUSIVEMENT les tokens `MoedColor` (couleur = signal, jamais déco).
struct TsadikVisual {
    let glyph: String
    let accent: Color
    let wash: Color

    static func of(_ category: TsadikCategory) -> TsadikVisual {
        switch category {
        case .tanna:    return .init(glyph: "scroll.fill",           accent: MoedColor.nerStrong, wash: MoedColor.nerWash)
        case .rishon:   return .init(glyph: "book.closed.fill",      accent: MoedColor.twilight,  wash: MoedColor.twilightWash)
        case .acharon:  return .init(glyph: "books.vertical.fill",   accent: MoedColor.sage,      wash: MoedColor.sageWash)
        case .hassid:   return .init(glyph: "flame.fill",            accent: MoedColor.nerStrong, wash: MoedColor.nerWash)
        case .habad:    return .init(glyph: "seal.fill",             accent: MoedColor.twilight,  wash: MoedColor.twilightWash)
        case .sefarade: return .init(glyph: "moon.stars.fill",       accent: MoedColor.sage,      wash: MoedColor.sageWash)
        }
    }
}

// MARK: - Nom localisé de catégorie (aucune clé i18n dédiée → table locale)

extension TsadikCategory {
    /// Libellé trilingue du courant/époque (parité éditoriale web).
    func label(_ lang: Lang) -> String {
        switch (self, lang) {
        case (.tanna, .he):    return "תנא"
        case (.tanna, _):      return "Tanna"
        case (.rishon, .he):   return "ראשון"
        case (.rishon, .fr):   return "Rishon"
        case (.rishon, .en):   return "Rishon"
        case (.acharon, .he):  return "אחרון"
        case (.acharon, .fr):  return "Aharon"
        case (.acharon, .en):  return "Acharon"
        case (.hassid, .he):   return "חסידות"
        case (.hassid, .fr):   return "Hassidique"
        case (.hassid, .en):   return "Hasidic"
        case (.habad, .he):    return "חב״ד"
        case (.habad, _):      return "Habad"
        case (.sefarade, .he): return "ספרדי"
        case (.sefarade, .fr): return "Séfarade"
        case (.sefarade, .en): return "Sephardic"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Tsadikim") {
    TsadikimView()
        .environment(AppState())
        .environment(\.moedLang, .fr)
        .preferredColorScheme(.light)
}
#endif
