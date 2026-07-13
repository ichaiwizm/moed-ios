//
//  TodayView.swift
//  Moed — Écran « Aujourd'hui » (dashboard du jour, l'écran le plus riche)
//
//  Réf. produit : NATIVE_SPEC §2.1 ; DA : DESIGN §5.1-5.3, motion §6, RTL §8.
//  Contrat consommé (gelé, CONTRACTS.md) :
//    • Store   : AppState.today() -> TodayModel, AppState.now (tick 1 s), .lang
//    • Modèles : TodayModel / ShabbatModel / Zman / HebrewDateResult / …
//    • Design  : MoedColor, MoedFont(+.hebrewBalanced), MoedSpace, MoedRadius,
//                MoedElevation, .glass(_:tint:), ForceLTR, .directionalMirror(),
//                Haptic(+.haptic), \.moedLang
//    • i18n    : L10n.t
//
//  Ce fichier ne dépend QUE des APIs gelées ci-dessus. Les sous-vues de
//  présentation propres à l'écran (héros Chabbat, capsule de compte à rebours,
//  ligne de zman, en-tête verre au scroll) sont `private` — donc aucun conflit
//  de nom avec le module `Components` partagé, et zéro dépendance sur une
//  signature non figée. Calcul 100 % offline & synchrone : pas de skeleton,
//  la cascade d'apparition masque l'unique frame de layout (DESIGN §6).
//

import SwiftUI

struct TodayView: View {

    // Navigation déléguée à la racine (garde l'écran autonome & testable).
    var onOpenCityPicker: () -> Void = {}
    var onOpenAllZmanim: () -> Void = {}

    @Environment(AppState.self) private var app
    @Environment(\.moedLang) private var lang
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealed = false
    @State private var showGlassHeader = false

    private let vm = TodayViewModel()
    private static let scrollSpace = "today.scroll"

    var body: some View {
        let model = app.today()
        let now = app.now
        let badges = vm.badges(model, lang: lang)
        let rows = vm.zmanRows(model, lang: lang)
        let disclaimer = L10n.t("zmanim.disclaimer", lang, [
            "shita": vm.tzeitShita(model),
            "min": model.city.candleMinutes,
        ])

        ScrollView {
            VStack(alignment: .leading, spacing: MoedSpace.s20) {

                // 0 — En-tête date (respire directement sur le canvas, pas de carte).
                DateHeaderBlock(
                    model: model, badges: badges, vm: vm, lang: lang,
                    onOpenCityPicker: onOpenCityPicker
                )
                .staggerReveal(0, revealed: revealed, reduceMotion: reduceMotion)

                // 1 — Carte Chabbat (le seul « héros » de l'écran, flamme pleine).
                if let shabbat = model.shabbat {
                    ShabbatHeroBlock(
                        shabbat: shabbat, city: model.city,
                        vm: vm, lang: lang, now: now, reduceMotion: reduceMotion
                    )
                    .staggerReveal(1, revealed: revealed, reduceMotion: reduceMotion)
                }

                // 2 — État jeûne (début/fin par zmanim), si actif.
                if let fast = model.activeFast {
                    FastBlock(
                        fast: fast, title: vm.fastTitle(model, lang: lang),
                        city: model.city, vm: vm, lang: lang
                    )
                    .staggerReveal(2, revealed: revealed, reduceMotion: reduceMotion)
                }

                // 3 — Zmanim clés du jour (contenu lisible, aucun verre).
                ZmanimBlock(
                    rows: rows, disclaimer: disclaimer, lang: lang,
                    onOpenAll: onOpenAllZmanim
                )
                .staggerReveal(3, revealed: revealed, reduceMotion: reduceMotion)

                // 4 — Parasha de la semaine + Daf Yomi du jour.
                ParashaDafBlock(parasha: model.parasha, daf: model.dafYomi, vm: vm, lang: lang)
                    .staggerReveal(4, revealed: revealed, reduceMotion: reduceMotion)
            }
            .padding(.horizontal, MoedSpace.s20)
            .padding(.top, MoedSpace.s8)
            .padding(.bottom, MoedSpace.s40)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Sonde de décalage de scroll (iOS 17 compatible via PreferenceKey) :
            // le minY du contenu dans l'espace du ScrollView décroît au scroll.
            .background(alignment: .top) {
                GeometryReader { g in
                    Color.clear.preference(
                        key: TodayScrollOffsetKey.self,
                        value: g.frame(in: .named(Self.scrollSpace)).minY
                    )
                }
            }
        }
        .coordinateSpace(name: Self.scrollSpace)
        .toolbar(.hidden, for: .navigationBar)
        .onPreferenceChange(TodayScrollOffsetKey.self) { minY in
            let show = minY < -12
            guard show != showGlassHeader else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.35)) {
                showGlassHeader = show
            }
        }
        .overlay(alignment: .top) {
            if showGlassHeader {
                GlassScrollHeader(text: vm.hebrew(model.hebrew, lang: lang), lang: lang)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear { revealed = true }
    }
}

