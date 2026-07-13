//
//  TsadikDetailView.swift
//  Moed — Fiche détail d'un tsadik (SPEC §2.4, DESIGN §5.4)
//
//  Poussée par `TsadikimView` (route `tsadikim/[slug]`, navigation par valeur).
//  Affiche : nom (langue active), épithète, catégorie, date de hiloula (+ note),
//  PROCHAINE hiloula (date grégorienne calculée offline), kever (lieu/pays),
//  œuvres, biographie longue, BADGE DE CONFIANCE (high/medium/traditional →
//  sage/ner/inkMute), SOURCES cliquables (→ `openURL`) et la note sur le visuel
//  symbolique (aucun portrait inventé).
//
//  Calcul « prochaine hiloula » : conversion hébreu→grégorien via le moteur
//  déterministe (`HebrewDateEngine.toGregorian`), en repartant de l'année
//  hébraïque courante. Gestion CORRECTE des années embolismiques (Adar / Adar II)
//  et de la numérotation Nisan-based du moteur (miroir de `StaticData`). 100 %
//  hors-ligne, aucun réseau au runtime.
//
//  RTL hébreu : direction posée à la racine ; les motifs/flamme ne sont JAMAIS
//  miroités, seuls les chevrons/flèches le sont ; les nombres (dates) restent
//  lisibles via le formatage localisé.
//

import Foundation
import SwiftUI

struct TsadikDetailView: View {

    let tsadik: Tsadik

