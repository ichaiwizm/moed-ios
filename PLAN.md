# Moed iOS — Plan d'implémentation natif (SwiftUI · Liquid Glass · iOS 17+)

> Autorités amont : `NATIVE_SPEC.md` (périmètre produit) + `DESIGN.md` (DA Liquid Glass).
> Référence de portage : moteur web `/root/apps/mvp-moed/src/lib/engine/` et app Android `/root/apps/mvp-moed/android/`.
> **Cible : iOS 17 minimum**, SwiftUI, projet généré par **XcodeGen** (`project.yml`), CI déjà présente dans `/root/.appstore/ios-template`.

⚠️ Le langage **Liquid Glass** de la DESIGN.md est API iOS 26 (`.glassEffect`, `Glass.clear`, TabBar verre auto). **Cible = iOS 17.** Stratégie : viser l'esthétique verre via une **abstraction `GlassBackground`** qui rend `.glassEffect(.regular…)` sous `#available(iOS 26)` et retombe sur `.regularMaterial` + bordure/ombre pour iOS 17–25. Aucune fonctionnalité ne dépend du verre ; c'est un habillage progressif.

---

## 1. Arborescence de fichiers proposée

```
/root/apps/moed-ios/
├── project.yml                      # XcodeGen : cible app + widget + tests, SPM deps, settings signature
├── Gemfile                          # (copié depuis ios-template) fastlane
├── fastlane/                        # (scaffold-ios-ci.sh) Appfile / Matchfile / Fastfile
├── .github/workflows/ios-release.yml# (scaffold) + étape `xcodegen generate` ajoutée (voir §9)
├── .gitignore                       # ignore *.xcodeproj généré, DerivedData, .build
├── Moed/                            # cible application
│   ├── App/
│   │   ├── MoedApp.swift            # @main, root scene, injecte AppState en environment
│   │   ├── RootView.swift           # TabView 5 onglets + layoutDirection selon locale
│   │   └── Info.plist               # locales he/fr/en, NSLocationWhenInUse, BGTask ids
│   ├── Engine/                      # ⭐ moteur déterministe (parité kosher-zmanim/KosherJava)
│   │   ├── HebrewDateEngine.swift   # conversions grég⇄hébreu, formatage localisé, molad
│   │   ├── ZmanimEngine.swift       # 16 zmanim (catalogue §3.3 SPEC) via KosherCocoa
│   │   ├── CandleEngine.swift       # allumage = sunset−offset ; havdala (degrés/minutes)
│   │   ├── CalendarEngine.swift     # fêtes, jeûnes, Roch Hodech, Omer, Daf Yomi, parasha/haftara
│   │   ├── PersonalEngine.swift     # yahrzeit / anniversaire (règles Cheshvan-30/Kislev-30/Adar)
│   │   ├── Gematria.swift           # mispar hechrachi + décomposition
│   │   ├── HebrewMonthTables.swift  # noms mois/jours he/fr/en (hebcal ne connaît que en/he)
│   │   ├── HaftaraSephardic.swift   # table statique si KosherCocoa ne couvre pas
│   │   └── EngineModels.swift       # structs de sortie (Zman, ZmanimResult, CalendarDay…)
│   ├── Data/
│   │   ├── City.swift               # struct City + décodage
│   │   ├── Tsadik.swift             # struct Tsadik + décodage
│   │   ├── StaticData.swift         # chargement paresseux + cache cities.json / tsadikim.json
│   │   └── Resources/
│   │       ├── cities.json          # ⬅ généré depuis src/data/cities.ts (191 villes)
│   │       └── tsadikim.json        # ⬅ généré depuis src/data/tsadikim.ts (32 fiches)
│   ├── Store/                       # gestion d'état + persistance
│   │   ├── AppState.swift           # @Observable racine (settings + carnet + dérivés)
│   │   ├── SettingsStore.swift      # UserDefaults (App Group) : ville, minhag, notif
│   │   ├── FamilyStore.swift        # carnet familial (JSON dans App Group container)
│   │   └── LocationProvider.swift   # CLLocationManager → ville la plus proche (opt-in)
│   ├── i18n/
│   │   ├── L10n.swift               # accès typé + interpolation ({n}, {city})
│   │   ├── he.lproj/Localizable.strings
│   │   ├── fr.lproj/Localizable.strings
│   │   └── en.lproj/Localizable.strings
│   ├── DesignSystem/
│   │   ├── MoedColor.swift          # tokens couleur (asset catalog Any/Dark)
│   │   ├── MoedFont.swift           # échelle typo + .hebrewBalanced() + tabular
│   │   ├── MoedRadius.swift / MoedElevation.swift
│   │   ├── GlassBackground.swift    # abstraction verre (iOS 26) ↔ material (17–25)
│   │   ├── CanvasBackground.swift   # gradient d'aube + halo radial nerGlow
│   │   ├── Haptics.swift            # wrappers .sensoryFeedback / UIFeedbackGenerator
│   │   └── RTL.swift                # ForceLTR (chiffres), miroir d'icônes directionnelles
│   ├── Components/
│   │   ├── ZmanRow.swift  ShabbatCard.swift  Badge.swift  CountdownCapsule.swift
│   │   ├── PersonRow.swift  TsadikCard.swift  CalendarDayRow.swift
│   │   ├── SectionCard.swift (cardSolid)  FloatingAddButton.swift  ScrollGlassHeader.swift
│   │   └── EmptyStateView.swift
│   ├── Screens/
│   │   ├── Today/TodayView.swift + TodayViewModel.swift
│   │   ├── Calendar/CalendarView.swift + CalendarViewModel.swift
│   │   ├── Personal/PersonalView.swift  AddPersonSheet.swift
│   │   ├── Tsadikim/TsadikimView.swift  TsadikDetailView.swift
│   │   ├── Settings/SettingsView.swift  CitySearchView.swift
│   │   └── Zmanim/ZmanimCityView.swift  ConverterView.swift
│   ├── Notifications/
│   │   ├── NotificationScheduler.swift # planifie fenêtre glissante d'occurrences
│   │   └── BackgroundRefresh.swift      # BGTaskScheduler → replanifie
│   └── Assets.xcassets/              # AppIcon, tokens couleur, illustrations, motifs tsadikim
├── MoedWidgets/                     # cible Widget Extension
│   ├── MoedWidgetsBundle.swift
│   ├── CandleWidget.swift  ZmanimWidget.swift  OmerWidget.swift
│   ├── Provider.swift                # TimelineProvider recalcule localement (App Group)
│   └── Assets.xcassets
├── Shared/                          # code partagé app ↔ widget (ⓘ target membership double)
│   └── (Engine + Data + tokens couleur inclus dans les 2 cibles via project.yml)
└── MoedTests/
    ├── ZmanimValidationTests.swift  # ⭐ matrice 10 villes × 2 ans (barre halakhique §3.6)
    ├── HebrewDateTests.swift  PersonalTests.swift  GematriaTests.swift
    └── Fixtures/kosher_zmanim_reference.json  # sorties de référence exportées du web
```

