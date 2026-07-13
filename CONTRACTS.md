# Moed iOS — CONTRACTS.md

> **Rôle de ce document.** Il **fige le vocabulaire partagé** entre tous les modules de code natif SwiftUI (voir découpage §5). Ces noms de types, de champs, de tokens et de signatures sont **contractuels** : chaque module les consomme ou les produit tels quels. Toute divergence de nom = build cassé. Autorités amont : `NATIVE_SPEC.md` (périmètre), `DESIGN.md` (DA Liquid Glass), `PLAN.md` (implémentation).
>
> **Cible :** SwiftUI, **iOS 17.0 minimum**, 100 % offline (aucun réseau au runtime pour le calcul), RTL hébreu-first, light mode par défaut. Dépendance runtime unique : **KosherCocoa** (SPM).
>
> Conventions : `struct` immuables pour les sorties moteur, `@Observable` pour l'état, `enum String` `Codable` pour les catégories. Toutes les `Date` sont des **instants absolus** (jamais arrondis avant la fin). Un zman absent (latitude extrême) est `nil`, **jamais** `NaN`.

---

## 1. Types du moteur de calendrier (`Engine/EngineModels.swift`)

Portés 1:1 depuis le moteur web `types.ts` / `zmanim.ts` / `hebrewDate.ts` / `calendar.ts` / `personal.ts`. **Ces noms sont gelés** — moteur et UI en dépendent.

### 1.1 Types transverses i18n / géo

```swift
enum Lang: String, Codable, CaseIterable { case he, fr, en }
    // helpers: static func fromSystem() -> Lang ; var dir: LayoutDirection ; var bcp47: String

struct LocalizedText: Codable, Hashable {
    let he: String
    let fr: String
    let en: String
    func callAsFunction(_ lang: Lang) -> String   // usage: names(lang)
}

struct GeoContext {
    let lat: Double
    let lng: Double
    let elevation: Double        // 0 si niveau mer ; utilisée pour lever/coucher SEULEMENT si > 0
    let timeZone: String         // identifiant IANA, ex. "Asia/Jerusalem" — PILOTE le DST
    let name: String?
}
```

### 1.2 Date hébraïque — `HebrewDateResult`

```swift
struct HebrewDateResult: Hashable {
    let year: Int
    let month: Int               // 1..13 (13 = Adar II en année embolismique)
    let day: Int                 // 1..30
    let dayOfWeek: Int           // 1 = dimanche … 7 = samedi
    let isLeapYear: Bool
    let monthName: LocalizedText // he/fr/en via tables maison (hebcal ne connaît que en/he)
    let weekdayName: LocalizedText
    let yearHebrew: String       // "תשפ״ה"
    let dayHebrew: String        // "ט״ו"
}
```

### 1.3 Zmanim — `Zman`, `ZmanimResult`, `ZmanKey`

```swift
// Catalogue figé des 16 zmanim (clés = celles du moteur web / KosherJava getters).
enum ZmanKey: String, CaseIterable {
    case alotHashachar, alotHashachar72, misheyakir, misheyakirMachmir
    case hanetzHachama, sofZmanShmaMGA, sofZmanShmaGRA, sofZmanTfilaMGA, sofZmanTfilaGRA
    case chatzot, minchaGedola, minchaKetana, plagHamincha
    case shkiaHachama, tzeitHakochavim, tzeit72
}

struct Zman: Identifiable {
    var id: String { key }
    let key: String              // rawValue d'un ZmanKey
    let date: Date?              // nil aux latitudes polaires → UI affiche "—"
    let shita: String            // ex. "16.1°", "72 min", "GRA" — TOUJOURS affiché (transparence halakhique)
}

struct ZmanimResult {
    let zmanim: [Zman]           // ordre catalogue
    let byKey: [String: Zman]    // accès O(1) par ZmanKey.rawValue
    let location: GeoContext
    let date: Date               // jour civil calculé
    let candleLighting: Date?    // sunset − candleMinutes (si veille de Chabbat/YT)
    let havdalah: Date?          // 8.5° ou offset minutes
}

// Sous-ensembles d'affichage figés (référence DESIGN §5.1 / §5.3) :
enum ZmanCatalog {
    static let home: [ZmanKey]    // [hanetzHachama, sofZmanShmaGRA, chatzot, minchaGedola, shkiaHachama, tzeitHakochavim]
    static let all:  [ZmanKey]    // ZmanKey.allCases (page ville détaillée)
}
```