    @Environment(AppState.self) private var appState
    @Environment(\.moedLang) private var lang
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MoedSpace.s24) {
                heroHeader
                hilulaCard
                if tsadik.kever != nil { keverCard }
                if let works = tsadik.works, !works.isEmpty { worksCard(works) }
                bioCard
                confidenceCard
                if !tsadik.sources.isEmpty { sourcesCard }
                visualNote
            }
            .padding(.horizontal, MoedSpace.pagePadding)
            .padding(.top, MoedSpace.s8)
            .padding(.bottom, MoedSpace.s40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(tsadik.names(lang))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - En-tête (motif symbolique + nom + épithète + catégorie)

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s16) {
            TsadikMotif(category: tsadik.category, size: nil)
                .frame(maxHeight: 180)

            VStack(alignment: .leading, spacing: MoedSpace.s8) {
                Text(tsadik.names(lang))
                    .font(MoedFont.title1(lang))
                    .foregroundStyle(MoedColor.ink)
                    .hebrewBalanced(lang)
                    .fixedSize(horizontal: false, vertical: true)

                if let epithet = tsadik.epithet {
                    Text(epithet(lang))
                        .font(MoedFont.title3(lang))
                        .foregroundStyle(MoedColor.inkSoft)
                        .hebrewBalanced(lang)
                }

                HStack(spacing: MoedSpace.s8) {
                    Badge(text: tsadik.category.label(lang), style: .neutral, showsIcon: false)
                    if let year = tsadik.yearGregorian {
                        Badge(text: gregorianYearLabel(year), style: .neutral, showsIcon: false)
                    }
                }
                .padding(.top, MoedSpace.s2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Carte hiloula (date + note + prochaine hiloula)

    private var hilulaCard: some View {
        SectionCard(title: L10n.t("tsadikim.hilulaDate", lang)) {
            VStack(alignment: .leading, spacing: MoedSpace.s12) {
                infoRow(symbol: "flame.fill", tint: MoedColor.ner) {
                    VStack(alignment: leadingAlign, spacing: MoedSpace.s4) {
                        Text(hilulaHebrewText)
                            .font(MoedFont.bodyEmph(lang))
                            .foregroundStyle(MoedColor.ink)
                            .hebrewBalanced(lang)
                        if let note = tsadik.hilulaNote {
                            Badge(text: note(lang), style: .festival)
                        }
                    }
                }

                CardDivider()

                infoRow(symbol: "calendar", tint: MoedColor.twilight) {
                    VStack(alignment: leadingAlign, spacing: MoedSpace.s2) {
                        Text(L10n.t("tsadikim.nextHilula", lang))
                            .font(MoedFont.caption(lang))
                            .foregroundStyle(MoedColor.inkMute)
                            .hebrewBalanced(lang)
                        Text(nextHilulaText)
                            .font(MoedFont.bodyEmph(lang))
                            .foregroundStyle(MoedColor.ink)
                            .hebrewBalanced(lang)
                    }
                }
            }
        }
    }

    // MARK: - Kever

    private var keverCard: some View {
        SectionCard(title: L10n.t("tsadikim.kever", lang)) {
            infoRow(symbol: "mappin.and.ellipse", tint: MoedColor.sage) {
                VStack(alignment: leadingAlign, spacing: MoedSpace.s2) {
                    if let kever = tsadik.kever {
                        Text(kever.place)
                            .font(MoedFont.bodyEmph(lang))
                            .foregroundStyle(MoedColor.ink)
                            .hebrewBalanced(lang)
                        Text(kever.country)
                            .font(MoedFont.callout(lang))
                            .foregroundStyle(MoedColor.inkSoft)
                            .hebrewBalanced(lang)
                    }
                }
            }
        }
    }

    // MARK: - Œuvres

    private func worksCard(_ works: [String]) -> some View {
        SectionCard(title: L10n.t("tsadikim.works", lang)) {
            VStack(alignment: .leading, spacing: MoedSpace.s8) {
                ForEach(Array(works.enumerated()), id: \.offset) { _, work in
                    HStack(alignment: .firstTextBaseline, spacing: MoedSpace.s8) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(MoedColor.ner)
                            .accessibilityHidden(true)
                        Text(work)
                            .font(MoedFont.body(lang))
                            .foregroundStyle(MoedColor.inkSoft)
                            .hebrewBalanced(lang)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Biographie longue (texte sélectionnable)

    private var bioCard: some View {
        SectionCard {
            // Alignement `.leading` : miroité automatiquement en RTL hébreu
            // (la racine pose `layoutDirection = .rightToLeft`).
            Text(tsadik.bio(lang))
                .font(MoedFont.body(lang))
                .foregroundStyle(MoedColor.inkSoft)
                .hebrewBalanced(lang)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    // MARK: - Badge de confiance

    private var confidenceCard: some View {
        let style = ConfidenceStyle.of(tsadik.confidence)
        return SectionCard(title: L10n.t("tsadikim.confidence", lang)) {
            HStack(spacing: MoedSpace.s8) {
                Image(systemName: style.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(style.color)
                    .accessibilityHidden(true)
                Text(L10n.t(style.labelKey, lang))
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(style.color)
                    .hebrewBalanced(lang)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MoedSpace.s12)
            .padding(.vertical, MoedSpace.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.wash, in: Capsule(style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Sources cliquables

    private var sourcesCard: some View {
        SectionCard(title: L10n.t("tsadikim.sources", lang)) {
            VStack(alignment: .leading, spacing: MoedSpace.s8) {
                ForEach(Array(tsadik.sources.enumerated()), id: \.offset) { _, source in
                    if let url = URL(string: source) {
                        Button {
                            openURL(url)
                        } label: {
                            HStack(spacing: MoedSpace.s8) {
                                Image(systemName: "link")
                                    .font(.system(size: 12, weight: .semibold))
                                    .accessibilityHidden(true)
                                Text(sourceLabel(url))
                                    .font(MoedFont.callout(lang))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.forward")
                                    .directionalMirror()
                                    .font(.system(size: 11, weight: .semibold))
                                    .accessibilityHidden(true)
                            }
                            .foregroundStyle(MoedColor.twilight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(sourceLabel(url)))
                        .accessibilityAddTraits(.isLink)
                    }
                }
            }
        }
    }

    // MARK: - Note sur le visuel symbolique

    private var visualNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: MoedSpace.s8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(MoedColor.inkMute)
                .accessibilityHidden(true)
            Text(L10n.t("tsadikim.visualNote", lang))
                .font(MoedFont.caption(lang))
                .foregroundStyle(MoedColor.inkMute)
                .hebrewBalanced(lang)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, MoedSpace.s4)
    }

    // MARK: - Ligne d'info générique (icône + contenu)

    private var leadingAlign: HorizontalAlignment { .leading }

    @ViewBuilder
    private func infoRow<Content: View>(
        symbol: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: MoedSpace.s12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            content()
            Spacer(minLength: 0)
        }
    }

    // MARK: - Textes dérivés (localisés, offline)

    /// « 18 Iyyar » / « י״ח אייר » — jour + nom de mois de la hiloula.
    private var hilulaHebrewText: String {
        let monthLoc = hebrewMonthName(tsadik.hilula.month, lang: lang)
        switch lang {
        case .he:
            return "\(hebrewDayLetters(tsadik.hilula.day)) \(monthLoc)"
        case .fr, .en:
            return "\(tsadik.hilula.day) \(monthLoc)"
        }
    }

    /// Date grégorienne de la prochaine hiloula, localisée, ou « — » si absente.
    private var nextHilulaText: String {
        guard let date = nextHilulaDate else { return "—" }
        return Self.longDateFormatter(lang: lang).string(from: date)
    }

    /// Étiquette de source lisible (Wikipedia / Sefaria / hôte).
    private func sourceLabel(_ url: URL) -> String {
        let host = (url.host ?? url.absoluteString).replacingOccurrences(of: "www.", with: "")
        if host.contains("wikipedia") { return "Wikipedia" }
        if host.contains("sefaria") { return "Sefaria" }
        if host.contains("chabad") { return "Chabad.org" }
        return host
    }

    private func gregorianYearLabel(_ year: Int) -> String {
        // Années négatives = ère « avant l'ère commune ».
        year < 0 ? "\(-year) \(bceSuffix)" : "\(year)"
    }

    private var bceSuffix: String {
        switch lang {
        case .he: return "לפנה״ס"
        case .fr: return "av. è.c."
        case .en: return "BCE"
        }
    }

    // MARK: - Calcul « prochaine hiloula » (hébreu → grégorien, offline)

    /// Prochaine occurrence grégorienne (aujourd'hui inclus) de la hiloula, en
    /// repartant de l'année hébraïque courante et en avançant si besoin.
    private var nextHilulaDate: Date? {
        let currentHebrewYear = appState.today().hebrew.year
        let todayStart = Calendar(identifier: .gregorian).startOfDay(for: appState.now)

        // On sonde l'année courante puis les suivantes (garde-fou : 3 ans, large).
        for offset in 0...2 {
            let year = currentHebrewYear + offset
            let leap = Self.isHebrewLeapYear(year)
            guard let month = Self.hebrewMonthNumber(dataName: tsadik.hilula.month, leap: leap),
                  let gregorian = HebrewDateEngine.toGregorian(
                    year: year, month: month, day: tsadik.hilula.day
                  )
            else { continue }

            if gregorian >= todayStart { return gregorian }
        }
        return nil
    }

    // MARK: - Formateur de date (mémoïsé)

    private static var dateCache: [String: DateFormatter] = [:]

    private static func longDateFormatter(lang: Lang) -> DateFormatter {
        if let f = dateCache[lang.bcp47] { return f }
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.bcp47)
        f.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        dateCache[lang.bcp47] = f
        return f
    }

    // MARK: - Calendrier hébraïque (correction embolismique)

    /// Année embolismique (13 mois) selon le cycle métonique de 19 ans :
    /// années 3, 6, 8, 11, 14, 17, 19 du cycle. Formule standard KosherJava.
    static func isHebrewLeapYear(_ year: Int) -> Bool {
        ((7 * year + 1) % 19) < 7
    }

    /// Numéro de mois Nisan-based (1…13) attendu par `HebrewDateEngine.toGregorian`,
    /// à partir du nom translittéré EN du dataset. Miroir de `StaticData.dataMonthName`.
    ///
    /// Corrections embolismiques :
    ///  • En année ordinaire, un mois « Adar II » (13, inexistant) retombe sur
    ///    l'unique Adar (12).
    ///  • « Adar » vaut 12 dans les deux cas — en année embolismique c'est Adar I,
    ///    conformément à la parité de `hilulotToday` (une hiloula « Adar » se
    ///    commémore en Adar I).
    static func hebrewMonthNumber(dataName name: String, leap: Bool) -> Int? {
        let maxMonth = leap ? 13 : 12
        for m in 1...maxMonth where StaticData.dataMonthName(forHebrewMonth: m) == name {
            return m
        }
        // Repli embolismique : « Adar II » demandé dans une année ordinaire.
        if !leap, name == "Adar II" { return 12 }
        // Tolérance dataset : orthographe « Adar I » explicite.
        if name == "Adar I" { return 12 }
        return nil
    }

    // MARK: - Rendu hébreu du jour / mois (fiche `he`)

    /// Nom de mois localisé pour l'affichage de la date de hiloula.
    /// `fr`/`en` → translittération EN du dataset (déjà lisible) ;
    /// `he` → nom hébreu correspondant.
    private func hebrewMonthName(_ dataName: String, lang: Lang) -> String {
        guard lang == .he else { return dataName }
        return Self.hebrewMonthDisplay[dataName] ?? dataName
    }

    private static let hebrewMonthDisplay: [String: String] = [
        "Nisan": "ניסן", "Iyyar": "אייר", "Sivan": "סיוון", "Tammuz": "תמוז",
        "Av": "אב", "Elul": "אלול", "Tishrei": "תשרי", "Cheshvan": "חשוון",
        "Kislev": "כסלו", "Tevet": "טבת", "Shevat": "שבט",
        "Adar": "אדר", "Adar I": "אדר א׳", "Adar II": "אדר ב׳",
    ]

    /// Lettres hébraïques d'un quantième de mois (1…30), gershayim inclus.
    /// Ex. 15 → « ט״ו », 18 → « י״ח » (jamais « יה/יו » — usage religieux).
    private func hebrewDayLetters(_ day: Int) -> String {
        guard (1...30).contains(day) else { return String(day) }
        let ones = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
        let tens = ["", "י", "כ", "ל"]                    // 10, 20, 30
        // Exceptions religieuses : 15 = ט״ו (9+6), 16 = ט״ז (9+7) — on n'écrit
        // pas le Nom (יה / יו).
        if day == 15 { return "ט״ו" }
        if day == 16 { return "ט״ז" }
        let letters = "\(tens[day / 10])\(ones[day % 10])"
        // Insère les gershayim (guillemet hébreu) avant la dernière lettre si ≥ 2.
        if letters.count >= 2 {
            let idx = letters.index(before: letters.endIndex)
            return "\(letters[letters.startIndex..<idx])״\(letters[idx])"
        } else if letters.count == 1 {
            return "\(letters)׳"                          // geresh sur lettre unique
        }
        return String(day)
    }
}

// MARK: - Style du badge de confiance (high/medium/traditional)

/// Palette sémantique du niveau de fiabilité de la date (DESIGN §5.4) :
/// high → `sage`, medium → `ner`, traditional → `inkMute`.
struct ConfidenceStyle {
    let color: Color
    let wash: Color
    let symbol: String
    let labelKey: String

    static func of(_ confidence: Confidence) -> ConfidenceStyle {
        switch confidence {
        case .high:
            return .init(color: MoedColor.sage, wash: MoedColor.sageWash,
                         symbol: "checkmark.seal.fill", labelKey: "tsadikim.confHigh")
        case .medium:
            return .init(color: MoedColor.nerStrong, wash: MoedColor.nerWash,
                         symbol: "seal.fill", labelKey: "tsadikim.confMedium")
        case .traditional:
            return .init(color: MoedColor.inkMute, wash: MoedColor.surfaceDeep,
                         symbol: "book.closed.fill", labelKey: "tsadikim.confTraditional")
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Fiche tsadik") {
    NavigationStack {
        TsadikDetailView(
            tsadik: StaticData.tsadikim.first ?? .preview
        )
    }
    .environment(AppState())
    .environment(\.moedLang, .fr)
    .preferredColorScheme(.light)
}

private extension Tsadik {
    /// Fiche de secours pour la preview si le dataset n'est pas résolu.
    static var preview: Tsadik {
        Tsadik(
            slug: "rashbi",
            names: LocalizedText(he: "רבי שמעון בר יוחאי", fr: "Rabbi Shimon bar Yohaï", en: "Rabbi Shimon bar Yochai"),
            epithet: LocalizedText(he: "רשב\"י", fr: "Rachbi", en: "Rashbi"),
            category: .tanna,
            hilula: HilulaDate(day: 18, month: "Iyyar"),
            hilulaNote: LocalizedText(he: "ל\"ג בעומר", fr: "Lag BaOmer", en: "Lag BaOmer"),
            yearGregorian: 160,
            kever: Kever(place: "Meron", country: "Israël"),
            works: ["Zohar"],
            bio: LocalizedText(he: "…", fr: "Tanna de la génération de Rabbi Akiva…", en: "Tanna of Rabbi Akiva's generation…"),
            confidence: .traditional,
            sources: ["https://en.wikipedia.org/wiki/Simeon_bar_Yochai"]
        )
    }
}
#endif