**Note partage app↔widget** : le dossier `Engine/`, `Data/`, et les tokens couleur sont déclarés dans **les deux** cibles (`Moed` et `MoedWidgets`) via `project.yml` (double target membership) plutôt qu'un framework séparé — plus simple, zéro dépendance dynamique.

---

## 2. Modèles de données (structs Swift)

Portés 1:1 depuis `types.ts` / `zmanim.ts` / `calendar.ts` / `personal.ts` du moteur web (voir §11 SPEC).

```swift
// --- i18n / géo ---
enum Lang: String, Codable { case he, fr, en }
struct LocalizedText: Codable { let he, fr, en: String }
struct GeoContext { let lat, lng: Double; let elevation: Double; let timeZone: String; let name: String? }

// --- Données statiques (parité cities.ts / tsadikim.ts) ---
struct City: Codable, Identifiable {
    var id: String { slug }
    let slug: String
    let names: LocalizedText
    let country: String            // ISO2
    let countryNames: LocalizedText
    let lat, lng: Double
    let elevation: Double?
    let tz: String                 // IANA
    let israel: Bool
    let candleMinutes: Int         // 18 défaut / 40 Jérusalem / 30 Haïfa…
    let community: Int?
}
enum TsadikCategory: String, Codable { case tanna, rishon, acharon, hassid, habad, sefarade }
enum Confidence: String, Codable { case high, medium, traditional }
struct HilulaDate: Codable { let day: Int; let month: String }   // mois hébreu translittéré EN
struct Tsadik: Codable, Identifiable {
    var id: String { slug }
    let slug: String
    let names: LocalizedText
    let epithet: LocalizedText?
    let category: TsadikCategory
    let hilula: HilulaDate
    let hilulaNote: LocalizedText?
    let yearGregorian: Int?
    let kever: Kever?              // { place, country }
    let works: [String]?
    let bio: LocalizedText
    let confidence: Confidence
    let sources: [String]
}

// --- Sorties moteur ---
struct Zman: Identifiable {         // zmanim.ts
    var id: String { key }
    let key: String                 // "hanetzHachama"…
    let date: Date?                 // null aux latitudes polaires → UI affiche "—"
    let shita: String               // "16.1°", "72 min" — TOUJOURS affiché (transparence halakhique)
}
struct ZmanimResult { let zmanim: [Zman]; let byKey: [String: Zman]; let location: GeoContext; let date: Date }

struct HebrewDateResult {           // hebrewDate.ts
    let year, month, day, dayOfWeek: Int
    let isLeapYear: Bool
    let monthName, weekdayName: LocalizedText
    let yearHebrew, dayHebrew: String   // "תשפ״ה", "ט״ו"
}

enum EventCategory: String { case holiday, yomtov, fast, roshchodesh, omer, parasha, other }
struct FastTiming { let start, end: Date?; let is25Hour: Bool }
struct CalEvent { let desc: String; let category: EventCategory; let title: LocalizedText
                  let emoji: String?; let isYomTov: Bool; let fast: FastTiming? }
struct ParashaInfo { let name: (en: String, he: String); let torah, haftara, haftaraSephardic: String? }
struct DafYomiInfo { let masechet: String; let daf: String; let render: (en: String, he: String) }
struct CalendarDay {
    let date: Date
    let hebrew: HebrewDateResult
    let events: [CalEvent]
    let omer: Int?                  // 1..49 ou nil
    let dafYomi: DafYomiInfo
    let parasha: ParashaInfo?       // seulement le Chabbat
    let candleLighting: Date?
    let havdalah: Date?
}

// --- Personnel (parité personal.ts + PersonRecord.kt) ---
enum PersonType: String, Codable { case yahrzeit, birthday }
struct PersonRecord: Codable, Identifiable {
    let id: String                  // UUID
    let type: PersonType
    let name: String
    let date: Date                  // date grég d'origine (décès/naissance)
    let afterSunset: Bool
}
struct Occurrence { let gregorian: Date; let hebrew: HebrewDateResult; let hebrewYear: Int }

// --- Préférences (parité moed_prefs / AppSettings.kt) ---
enum CandleMode: Codable, Equatable { case auto; case minutes(Int) }   // auto|18|20|30|40
enum TzeitMethod: String, Codable { case degrees, minutes }            // 8.5° | offset fixe
enum Region: String, Codable { case auto, il, diaspora }
struct NotifPrefs: Codable { var shabbat=false, omer=false, hilula=false, yahrzeit=false }
struct Settings: Codable {
    var citySlug = "paris"
    var candle: CandleMode = .auto
    var tzeit: TzeitMethod = .degrees
    var region: Region = .auto
    var lang: Lang? = nil           // nil = suivre la langue système au 1er lancement
    var notif = NotifPrefs()
}
```