### 1.4 Calendrier — événements, fête, jeûne, parasha, Daf, jour

```swift
enum EventCategory: String { case holiday, yomtov, fast, roshchodesh, omer, parasha, other }

struct FastTiming {
    let start: Date?
    let end: Date?
    let is25Hour: Bool           // true = Kippour / 9 Av (coucher veille → tzeit) ; false = mineur (alot → tzeit)
}

struct CalEvent: Identifiable {
    var id: String { desc }
    let desc: String             // identifiant hebcal, ex. "Rosh Hashana"
    let category: EventCategory
    let title: LocalizedText
    let emoji: String?
    let isYomTov: Bool
    let fast: FastTiming?
}

struct ParashaInfo {
    let name: (en: String, he: String)   // hebcal ne fournit que en/he
    let torah: String?
    let haftara: String?                 // ashkénaze
    let haftaraSephardic: String?        // table statique HaftaraSephardic si lib incomplète
}

struct DafYomiInfo {
    let masechet: String
    let daf: String
    let render: (en: String, he: String)
}

struct CalendarDay: Identifiable {
    var id: Date { date }
    let date: Date
    let hebrew: HebrewDateResult
    let events: [CalEvent]
    let omer: Int?               // 1..49 ou nil
    let dafYomi: DafYomiInfo
    let parasha: ParashaInfo?    // renseigné uniquement le Chabbat
    let candleLighting: Date?
    let havdalah: Date?
}
```

### 1.5 Personnel — yahrzeit / anniversaire

```swift
enum PersonType: String, Codable { case yahrzeit, birthday }

struct PersonRecord: Codable, Identifiable, Hashable {
    let id: String               // UUID string
    var type: PersonType
    var name: String
    var date: Date               // date grégorienne d'origine (décès / naissance)
    var afterSunset: Bool        // avance la date hébraïque d'un jour
}

struct Occurrence: Identifiable {
    var id: Date { gregorian }
    let gregorian: Date
    let hebrew: HebrewDateResult
    let hebrewYear: Int
}
```

### 1.6 Préférences (persistées) — `Settings`

```swift
enum CandleMode: Codable, Equatable { case auto; case minutes(Int) }   // auto | 18 | 20 | 30 | 40
enum TzeitMethod: String, Codable { case degrees, minutes }            // 8.5° | offset fixe
enum Region: String, Codable { case auto, il, diaspora }

struct NotifPrefs: Codable, Equatable {
    var shabbat  = false
    var omer     = false
    var hilula   = false
    var yahrzeit = false
}

struct Settings: Codable, Equatable {
    var citySlug: String = "paris"
    var candle: CandleMode = .auto
    var tzeit: TzeitMethod = .degrees
    var region: Region = .auto
    var lang: Lang? = nil        // nil = suivre langue système au 1er lancement
    var notif = NotifPrefs()
}
```

### 1.7 Modèle d'écran « Aujourd'hui » — `TodayModel`

Sortie agrégée consommée par `TodayView` (produite par `AppState.today()`), figée pour éviter que la vue rappelle le moteur pièce par pièce :

```swift
struct TodayModel {
    let city: City
    let hebrew: HebrewDateResult
    let gregorian: Date
    let omer: Int?
    let events: [CalEvent]          // fêtes / RH / jeûne du jour
    let shabbat: ShabbatModel?      // nil si trop loin ou non pertinent
    let homeZmanim: [Zman]          // ZmanCatalog.home résolus
    let keyZmanKey: ZmanKey?        // le "zman clé" surligné (prochain à venir)
    let parasha: ParashaInfo?
    let dafYomi: DafYomiInfo
    let activeFast: FastTiming?
}

struct ShabbatModel {
    let parashaName: LocalizedText
    let candleLighting: Date
    let havdalah: Date?
}
```

---

## 2. API du DesignSystem (`DesignSystem/*`)

Traduction SwiftUI de `DESIGN.md`. **Noms de tokens et de modifiers gelés** — tous les composants et écrans les référencent.

### 2.1 Couleurs — `MoedColor` (`DesignSystem/MoedColor.swift`)

Un color set Asset Catalog par token (variantes Any/Dark). Accès via `Color` statiques :