// MARK: - En-tête date

private struct DateHeaderBlock: View {
    let model: TodayModel
    let badges: [TodayViewModel.BadgeDisplay]
    let vm: TodayViewModel
    let lang: Lang
    let onOpenCityPicker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s4) {
            // Ligne ville (tap → sélecteur de ville en sheet).
            Button(action: onOpenCityPicker) {
                HStack(spacing: MoedSpace.s4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MoedColor.ner)          // icône non directionnelle → jamais miroitée
                    Text(model.city.names(lang))
                        .font(MoedFont.bodyEmph(lang))
                        .foregroundStyle(MoedColor.inkSoft)
                }
                .contentShape(Rectangle())
                .frame(minHeight: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.city.names(lang))
            .accessibilityHint(L10n.t("common.changeCity", lang))

            // Date hébraïque (Display, langue active, RTL pour l'hébreu).
            Text(vm.hebrew(model.hebrew, lang: lang))
                .font(MoedFont.title1(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .fixedSize(horizontal: false, vertical: true)

            // Date grégorienne.
            Text(vm.gregorian(model.gregorian, tz: model.city.tz, lang: lang))
                .font(MoedFont.callout(lang))
                .foregroundStyle(MoedColor.inkMute)

            // Rangée de badges (Omer / fête / Roch Hodech), wrap flexible, max 3.
            if !badges.isEmpty {
                FlowLayout(spacing: MoedSpace.s8) {
                    ForEach(badges) { HeaderBadge(badge: $0, lang: lang) }
                }
                .padding(.top, MoedSpace.s8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeaderBadge: View {
    let badge: TodayViewModel.BadgeDisplay
    let lang: Lang

    var body: some View {
        let palette: (bg: Color, fg: Color) = {
            switch badge.kind {
            case .omer:        return (MoedColor.sageWash, MoedColor.sage)
            case .holiday:     return (MoedColor.nerWash, MoedColor.nerStrong)
            case .roshchodesh: return (MoedColor.twilightWash, MoedColor.twilight)
            }
        }()
        return HStack(spacing: MoedSpace.s4) {
            Image(systemName: badge.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(badge.text)
                .font(MoedFont.caption(lang))
        }
        .foregroundStyle(palette.fg)
        .padding(.horizontal, MoedSpace.s12)
        .padding(.vertical, 6)
        .background(Capsule().fill(palette.bg))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Carte Chabbat (héros)

private struct ShabbatHeroBlock: View {
    let shabbat: ShabbatModel
    let city: City
    let vm: TodayViewModel
    let lang: Lang
    let now: Date
    let reduceMotion: Bool

    var body: some View {
        let candle = shabbat.candleLighting
        let entered = now >= candle
        let havdala = shabbat.havdalah
        let target = entered ? (havdala ?? candle) : candle
        let heroTime = vm.time(target, tz: city.tz, lang: lang)
        let capsulePrefix = entered
            ? L10n.t("home.havdala", lang)
            : L10n.t("home.candleIn", lang, ["time": ""]).trimmingCharacters(in: .whitespaces)
        let remain = vm.remaining(to: target, now: now)

        let visual = VStack(alignment: .leading, spacing: MoedSpace.s12) {

            // Titre : eyebrow + nom de la parasha.
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: MoedSpace.s4) {
                    Text(L10n.t("home.nextShabbat", lang).uppercased())
                        .font(MoedFont.micro(lang)).tracking(0.8)
                        .foregroundStyle(MoedColor.inkMute)
                    Text(shabbat.parashaName(lang))
                        .font(MoedFont.title3(lang))
                        .foregroundStyle(MoedColor.ink)
                        .hebrewBalanced(lang)
                }
                Spacer(minLength: MoedSpace.s12)
                // Illustration symbolique (bougie) — non directionnelle, halo flamme.
                Image(systemName: "flame.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(MoedColor.ner)
                    .shadow(color: MoedColor.nerGlow.opacity(0.5), radius: 14)
                    .accessibilityHidden(true)
            }

            // Heure d'allumage — héros (hero 40pt, ner, tabular, LTR même en hébreu).
            VStack(alignment: .leading, spacing: MoedSpace.s2) {
                Text(L10n.t("zmanim.candles", lang).uppercased())
                    .font(MoedFont.micro(lang)).tracking(0.8)
                    .foregroundStyle(MoedColor.inkMute)
                ForceLTR {
                    Text(heroTime).font(MoedFont.hero(lang)).monospacedDigit()
                }
                .foregroundStyle(MoedColor.ner)
            }

            // Compte à rebours live dans une capsule verre flottante.
            CountdownPill(
                prefix: capsulePrefix,
                value: vm.countdown(remain),
                lang: lang, reduceMotion: reduceMotion
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(capsulePrefix)
            .accessibilityValue(vm.countdownCoarse(remain, lang: lang))

            // Havdala (ligne discrète, twilight).
            if let havdala {
                Divider().overlay(MoedColor.line)
                HStack(spacing: MoedSpace.s8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15))
                        .foregroundStyle(MoedColor.twilight)
                    Text(L10n.t("home.havdala", lang))
                        .font(MoedFont.callout(lang))
                        .foregroundStyle(MoedColor.inkSoft)
                    Spacer()
                    ForceLTR {
                        Text(vm.time(havdala, tz: city.tz, lang: lang))
                            .monospacedDigit().font(MoedFont.zmanTime(lang))
                    }
                    .foregroundStyle(MoedColor.twilight)
                }
            }
        }
        .padding(MoedSpace.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MoedRadius.lg, style: .continuous)
                .fill(MoedColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MoedRadius.lg, style: .continuous)
                .strokeBorder(MoedColor.lineStrong, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            // Filet de « braise » (nerGlow → ner).
            LinearGradient(colors: [MoedColor.nerGlow, MoedColor.ner],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 3)
                .clipShape(Capsule())
                .padding(.horizontal, MoedSpace.s24)
                .offset(y: -1)
                .accessibilityHidden(true)
        }

        // e2 + glowNer (seul élément à porter la flamme), haptique douce à l'entrée du Chabbat.
        return MoedElevation.glowNer(MoedElevation.e2(visual))
            .haptic(.shabbatEntry, trigger: entered)
    }
}

private struct CountdownPill: View {
    let prefix: String
    let value: String
    let lang: Lang
    let reduceMotion: Bool

    @State private var pulse = false

    var body: some View {
        HStack(spacing: MoedSpace.s8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13))
                .foregroundStyle(MoedColor.ner)
            if !prefix.isEmpty {
                Text(prefix)
                    .font(MoedFont.caption(lang))
                    .foregroundStyle(MoedColor.inkSoft)
            }
            ForceLTR {
                Text(value).monospacedDigit().font(MoedFont.bodyEmph(lang))
            }
            .foregroundStyle(MoedColor.nerStrong)
        }
        .padding(.horizontal, MoedSpace.s12)
        .padding(.vertical, 6)
        .glass(.float, tint: MoedColor.ner.opacity(0.14))
        .scaleEffect(pulse ? 1.006 : 1.0)
        .onAppear {
            guard !reduceMotion else { return }        // pulse figée si Reduce Motion
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - État jeûne

private struct FastBlock: View {
    let fast: FastTiming
    let title: String
    let city: City
    let vm: TodayViewModel
    let lang: Lang

    var body: some View {
        HStack(spacing: MoedSpace.s12) {
            Image(systemName: "moon.stars.fill")           // non directionnelle
                .font(.system(size: 20))
                .foregroundStyle(MoedColor.rose)
            VStack(alignment: .leading, spacing: MoedSpace.s4) {
                Text(title)
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.ink)
                HStack(spacing: MoedSpace.s12) {
                    if let start = fast.start {
                        fastTime("arrow.down.to.line", vm.time(start, tz: city.tz, lang: lang))
                    }
                    if let end = fast.end {
                        fastTime("arrow.up.to.line", vm.time(end, tz: city.tz, lang: lang))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(MoedSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MoedRadius.md, style: .continuous)
                .fill(MoedColor.roseWash)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MoedRadius.md, style: .continuous)
                .strokeBorder(MoedColor.rose.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func fastTime(_ icon: String, _ time: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(MoedColor.rose)
            ForceLTR {
                Text(time).monospacedDigit().font(MoedFont.caption(lang))
            }
            .foregroundStyle(MoedColor.rose)
        }
    }
}

// MARK: - Zmanim clés

private struct ZmanimBlock: View {
    let rows: [TodayViewModel.ZmanDisplay]
    let disclaimer: String
    let lang: Lang
    let onOpenAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MoedSpace.s12) {
            Text(L10n.t("home.zmanimTitle", lang))
                .font(MoedFont.title2(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    ZmanLine(row: row, lang: lang)
                    if idx < rows.count - 1 {
                        Divider().overlay(MoedColor.line)
                    }
                }
            }

            // Lien « Tous les zmanim » → page ville détaillée (chevron miroité en RTL).
            Button(action: onOpenAll) {
                HStack(spacing: MoedSpace.s4) {
                    Text(L10n.t("home.allZmanim", lang))
                        .font(MoedFont.bodyEmph(lang))
                    Image(systemName: "chevron.right")
                        .directionalMirror()
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(MoedColor.ner)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Disclaimer halakhique obligatoire (shita active + minutes d'allumage).
            Text(disclaimer)
                .font(MoedFont.caption(lang))
                .foregroundStyle(MoedColor.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: MoedRadius.md, padding: MoedSpace.s20)
    }
}

private struct ZmanLine: View {
    let row: TodayViewModel.ZmanDisplay
    let lang: Lang

    var body: some View {
        HStack(spacing: MoedSpace.s12) {
            Image(systemName: row.symbol)
                .font(.system(size: 20))
                .foregroundStyle(row.isKey ? MoedColor.ner : MoedColor.inkSoft)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.t(row.labelKey, lang))
                    .font(MoedFont.bodyEmph(lang))
                    .foregroundStyle(MoedColor.ink)
                Text(row.shita)                            // shita TOUJOURS affichée
                    .font(MoedFont.caption(lang))
                    .foregroundStyle(MoedColor.inkMute)
            }
            Spacer(minLength: MoedSpace.s8)
            // Heure en colonne trailing rigide (tabular), LTR même en hébreu.
            ForceLTR {
                Text(row.time).monospacedDigit().font(MoedFont.zmanTime(lang))
            }
            .foregroundStyle(row.isKey ? MoedColor.ner : MoedColor.ink)
        }
        .padding(.vertical, MoedSpace.s8)
        .padding(.horizontal, row.isKey ? MoedSpace.s8 : 0)
        .background {
            if row.isKey {
                RoundedRectangle(cornerRadius: MoedRadius.sm, style: .continuous)
                    .fill(MoedColor.nerWash)
            }
        }
        .modifier(KeyGlow(active: row.isKey))               // glowNer sur le zman clé uniquement
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L10n.t(row.labelKey, lang)), \(row.shita), \(row.available ? row.time : "—")")
    }
}

private struct KeyGlow: ViewModifier {
    let active: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if active { MoedElevation.glowNer(content) } else { content }
    }
}

// MARK: - Parasha + Daf Yomi

private struct ParashaDafBlock: View {
    let parasha: ParashaInfo?
    let daf: DafYomiInfo
    let vm: TodayViewModel
    let lang: Lang

    var body: some View {
        HStack(alignment: .top, spacing: MoedSpace.s16) {
            if let parasha {
                InfoTile(
                    symbol: "text.book.closed.fill", tint: MoedColor.ner,
                    eyebrow: L10n.t("home.parasha", lang),
                    title: vm.parashaName(parasha, lang: lang),
                    subtitle: parasha.torah, lang: lang
                )
            }
            InfoTile(
                symbol: "book.fill", tint: MoedColor.twilight,
                eyebrow: L10n.t("home.dafYomi", lang),
                title: vm.dafName(daf, lang: lang),
                subtitle: nil, lang: lang
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct InfoTile: View {
    let symbol: String
    let tint: Color
    let eyebrow: String
    let title: String
    let subtitle: String?
    let lang: Lang

    var body: some View {
        HStack(spacing: MoedSpace.s12) {
            ZStack {
                Circle().fill(tint.opacity(0.14))
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow.uppercased())
                    .font(MoedFont.micro(lang)).tracking(0.8)
                    .foregroundStyle(MoedColor.inkMute)
                Text(title)
                    .font(MoedFont.title3(lang))
                    .foregroundStyle(MoedColor.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .hebrewBalanced(lang)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(MoedFont.caption(lang))
                        .foregroundStyle(MoedColor.inkMute)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: MoedRadius.md, padding: MoedSpace.s16)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - En-tête verre au scroll

private struct GlassScrollHeader: View {
    let text: String
    let lang: Lang

    var body: some View {
        HStack {
            Text(text)
                .font(MoedFont.title3(lang))
                .foregroundStyle(MoedColor.ink)
                .hebrewBalanced(lang)
                .lineLimit(1).minimumScaleFactor(0.85)
            Spacer()
        }
        .padding(.horizontal, MoedSpace.s20)
        .padding(.vertical, MoedSpace.s12)
        .frame(maxWidth: .infinity)
        .glass(.chrome)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Carte solide (cardSolid) — contenu lisible, jamais de verre

private struct SolidCard: ViewModifier {
    var radius: CGFloat
    var padding: CGFloat
    func body(content: Content) -> some View {
        MoedElevation.e1(
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(MoedColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(MoedColor.lineStrong, lineWidth: 1)
                )
        )
    }
}

private extension View {
    func solidCard(radius: CGFloat, padding: CGFloat) -> some View {
        modifier(SolidCard(radius: radius, padding: padding))
    }
}

// MARK: - Cascade d'apparition (stagger 60 ms, Reduce Motion respecté)

private struct StaggerReveal: ViewModifier {
    let index: Int
    let revealed: Bool
    let reduceMotion: Bool
    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 8)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.15)
                    : .smooth(duration: 0.5).delay(Double(index) * 0.06),
                value: revealed
            )
    }
}

private extension View {
    func staggerReveal(_ index: Int, revealed: Bool, reduceMotion: Bool) -> some View {
        modifier(StaggerReveal(index: index, revealed: revealed, reduceMotion: reduceMotion))
    }
}

// MARK: - Sonde de décalage de scroll

private struct TodayScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Flow layout (wrap des badges, iOS 16+ Layout)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += s.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, s.height)
        }
        let width = maxWidth == .greatestFiniteMagnitude ? widest : maxWidth
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX, x + s.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