---

## 3. Couche « réseau » — **il n'y en a pas au runtime**

Règle d'or n°1 (SPEC §10) : **aucun appel réseau pour le calcul**. Tout est on-device. Donc :

- **Pas de client HTTP, pas d'endpoint, pas de token d'auth applicatif.** L'app est offline par nature, sans compte, sans backend (SPEC §7). Le PocketBase `pocketbase-moed` et les routes `api/push/*` du repo web n'existent **que** pour le Web Push VAPID de la PWA et **ne sont pas portés**.
- **Seuls « accès externes » tolérés, tous non-bloquants et hors calcul** :
  - `KosherCocoa` / `Foundation` : calcul **local** pur.
  - `CLLocationManager` : géoloc **device** (opt-in) pour choisir la ville proche — pas un appel serveur.
  - Les liens `sources[]` des fiches tsadikim ouvrent Safari (`openURL`) — action utilisateur explicite, hors runtime de calcul.
- **Auth par token** demandée dans la consigne : **sans objet pour l'app**. Les seuls tokens du projet sont **côté CI** (App Store Connect API Key `.p8`, clé SSH `match`) — voir §9. Ils ne vivent jamais dans le binaire.
- **Validation build-time** (l'équivalent de `validate.mjs`) : un script hors-app compare KosherCocoa à Hebcal / aux sorties kosher-zmanim exportées. Réseau autorisé **uniquement là**, jamais embarqué (cf. `ZmanimValidationTests` lit un fixture figé pour rester offline en CI).

---

## 4. Moteur de calcul (le cœur — parité obligatoire)

**Dépendance : KosherCocoa** (port officiel Objective-C/Swift de KosherJava par Moshe Berman), via SPM. C'est la contrepartie iOS directe de `kosher-zmanim` (JS) et `KosherJava 2.5.0` (Android) → **résultats identiques garantis**.

| Domaine | API KosherCocoa | Sortie |
|---|---|---|
| Conversion grég⇄hébreu | `KCJewishCalendar`, `KCHebrewDateFormatter` | `HebrewDateResult` |
| 16 zmanim (catalogue §3.3 SPEC) | `KCComplexZmanimCalendar` + `KCGeoLocation` | `[Zman]` |
| Lever/coucher | `sunrise` / `sunset` | ancre allumage/havdala |
| Daf Yomi | `KCDafYomiCalculator` (ou table de secours) | `DafYomiInfo` |
| Fêtes/jeûnes/Omer/Roch Hodech | `KCJewishCalendar` (holidayIndex, dayOfOmer…) | `[CalEvent]`, `omer` |
| Molad | `KCJewishCalendar` molad | struct molad |

**Lacunes probables à combler par tables statiques** (comme le prévoit la SPEC §3.2) :
- **Parasha + haftara** : si KosherCocoa ne fournit pas la haftara **sépharade** et le distinguo Israël/diaspora complet → embarquer une petite table dérivée de `@hebcal/leyning` dans `HaftaraSephardic.swift`.
- **Noms de mois/jours FR** : hebcal/KosherJava ne connaissent que en/he → `HebrewMonthTables.swift` (tables he/fr/en portées de `hebrewDate.ts`). **Ne jamais** demander le rendu `fr` à la lib.

**Edge cases à reproduire à l'identique (SPEC §3.4)** :
- Timezone/DST piloté par l'**IANA** de la ville (`TimeZone(identifier:)`), jamais l'offset device.
- Latitude extrême → zman **`nil`** (jamais NaN) → UI affiche « — ».
- Jour hébraïque commence au coucher → flag `afterSunset` avance d'un jour (`anchorHebrewDate`).
- Élévation utilisée pour lever/coucher **seulement si > 0**.
- Arrondi **uniquement à la fin** (garder les `Date` bruts).
- `region` (auto/il/diaspora) change fêtes + parasha + haftara.
- Jeûnes : mineur alot→tzeit ; majeur 25 h (Kippour, 9 Av) coucher veille→tzeit.

**Personnel (SPEC §3.5)** : yahrzeit via règles Cheshvan-30/Kislev-30/Adar (embolismique) de KosherCocoa `JewishCalendar`; énumération année par année depuis l'année hébraïque de `from` jusqu'à `count` occurrences, garde-fou `count+200` ans.

---

## 5. Gestion d'état

Pattern : **`@Observable` (Observation framework, iOS 17)** — un `AppState` racine injecté en `.environment`, des ViewModels légers par écran quand utile.

```swift
@Observable final class AppState {
    var settings: Settings           // persistée (SettingsStore, App Group)
    var family: [PersonRecord]       // persistée (FamilyStore)
    var now: Date                    // tick 1 s (Timer) pour le compte à rebours
    // Dérivés recalculés (synchrones, offline) quand ville/minhag/langue changent :
    var city: City { StaticData.city(slug: settings.citySlug) }
    var geo: GeoContext { city.geoContext(candleMode: settings.candle) }
    var lang: Lang { settings.lang ?? Lang.fromSystem() }
    var layoutDirection: LayoutDirection { lang == .he ? .rightToLeft : .leftToRight }
    // Fonctions : today() -> TodayModel, zmanim(date:), calendar(monthOffset:)…
}
```

- **Calcul synchrone** (pas de skeleton) : au changement de ville/minhag/langue, tout est recalculé instantanément (offline). Le « moment » d'écran est masqué par la cascade d'apparition (DESIGN §6), pas par un chargement.
- **Timer 1 s** pilote `now` → compte à rebours d'allumage (DESIGN §5.2). VoiceOver : throttle l'annonce à la minute (DESIGN §10).
- **Langue in-app** : changer `settings.lang` met à jour `layoutDirection` **sans redémarrage**, transition `.smooth`.
- **Persistance** :
  - `SettingsStore` → `UserDefaults(suiteName: appGroup)` (partagé widgets).
  - `FamilyStore` → JSON `moed_family` dans le container **App Group** (partage widget + privacy : rien ne quitte l'appareil, SPEC §7.2). SwiftData envisageable en v2 mais non nécessaire.

---

## 6. Écrans & vues (SwiftUI)

`RootView` = `TabView` 5 onglets (ordre logique → miroité auto en RTL), `.environment(\.layoutDirection, …)` racine, `CanvasBackground` global.

| # | Écran | Vue | Composants clés | Réf. SPEC/DESIGN |
|---|---|---|---|---|
| 1 | **Aujourd'hui** `today` | `TodayView` (ScrollView + `ScrollGlassHeader`) | en-tête date (ville→sheet, date héb `title1`, badges), `ShabbatCard` (héros, `glowNer`, `CountdownCapsule` verre, havdala), liste `ZmanRow` (HOME_ZMANIM: hanetz, sofShmaGRA, chatzot, minchaGedola, shkia, tzeit), `parasha` + Daf Yomi, états fête/jeûne. Cascade 60 ms stagger. | SPEC §2.1, DESIGN §5.1-5.3 |
| 2 | **Calendrier** `calendar` | `CalendarView` | header mois+année + chevrons (miroir RTL, glissement horizontal), `List` de `CalendarDayRow` (date héb+grég, badges catégorie: fête=ner, jeûne=rose, RH=twilight, omer=sage). Source `CalendarEngine.range(start,end,{region,geo,lang})`. | SPEC §2.2, DESIGN §5.4 |
| 3 | **Personnel** `personal` | `PersonalView` + `AddPersonSheet` | `List` de `PersonRow` (pastille type, prochaine occurrence grég+héb, badge « dans X j »), swipe supprimer (`rose`+haptique), `FloatingAddButton` verre → sheet (segmented type, nom `cardInset`, DatePicker `.graphical`, toggle afterSunset, valider capsule `ner`), empty state illustré, bloc opt-in rappels. | SPEC §2.3, DESIGN §5.4-5.5 |
| 4 | **Tsadikim** `tsadikim` | `TsadikimView` + `TsadikDetailView` | section « Hiloula du jour » (filtre `hilula == date héb courante`) cartes motif **symbolique par catégorie** (jamais de portrait), répertoire grille 2 col., détail push `NavigationStack` (épithète, hiloula+note, prochaine hiloula, kever, œuvres, bio, badge confiance `sage`/`ner`/`inkMute`, sources cliquables). | SPEC §2.4, DESIGN §5.4 |
| 5 | **Réglages** `settings` | `SettingsView` + `CitySearchView` | Langue (he/fr/en, change locale+RTL live), Localisation (recherche sur 191 villes + « autour de moi » CoreLocation), Minhag (candleMinutes segmented auto/18/20/30/40, tzeit degrees/minutes, région auto/il/diaspora), Notifications (toggles opt-in → demande permission au moment de l'opt-in). | SPEC §2.5, DESIGN §5.6 |
| — | **Zmanim ville** (sous-vue) | `ZmanimCityView` | tous les zmanim (ALL_ZMANIM, 13 lignes) + allumage Chabbat + `Disclaimer` halakhique + shita active + villes proches. | SPEC §2 |
| — | **Convertisseur** (sous-vue) | `ConverterView` | segmented grég→héb / héb→grég, DatePicker, sélecteurs jour(1-30)/mois héb/année, gestion invalide (haptique `.error`). | SPEC §2.6 |

**Composants transverses** : `ZmanRow` (icône+label `bodyEmph`+heure `zmanTime` monospacedDigit trailing+shita ; zman clé fond `nerWash` unique ; null→« — »), `Badge` (§5.6 DESIGN), `GlassBackground`, `CanvasBackground`, `ForceLTR` (enveloppe les heures pour rester `18:42` en RTL, tabular).

---

## 7. Design system (traduction DESIGN.md)

- **Couleurs** : `Assets.xcassets` un color set par token (Any/Dark) → `MoedColor.canvas`, `.ink`, `.ner`… Dark **présent mais non branché** en v1 (`preferredColorScheme(.light)` forcé, DESIGN §9).
- **Verre** : `GlassBackground` = `if #available(iOS 26) { .glassEffect(.regular.tint(...)) } else { ZStack { .regularMaterial ; bordure lineStrong ; ombre e2 } }`. **Reduce Transparency** → `surface` opaque (DESIGN §10).
- **Typo** : polices embarquées (Fraunces, Frank Ruhl Libre, Instrument Sans, Assistant) déclarées dans Info.plist `UIAppFonts`. `MoedFont` mappe chaque style sur un `Font.TextStyle` (Dynamic Type). `zmanTime`/chiffres → `.monospacedDigit()`. `.hebrewBalanced()` = ×1.04 si `lang == .he`. Fallback `.serif`/`.system`.
- **Formes** : `RoundedRectangle(cornerRadius:, style: .continuous)` — sm 10 / md 16 / lg 26 / `Capsule`.
- **Ombres** teintées `ink` (jamais noires) : e1/e2/e3 + `glowNer` (zman clé/allumage **uniquement**).
- **Canvas** : `LinearGradient(top→bottom)` + `RadialGradient(nerGlow @0.03, .top)`, immobile, `.ignoresSafeArea()`.
- **Motion** : `.smooth(0.5)` apparition, `.snappy(0.22)` press, cascade stagger 60 ms **une fois** par présentation, pulse capsule 1↔1.006/2 s. **Reduce Motion** → fondu ≤150 ms, pulse figée.
- **Haptique** (`.sensoryFeedback`) : `.selection` (onglet/segmented/ville), `.success` (ajout, entrée Chabbat), `.impact(.rigid)` (suppression), `.error` (date invalide), `.impact(.soft)` (mois). Jamais sur scroll/tick.
- **RTL** : `.leading/.trailing` partout, icônes directionnelles `.flipsForRightToLeftLayoutDirection(true)`, icônes bougie/lune jamais miroitées, heures en `ForceLTR`.
- **Accessibilité** : contrastes AA, Dynamic Type jusqu'à `.accessibility3` (cartes en layout vertical), VoiceOver « [label], [shita], [heure] », cibles ≥44 pt, focus ring `focus`.

---

## 8. Notifications (locales, planifiées — zéro serveur)

- **Framework** : `UNUserNotificationCenter`, triggers `UNCalendarNotificationTrigger` (dates déterministes). Permission demandée **au moment de l'opt-in**, pas au lancement (SPEC §9).
- **Types** (tous opt-in, miroir des 4 canaux Android `moed_shabbat/yahrzeit/omer/holiday`) : allumage Chabbat (vendredi), yahrzeit+kaddish, Omer quotidien (49 j), hiloula du jour, fêtes/jeûnes à venir.
- **Stratégie fenêtre glissante** : `NotificationScheduler` planifie les **N prochaines occurrences** ; `BackgroundRefresh` (`BGTaskScheduler`, id déclaré Info.plist) + replanification **à chaque ouverture** re-remplit la fenêtre. Contenu **localisé** (langue active).
- Aucune dépendance push VAPID — toutes les échéances sont calculables à l'avance.

---

## 9. Dépendances, build, signature, CI

### Dépendances (SPM, dans `project.yml`)
- **KosherCocoa** (`github.com/MosheBerman/KosherCocoa`) — zmanim + calendrier hébraïque. **Seule dépendance runtime.**
- **XcodeGen** (outil de génération, pas un package) — installé via Homebrew en CI + local.
- Zéro autre dépendance tierce (pas de réseau, pas d'analytics — SPEC règle d'or n°4).

### `project.yml` (XcodeGen) — points clés
```yaml
name: Moed
options: { deploymentTarget: { iOS: "17.0" }, bundleIdPrefix: com.wizycode }
settings: { MARKETING_VERSION: "1.0.0", DEVELOPMENT_TEAM: "" }   # team résolue par la clé ASC
packages:
  KosherCocoa: { url: https://github.com/MosheBerman/KosherCocoa, from: "4.0.0" }
targets:
  Moed:            # scheme = "Moed" (attendu par le Fastfile/CI)
    type: application; platform: iOS
    sources: [Moed, Shared]
    dependencies: [{ package: KosherCocoa }, { target: MoedWidgets, embed: true }]
    settings: { PRODUCT_BUNDLE_IDENTIFIER: com.wizycode.moed, CODE_SIGN_STYLE: Manual }
    entitlements: App Group (group.com.wizycode.moed)
  MoedWidgets:
    type: app-extension; sources: [MoedWidgets, Shared]; App Group identique
  MoedTests:
    type: bundle.unit-test; dependencies: [{ target: Moed }]
```
Le **scheme `Moed`** et le **bundle `com.wizycode.moed`** doivent correspondre aux arguments passés à `scaffold-ios-ci.sh` (le Fastfile référence `#{SCHEME}.xcodeproj`).

### Signature & CI — **le pipeline existe déjà dans `/root/.appstore`**
1. `scaffold-ios-ci.sh /root/apps/moed-ios com.wizycode.moed Moed` → copie `Gemfile`, `fastlane/{Appfile,Matchfile,Fastfile}` (substitution bundle/scheme), workflow `ios-release.yml`.
2. Signature via **fastlane match** (type `appstore`, repo `git@github.com:ichaiwizm/ios-signing.git`, `MATCH_DEPLOY_KEY` SSH). Style **manuel** (le Fastfile force `signingStyle: manual`).
3. Auth App Store Connect via **API Key `.p8`** (`AuthKey_25S93LUR8B.p8`) → secrets `ASC_KEY_ID/ISSUER_ID/KEY_P8_BASE64`. Team résolue automatiquement (Appfile).
4. `setup-ios-secrets.sh <owner/repo>` injecte tous les secrets (`secrets.env` + `match_deploy_key`) dans le repo GitHub.
5. **Une adaptation requise** : la CI `ios-release.yml` fait `checkout` puis `build_app(scheme:)` — mais le `.xcodeproj` est **généré par XcodeGen**, pas commité. → **Ajouter une étape** avant fastlane :
   ```yaml
   - run: brew install xcodegen && xcodegen generate
   ```
   (dans `.github/workflows/ios-release.yml`, après le checkout ; et l'ajouter à `.gitignore` : `*.xcodeproj/`).
6. Lanes : `beta` → TestFlight, `release` → App Store review. Build number = `GITHUB_RUN_NUMBER` (monotone). Runner `macos-14`, Xcode sélectionné, Ruby 3.2 + bundler cache.
7. Déclenchement : `gh workflow run ios-release.yml --repo <owner/repo> -f lane=beta` ou push tag `v*`.
8. `poll.sh` sert à attendre la propagation du contrat App Store Connect (`REQUIRED_AGREEMENTS`) si première soumission.

---

## 10. Données statiques & i18n à générer

- **`cities.json`** (191 villes) : exporter depuis `src/data/cities.ts` (script Node one-shot `tsx export.ts > cities.json`) en gardant TOUS les champs (`slug, names{fr,en,he}, country, countryNames, lat, lng, tz, elevation?, israel, candleMinutes, community?`). Décodé par `City: Codable`. ⚠️ Le format Android n'a qu'un sous-ensemble (name/country/lat/lng/tz/elevation) — **côté iOS, garder le format riche** (besoin des noms trilingues + candleMinutes + israel).
- **`tsadikim.json`** (32 fiches) : idem depuis `src/data/tsadikim.ts` (structure §2). Bios trilingues pré-générées, sources incluses.
- **`Localizable.strings`** he/fr/en : porter `src/messages/{he,fr,en}.json` (sections `meta/brand/nav/common/home/zmanim/converter/personal/tsadikim/calendar/settings/install/offline` ; `install`/`offline` inutiles en natif). **Chaînes paramétrées** : `home.omerDay {n}`, `zmanim.pageTitle {city}` → format `%@`/`%lld` + helper `L10n`.
- **Assets** : illustrations (candles, zmanim, parasha, omer, birthday, yahrzeit, empty states) + motifs tsadikim par catégorie + AppIcon (concept « croissant du molad → flamme »), en @1x/@2x/@3x. **Jamais** de portrait photoréaliste de tsadik.
- **Polices** : 4 fichiers embarqués (Fraunces, Frank Ruhl Libre, Instrument Sans, Assistant), déclarés `UIAppFonts`.

---

## 11. Ordre de construction recommandé (jalons)

**J0 — Squelette buildable.** `project.yml` (XcodeGen), cibles Moed + MoedWidgets + Tests, KosherCocoa SPM, App Group, scaffold CI (`scaffold-ios-ci.sh` + étape xcodegen), `MoedApp`/`RootView` TabView 5 onglets vides. Vérifier build local + un run CI `beta` à blanc.

**J1 — Moteur + validation (barre halakhique, bloquant).** `HebrewDateEngine`, `ZmanimEngine` (16 zmanim), `CandleEngine`, `PersonalEngine`, `CalendarEngine`, `Gematria`, tables mois/haftara. Écrire `ZmanimValidationTests` : rejouer la matrice **10 villes × 2 ans × 4 types** contre un fixture exporté de kosher-zmanim (dates 0 tolérance, zmanim ≤2 min). **Rien d'UI ne démarre tant que la validation n'est pas PASS** (les gens jeûnent/allument selon ces heures).

**J2 — Données + état + i18n.** Export `cities.json`/`tsadikim.json`, `StaticData`, `Settings`/`Family` stores (App Group), `AppState @Observable`, `Localizable.strings` he/fr/en, `L10n`, direction RTL racine.

**J3 — Design system.** Tokens couleur (asset catalog), polices, `MoedFont`+`.hebrewBalanced()`, `GlassBackground` (fallback iOS 17), `CanvasBackground`, `Haptics`, `RTL`/`ForceLTR`, composants (`ZmanRow`, `Badge`, `SectionCard`, `CountdownCapsule`, `FloatingAddButton`).

**J4 — Écran Aujourd'hui** (le plus riche : header verre au scroll, `ShabbatCard` héros, compte à rebours 1 s, HOME_ZMANIM, parasha/Daf, cascade + Reduce Motion). Valide toute la chaîne moteur→UI.

**J5 — Écrans Calendrier, Personnel (+sheet), Tsadikim (+détail), Réglages (+CitySearch, CoreLocation), Zmanim ville, Convertisseur.**

**J6 — Notifications** (`UNUserNotificationCenter`, triggers calendaires, fenêtre glissante, `BGTaskScheduler`, opt-in).

**J7 — Widgets WidgetKit** (Allumage small/medium+LockScreen, Zmanim medium, Omer small+LockScreen ; `TimelineProvider` local via App Group).

**J8 — Accessibilité, RTL fin, Dynamic Type, VoiceOver, contrastes AA, Reduce Transparency/Motion ; polish DA ; rapport de validation final ; run CI `release`.**

---

## 12. Garde-fous non négociables (rappel SPEC §10 / DESIGN §12)
1. **Aucun réseau au runtime** pour le calcul (offline complet, pas de backend, pas de compte).
2. **Parité de calcul** iOS↔Android↔Web validée (§3.6 SPEC) — mêmes shitot, noms, règles yahrzeit ; disclaimer + shita affichés ; **zéro approximation**.
3. **Light mode par défaut** ; **RTL première classe** ; **hébreu langue primaire** ; 3 langues à parité.
4. **Verre = chrome/contrôles flottants uniquement**, jamais sous du contenu de lecture ; jamais verre sur verre ; jamais blanc pur en canvas ; flamme sur **un seul** élément fort par écran.
5. **Rien ne quitte l'appareil** (privacy by design).