```swift
enum MoedColor {
    // Fond / surfaces
    static let canvas, canvasGradientTop, canvasGradientBottom: Color
    static let surface, surfaceDeep, line, lineStrong: Color
    // Encre
    static let ink, inkSoft, inkMute: Color
    // Flamme (ner)
    static let ner, nerStrong, nerGlow, nerWash: Color
    // Crépuscule & sémantique
    static let twilight, twilightWash: Color
    static let sage, sageWash, rose, roseWash, focus: Color
}
```
> Dark présent dans l'asset catalog mais **non branché** en v1 (`.preferredColorScheme(.light)` forcé à la racine). `Material` Apple s'inverse seul le jour venu.

### 2.2 Typographie — `MoedFont` (`DesignSystem/MoedFont.swift`)

Polices embarquées (Fraunces, Frank Ruhl Libre, Instrument Sans, Assistant) déclarées `UIAppFonts`. Chaque style mappé à un `Font.TextStyle` (Dynamic Type). Sélection latin/hébreu par `Lang` actif.

```swift
enum MoedFont {
    static func hero(_ lang: Lang) -> Font        // 40 Semibold Display / .largeTitle
    static func title1(_ lang: Lang) -> Font      // 30 Semibold Display / .title
    static func title2(_ lang: Lang) -> Font      // 24 Medium Display / .title2
    static func title3(_ lang: Lang) -> Font      // 20 Medium Display / .title3
    static func body(_ lang: Lang) -> Font        // 16 Regular Body / .body
    static func bodyEmph(_ lang: Lang) -> Font    // 16 Semibold Body / .body
    static func callout(_ lang: Lang) -> Font     // 15 Regular Body / .callout
    static func caption(_ lang: Lang) -> Font     // 13 Medium Body / .caption
    static func micro(_ lang: Lang) -> Font       // 11 Semibold Body / .caption2 (uppercase +8% tracking)
    static func zmanTime(_ lang: Lang) -> Font    // 22 Medium Display, .monospacedDigit() OBLIGATOIRE
}

// Modifier hébreu +4 % (équilibre couleur typographique)
extension View { func hebrewBalanced(_ lang: Lang) -> some View }   // scale ×1.04 si lang == .he
```

### 2.3 Formes, élévations — `MoedRadius`, `MoedElevation`

```swift
enum MoedRadius { static let sm: CGFloat = 10; static let md: CGFloat = 16; static let lg: CGFloat = 26 }
    // capsule = SwiftUI Capsule() ; toujours RoundedRectangle(cornerRadius:, style: .continuous)

enum MoedElevation {                       // ombres TEINTÉES ink, jamais noires
    static func e1<V: View>(_ v: V) -> some View   // y2  blur10 ink@0.06
    static func e2<V: View>(_ v: V) -> some View   // y6  blur22 ink@0.10
    static func e3<V: View>(_ v: V) -> some View   // y16 blur44 ink@0.16
    static func glowNer<V: View>(_ v: V) -> some View  // y0 blur30 nerGlow@0.30 — zman clé / allumage UNIQUEMENT
}
// Espacement (échelle 4px) : constantes MoedSpace.{s2,s4,s8,s12,s16,s20,s24,s32,s40,s56,s72,s96}
// pagePadding = 20, interCard = 16, cardPadding = 20 (16 compact)
```

### 2.4 Verre (abstraction iOS 17↔26) — `GlassBackground` (`DesignSystem/GlassBackground.swift`)

Abstraction clé : rend `.glassEffect` sous iOS 26, retombe sur `.regularMaterial` + bordure/ombre en iOS 17–25. **Respecte Reduce Transparency** (→ `surface` opaque).

```swift
enum GlassStyle { case chrome, float, sheet }   // glassChrome, glassFloat(tint ner), glassSheet

struct GlassBackground: ViewModifier {
    let style: GlassStyle
    var tint: Color? = nil
    // if #available(iOS 26): .glassEffect(.regular.tint(tint)) ; else .regularMaterial + lineStrong + e2
    // if accessibilityReduceTransparency: MoedColor.surface opaque + bordure lineStrong
}
extension View {
    func glass(_ style: GlassStyle, tint: Color? = nil) -> some View
}
```
> Règle d'or DA : verre = chrome/contrôles flottants uniquement, jamais sous du contenu de lecture, jamais verre sur verre. Le contenu lisible utilise `cardSolid` (voir Components §3).

### 2.5 Canvas, RTL, Haptique

```swift
// CanvasBackground.swift — fond racine immobile "parchemin d'aube"
struct CanvasBackground: View { }   // LinearGradient(top→bottom) + RadialGradient(nerGlow@0.03,.top,420) .ignoresSafeArea()

// RTL.swift — direction + LTR forcé pour les chiffres
struct ForceLTR<Content: View>: View { }        // .environment(\.layoutDirection, .leftToRight) — enveloppe TOUTE heure/compte à rebours
extension Image { func directionalMirror() -> some View }   // .flipsForRightToLeftLayoutDirection(true) pour chevrons/flèches ; JAMAIS bougie/lune
// gestion langue : environment(\.moedLang) + environment(\.layoutDirection, lang.dir) posés à la racine

// Haptics.swift — sémantique, jamais sur scroll/tick
enum Haptic { case selection, success, remove, error, monthChange, toggleOn, shabbatEntry }
extension View { func haptic(_ h: Haptic, trigger: some Equatable) -> some View }   // wrappe .sensoryFeedback
```

### 2.6 Environnement partagé

```swift
extension EnvironmentValues {
    var moedLang: Lang { get set }        // défaut Lang.fromSystem()
}
// La racine (RootView) pose : .environment(\.moedLang, appState.lang)
//                              .environment(\.layoutDirection, appState.layoutDirection)
//                              .preferredColorScheme(.light)
```

---

## 3. Source des données (moteur offline + datasets statiques)

### 3.1 Moteur de calcul — quel algo / lib

- **Lib runtime unique : KosherCocoa** (`github.com/MosheBerman/KosherCocoa`, SPM, `from: "4.0.0"`) — port officiel Objective-C/Swift de KosherJava par Moshe Berman. Contrepartie iOS directe de `kosher-zmanim` (JS) et `KosherJava 2.5.0` (Android) ⇒ **parité de calcul garantie**, algorithme solaire NOAA.
  - `KCComplexZmanimCalendar` + `KCGeoLocation` → les 16 zmanim, allumage, havdala.
  - `KCJewishCalendar` → fêtes (holidayIndex), Omer (dayOfOmer), Roch Hodech, molad, règles yahrzeit (Cheshvan-30 / Kislev-30 / Adar).
  - `KCHebrewDateFormatter` → `yearHebrew` / `dayHebrew`.
  - `KCDafYomiCalculator` → Daf Yomi (table de secours si lacune).
- **Tables statiques maison** (lacunes lib, `Engine/`) :
  - `HebrewMonthTables.swift` — noms mois/jours **he/fr/en** (hebcal/KosherJava ne connaissent que en/he ; **ne jamais** demander le rendu `fr` à la lib).
  - `HaftaraSephardic.swift` — haftara **sépharade** + distinguo Israël/diaspora si KosherCocoa ne couvre pas (table dérivée de `@hebcal/leyning`).
- **Aucun appel réseau au runtime.** Pas de client HTTP, pas de backend, pas de compte, pas de token applicatif. Le PocketBase `pocketbase-moed` et les routes push VAPID du repo web ne sont **pas portés**.
- **Validation build-time** : `ZmanimValidationTests` rejoue une matrice **10 villes × 2 ans × 4 types** contre `Fixtures/kosher_zmanim_reference.json` (figé, offline). Barre : dates 0 tolérance, zmanim ≤ 2 min. **Aucune UI ne démarre tant que la validation n'est pas PASS.**

### 3.2 Signatures du moteur (protocoles gelés)

Chaque sous-moteur est un type sans état exposant des méthodes pures (entrées → sorties §1). Signatures contractuelles consommées par `AppState` / ViewModels :

```swift
enum HebrewDateEngine {
    static func convert(_ date: Date, afterSunset: Bool, geo: GeoContext, lang: Lang) -> HebrewDateResult
    static func toGregorian(year: Int, month: Int, day: Int) -> Date?          // converter héb→grég
    static func molad(year: Int, month: Int) -> Date
}

enum ZmanimEngine {
    static func zmanim(date: Date, geo: GeoContext, settings: Settings) -> ZmanimResult
}

enum CandleEngine {
    static func candleLighting(date: Date, geo: GeoContext, candle: CandleMode, cityMinutes: Int) -> Date?
    static func havdalah(date: Date, geo: GeoContext, tzeit: TzeitMethod) -> Date?
}

enum CalendarEngine {
    static func day(_ date: Date, geo: GeoContext, region: Region, lang: Lang) -> CalendarDay
    static func range(start: Date, end: Date, geo: GeoContext, region: Region, lang: Lang) -> [CalendarDay]
    static func parasha(week of: Date, region: Region) -> ParashaInfo?
    static func dafYomi(_ date: Date) -> DafYomiInfo
}

enum PersonalEngine {
    static func occurrences(of person: PersonRecord, from: Date, count: Int, geo: GeoContext, lang: Lang) -> [Occurrence]
    // garde-fou anti-boucle : count + 200 ans
}

enum Gematria {
    static func value(of word: String) -> Int                 // mispar hechrachi
    static func breakdown(of word: String) -> [(letter: Character, value: Int)]
}
```

### 3.3 Datasets embarqués — `Data/`

```swift
// City.swift — parité cities.ts (191 villes, format RICHE conservé côté iOS)
struct City: Codable, Identifiable {
    var id: String { slug }
    let slug: String
    let names: LocalizedText
    let country: String              // ISO2
    let countryNames: LocalizedText
    let lat: Double
    let lng: Double
    let elevation: Double?
    let tz: String                   // IANA
    let israel: Bool
    let candleMinutes: Int           // Jérusalem 40 / Haïfa,Petah Tikva,Beer Sheva 30 / défaut 18 / 20
    let community: Int?
    func geoContext(candleMode: CandleMode) -> GeoContext
}

// Tsadik.swift — parité tsadikim.ts (32 fiches)
enum TsadikCategory: String, Codable { case tanna, rishon, acharon, hassid, habad, sefarade }
enum Confidence: String, Codable { case high, medium, traditional }
struct HilulaDate: Codable { let day: Int; let month: String }   // mois hébreu translittéré EN
struct Kever: Codable { let place: String; let country: String }
struct Tsadik: Codable, Identifiable {
    var id: String { slug }
    let slug: String
    let names: LocalizedText
    let epithet: LocalizedText?
    let category: TsadikCategory
    let hilula: HilulaDate
    let hilulaNote: LocalizedText?
    let yearGregorian: Int?
    let kever: Kever?
    let works: [String]?
    let bio: LocalizedText
    let confidence: Confidence
    let sources: [String]
}

// StaticData.swift — chargement paresseux + cache des JSON bundlés
enum StaticData {
    static var cities: [City]                        // lazy depuis Resources/cities.json
    static var tsadikim: [Tsadik]                    // lazy depuis Resources/tsadikim.json
    static func city(slug: String) -> City           // fallback "paris" si introuvable
    static func tsadik(slug: String) -> Tsadik?
    static func hilulotToday(hebrew: HebrewDateResult) -> [Tsadik]   // filtre hilula == date héb courante
}
```
> Ressources : `Data/Resources/cities.json` (exporté de `src/data/cities.ts`), `tsadikim.json` (de `src/data/tsadikim.ts`). Format riche : tous les champs trilingues + `candleMinutes` + `israel`.

### 3.4 i18n — `L10n` (`i18n/L10n.swift`)

```swift
enum L10n {
    static func t(_ key: String, _ lang: Lang) -> String
    static func t(_ key: String, _ lang: Lang, _ args: [String: CVarArg]) -> String   // {n}, {city} → %lld/%@
}
// Localizable.strings he/fr/en portés de src/messages/{he,fr,en}.json
// Sections : meta brand nav common home zmanim converter personal tsadikim calendar settings
// (install / offline ignorés en natif). Chaînes paramétrées : home.omerDay {n}, zmanim.pageTitle {city}
```

---

## 4. Structure de l'app (entry, navigation, stores)

### 4.1 App entry & navigation (`App/`)

```swift
@main struct MoedApp: App {
    @State private var appState = AppState()          // @Observable racine
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.moedLang, appState.lang)
                .environment(\.layoutDirection, appState.layoutDirection)   // .rightToLeft si he
                .preferredColorScheme(.light)                                // light forcé v1
        }
    }
}

struct RootView: View {   // TabView 5 onglets (ordre logique → miroité auto en RTL), CanvasBackground global
    // onglets figés : today (sun.max), calendar (calendar), personal (person.2),
    //                 tsadikim (flame), settings (gearshape) — actif teinté ner, inactif inkMute
}
```

Sous-navigation : chaque onglet possède son `NavigationStack`. Détails poussés : `TsadikDetailView` (depuis Tsadikim), `ZmanimCityView` + `ConverterView` (depuis Today/Zmanim), `CitySearchView` (sheet depuis Settings & en-tête Today). `AddPersonSheet` = sheet `.presentationDetents([.medium, .large])` depuis Personnel.

### 4.2 Stores & état (`Store/`)

```swift
@Observable final class AppState {
    var settings: Settings          // persisté via SettingsStore
    var family: [PersonRecord]      // persisté via FamilyStore
    var now: Date                   // tick 1 s (Timer) → compte à rebours

    // Dérivés synchrones (recalcul instantané offline au changement ville/minhag/langue) :
    var city: City { StaticData.city(slug: settings.citySlug) }
    var geo: GeoContext { city.geoContext(candleMode: settings.candle) }
    var lang: Lang { settings.lang ?? Lang.fromSystem() }
    var layoutDirection: LayoutDirection { lang == .he ? .rightToLeft : .leftToRight }

    // API consommée par les vues (pas d'appel moteur direct depuis l'UI) :
    func today() -> TodayModel
    func zmanim(date: Date) -> ZmanimResult
    func calendar(monthOffset: Int) -> [CalendarDay]
    func occurrences(_ p: PersonRecord) -> [Occurrence]

    // Mutations
    func addPerson(_ p: PersonRecord)      // + reschedule notifs
    func removePerson(id: String)
    func update(settings: Settings)        // persiste + recalcule dérivés + reschedule notifs
}

// SettingsStore.swift — UserDefaults(suiteName: appGroup) "group.com.wizycode.moed"
enum SettingsStore {
    static func load() -> Settings
    static func save(_ s: Settings)
}

// FamilyStore.swift — JSON "moed_family" dans le container App Group (rien ne quitte l'appareil)
enum FamilyStore {
    static func load() -> [PersonRecord]
    static func save(_ people: [PersonRecord])
}

// LocationProvider.swift — CLLocationManager opt-in → ville la plus proche
final class LocationProvider: NSObject {
    func requestNearestCity(_ completion: @escaping (City?) -> Void)
}
```

App Group `group.com.wizycode.moed` partagé app ↔ widgets. Bundle app `com.wizycode.moed`, scheme `Moed` (attendus par le Fastfile CI).

### 4.3 ViewModels d'écran

Légers, un par écran riche quand nécessaire (sinon la vue lit `AppState` directement) : `TodayViewModel`, `CalendarViewModel` (gère `monthOffset`), `CitySearchView` (filtre 191 villes). Ils **ne recalculent pas** — ils appellent l'API `AppState` (§4.2).

### 4.4 Notifications & widgets (targets)

```swift
// Notifications/ — UNUserNotificationCenter, UNCalendarNotificationTrigger, opt-in au moment de l'activation
enum NotificationScheduler {
    static func reschedule(settings: Settings, family: [PersonRecord], geo: GeoContext, lang: Lang)
    // fenêtre glissante des N prochaines occurrences : shabbat, omer(49j), hilula, yahrzeit, fêtes/jeûnes
}
enum BackgroundRefresh { static func register(); static func schedule() }   // BGTaskScheduler (id Info.plist)

// MoedWidgets/ — WidgetKit ; TimelineProvider recalcule LOCALEMENT via App Group (Engine + Data partagés)
// Widgets figés : CandleWidget (small/medium + Lock Screen), ZmanimWidget (medium), OmerWidget (small + Lock Screen)
```

Partage app ↔ widget : dossiers `Engine/`, `Data/`, tokens couleur déclarés dans **les deux** cibles (`Moed` + `MoedWidgets`) via double target membership `project.yml` — pas de framework séparé.

---

## 5. Découpage en modules (voir sortie structurée)

Résumé de la topologie contractuelle (dépendances descendantes uniquement) :

```
Models ──────────────┐
   ▲                 │
CalendarEngine ◄── Zmanim ◄── Data ◄── Store ◄── Screens ◄── App
   ▲                              ▲        ▲          ▲
   └── DesignSystem ◄── Components ┘        │          │
                          Notifications ────┘          │
                          Widgets ──────────────────────┘
```
Chaque module est détaillé dans la sortie structurée (`StructuredOutput.modules`).
