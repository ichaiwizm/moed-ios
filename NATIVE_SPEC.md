# Moed — Spécification produit pour réimplémentation NATIVE (iOS + Android)

> מועד — « le temps fixé ». Le compagnon du calendrier juif (louah), mondial, trilingue **hébreu (RTL) / français / anglais** à parité.
> **Principe non négociable : coût marginal ≈ zéro.** Tout le calcul (dates hébraïques, zmanim, anniversaires, fêtes) est **100 % on-device, déterministe, offline**. Aucun appel serveur par usage. Gratuit, sans pub, sans compte.
> Ce document décrit le produit tel qu'il existe (référence : PWA Next.js `/root/apps/mvp-moed` + app Android Kotlin `/root/apps/mvp-moed/android`) et la façon de le porter en **natif iOS (SwiftUI)** et **natif Android (Jetpack Compose)**.

---

## 0. Résumé exécutif

Moed est un « louah » (calendrier juif) de poche : il répond à *quelle est la date hébraïque aujourd'hui, à quelle heure allumer les bougies de Chabbat, quels sont les zmanim (horaires halakhiques) de ma ville, quelle est la parasha, où en est le Omer, quels tsadikim ont leur hiloula aujourd'hui, et quand tombe le prochain yahrzeit / anniversaire hébraïque de mes proches*. Il envoie des rappels (allumage, Omer, yahrzeit, fêtes). Il fonctionne **sans réseau** et **sans backend** : toute la logique astronomique/halakhique tourne sur l'appareil à partir de bibliothèques déterministes et de datasets statiques embarqués.

Cibles : PWA (existante), **Android natif** (existante, Kotlin/Compose), et **iOS natif** (à créer, SwiftUI). L'app doit se sentir NATIVE sur chaque plateforme (navigation, widgets home-screen, notifications locales, offline complet, thème système, gestes).

Le seul « backend » optionnel est un serveur de Web Push pour la version web (VAPID) — **inutile en natif** : iOS et Android planifient leurs notifications **localement** (pas besoin de push serveur pour les rappels calculables à l'avance, ce qui est le cas de tous les rappels de Moed).

---

## 1. Périmètre fonctionnel (ce que fait l'app)

### 1.1 Moteur calendrier & temps
- **Conversion date hébraïque ⇄ grégorienne**, passé et futur, dans les deux sens.
- **Zmanim quotidiens** par ville / géoloc : alot hashahar, misheyakir, netz (lever), sof zman kriat shema (MGA + GRA), sof zman tefila (MGA + GRA), hatzot, minha guedola, minha ketana, plag haminha, shkia (coucher), tzeit hakohavim (multi-shitot), tzeit Rabbeinu Tam. **Multi-shitot** avec label de la shita affiché.
- **Allumage des bougies + havdala** (Chabbat & Yom Tov), par ville, selon le minhag (offset d'allumage 18/20/30/40 min ; havdala en degrés ou minutes).
- **Parashat hashavoua + haftara** (Ashkénaze + Sépharade), avec distinction **Israël / diaspora**.
- **Fêtes (hagim)**, Roch Hodech, jeûnes (avec heures de début/fin calculées par zmanim), Chol Hamoed.
- **Sefirat HaOmer** (compte du jour) + **Daf Yomi** (page du jour).
- **Molad** du mois hébraïque, événements du calendrier.
- **Vue calendrier mensuelle** défilable (mois précédent/suivant) listant les événements de chaque jour.

### 1.2 Personnel & récurrent (cœur de la rétention)
- **Anniversaire hébraïque** : saisie d'une date grégorienne → date hébraïque + prochaines occurrences grégoriennes.
- **Yahrzeit** (anniversaire de décès) : saisie de la date de décès → date hébraïque, prochaines occurrences, rappel du kaddish. Règles halakhiques Cheshvan-30 / Kislev-30 / Adar (année embolismique) gérées par la lib.
- **Carnet familial** : liste locale de proches (anniversaires + yahrzeits), stockée **on-device** (pas de compte). Rappels annuels automatiques.
- Flag « **après le coucher du soleil** » (afterSunset) pour ancrer correctement la date hébraïque d'un événement survenu après la tombée de la nuit.

### 1.3 Tsadikim / Hiloulot
- **Hiloula du jour** : « quels tsadikim sont décédés à cette date hébraïque » + biographie sourcée trilingue.
- **Répertoire** des tsadikim (dataset statique, ~32 fiches), fiche détaillée (dates de hiloula, kever, œuvres, bio, sources, niveau de confiance).
- **Sensibilité éditoriale** : jamais de faux portrait photoréaliste. Visuels symboliques par courant (tanna / rishon / hassid / habad / sefarade), motifs de kever / bougie.

### 1.4 Guématria
- Calcul de la valeur numérique standard (mispar hechrachi) d'un mot hébreu, avec décomposition par lettre. (Présent dans le moteur ; page dédiée = v2 côté web.)

### 1.5 Notifications (toutes opt-in)
- **Vendredi** : « Chabbat entre à HH:MM, allumage dans X ».
- **Rappel anniversaire hébraïque** (soi + carnet familial).
- **Rappel yahrzeit + kaddish**.
- **Omer quotidien** pendant la période (49 jours).
- **Hiloula du jour** (+ mini-bio).
- **Fêtes / jeûnes à venir**.

En natif, **toutes ces notifications sont locales et planifiées à l'avance** (les dates sont déterministes). Aucune dépendance à un serveur push.

---

## 2. Écrans & navigation

Navigation principale à **5 onglets** (bottom nav mobile / side rail desktop-web). Ordre et clés identiques sur web et Android natif :

| Onglet | Clé | Rôle |
|---|---|---|
| **Aujourd'hui** | `today` | Écran d'accueil / dashboard du jour |
| **Calendrier** | `calendar` | Vue mensuelle des événements |
| **Personnel** | `personal` | Carnet familial (anniversaires / yahrzeits) |
| **Tsadikim** | `tsadikim` | Hiloula du jour + répertoire |
| **Réglages** | `settings` | Langue, ville, minhag, notifications |

Écrans secondaires (web) à conserver comme sous-vues natives :
- **Zmanim par ville** (page détaillée d'une ville : allumage du Chabbat, tous les zmanim, disclaimer, villes proches).
- **Convertisseur de dates** (grég ⇄ hébreu).
- **Fiche tsadik** (détail).
- **Offline** (état hors-ligne — surtout web ; en natif, l'app est offline par nature).

### 2.1 Écran « Aujourd'hui » (dashboard)
Contenu (dans l'ordre) :
1. **En-tête date** : ville active (avec icône localisation), **date hébraïque** formatée dans la langue, date grégorienne, badges (jour du Omer, fête / Yom Tov / Roch Hodech du jour).
2. **Carte Chabbat (feature)** : titre « prochain Chabbat », heure d'allumage des bougies, **compte à rebours** live (« allumage dans X »), heure de havdala. Illustration bougies.
3. **Zmanim clés du jour** (sous-ensemble « HOME_ZMANIM ») : lignes zman (icône + label + heure), lien « tous les zmanim ».
4. **Parasha** de la semaine (nom + haftara), **Daf Yomi** du jour.
5. Éventuels états : fête en cours, jeûne (début/fin).

Comportements : l'heure se rafraîchit chaque seconde (compte à rebours). Tout est recalculé quand la ville / le minhag / la langue changent. Skeleton au montage (hydratation web) — en natif, calcul synchrone instantané.

### 2.2 Écran « Calendrier »
- Titre = mois + année (dans la langue). Boutons mois précédent / suivant (offset).
- Liste des jours du mois avec, par jour : date hébraïque, badges d'événements colorés par catégorie (fête=or/ner, jeûne=rose, roch hodech=twilight, omer=sage, autre=neutre).
- Source : `getCalendarRange(start, end, { il, geo, locale })`.

### 2.3 Écran « Personnel » (carnet familial)
- Liste des proches enregistrés ; pour chacun : nom, type (anniversaire/yahrzeit), **prochaine occurrence** (date grégorienne + date hébraïque), badge « né le / décédé le ».
- Bouton **Ajouter** → formulaire : type (segmented yahrzeit/birthday), nom, date (date picker), toggle « après le coucher du soleil ».
- Suppression par item.
- **Persistance locale** : web = `localStorage` clé `moed_family` (tableau de `{id, type, name, date, afterSunset}`). Natif = base locale (voir §7).
- Bloc opt-in notifications (rappels).
- État vide illustré (empty state).

### 2.4 Écran « Tsadikim »
- **Section « Hiloula du jour »** : tsadikim dont `hilula` (jour+mois hébreu) == date hébraïque courante → cartes bio. Si aucun : état « personne aujourd'hui ».
- **Répertoire complet** : liste/grille des ~32 tsadikim.
- **Fiche détail** (route `tsadikim/[slug]`) : nom (trilingue), épithète, catégorie, date de hiloula (+ note ex. « Lag BaOmer »), prochaine hiloula, kever (lieu/pays), œuvres, bio longue, **badge de confiance** (high/medium/traditional), **sources** (liens), note sur le visuel symbolique.

### 2.5 Écran « Réglages »
Sections :
- **Langue** : he / fr / en (change la locale + la direction RTL/LTR).
- **Localisation** : recherche de ville (CitySearch sur le dataset des 189 villes) → définit la ville active.
- **Minhag** :
  - Minutes d'allulmage : segmented `auto` (= minhag de la ville) / 18 / 20 / 30 / 40.
  - Shita de tzeit/havdala : `degrees` (8.5°, « 3 étoiles ») / `minutes` (fixe après coucher).
  - Israël / Diaspora : `auto` (selon la ville) / `il` / `diaspora`.
- **Notifications** : toggles opt-in (shabbat, omer, hilula, yahrzeit) + description + demande de permission système.
- **Installer** (web PWA) — sans objet en natif.

### 2.6 Convertisseur de dates
- Direction segmented : grég→hébreu / hébreu→grég.
- Grég→héb : date picker → date hébraïque formatée.
- Héb→grég : sélecteurs jour (1–30) / mois hébreu / année → date grégorienne. Gestion de l'invalide.

---

## 3. Logique de calcul — **client-side, déterministe, validée**

### 3.1 Est-ce client-side ? OUI — 100 %, sans réseau au runtime
> « Zero network access at runtime — every value is computed locally. » (README du moteur.)
Le seul fichier qui touche le réseau est `validate.mjs`, un **outil de build** qui compare le moteur à l'API publique Hebcal ; il n'est jamais embarqué dans l'app.

### 3.2 Bibliothèques / algorithmes utilisés

**Web (référence)** — `/root/apps/mvp-moed/src/lib/engine/` :
- **`@hebcal/core`** (v5) : `HDate` (conversion grég⇄hébreu basée Rata Die, exacte passé/futur), `HebrewCalendar` (fêtes, jeûnes, Roch Hodech, Omer, sedra), `Molad`, `flags`, `getYahrzeit`, `getBirthdayOrAnniversary`.
- **`@hebcal/learning`** : `DafYomi`.
- **`@hebcal/leyning`** : `getLeyningOnDate` (parasha + haftara + haftara sépharade).
- **`kosher-zmanim`** (v0.9, port JS de KosherJava) : `ComplexZmanimCalendar` + `GeoLocation`, **algorithme solaire NOAA**, pour tous les zmanim / allumage / havdala.

**Android natif (référence)** — `/root/apps/mvp-moed/android` :
- **KosherJava** `com.kosherjava:zmanim:2.5.0` — `JewishCalendar`, `HebrewDateFormatter`, `YomiCalculator` (Daf Yomi), `ComplexZmanimCalendar`, `GeoLocation`. Même modèle de calcul que kosher-zmanim (kosher-zmanim EST le port JS de KosherJava → **résultats identiques**).

**iOS natif (à créer)** — recommandation :
- Utiliser **KosherCocoa** (port Objective-C/Swift officiel de KosherJava, par Moshe Berman) pour les zmanim et le calendrier hébraïque (`KCComplexZmanimCalendar`, `KCJewishCalendar`, `KCGeoLocation`). C'est la contrepartie iOS directe de KosherJava/kosher-zmanim ⇒ parité de calcul garantie.
- **Alternative / complément** : `Foundation` fournit `Calendar(identifier: .hebrew)` pour la conversion de dates hébraïques natives Apple (utile pour formatage localisé), mais **KosherCocoa reste la source de vérité** pour rester bit-à-bit cohérent avec les autres plateformes (mêmes shitot, mêmes noms de mois, mêmes règles yahrzeit). Pour parasha/haftara/Daf Yomi/Omer, KosherCocoa couvre l'essentiel ; si une lacune apparaît (haftara sépharade), porter les tables depuis `@hebcal/leyning` ou embarquer un petit dataset statique.
- **Exigence dure** : quelle que soit la lib iOS choisie, elle DOIT être **validée** contre les mêmes références que le moteur web (voir §3.6). Aucune divergence > tolérance n'est acceptable (les gens jeûnent et allument selon ces heures).

### 3.3 Zmanim implémentés (catalogue, avec shitot)

| key | shita | source getter (kosher-zmanim / KosherJava) |
|---|---|---|
| `alotHashachar` | 16.1° | `getAlos16Point1Degrees` |
| `alotHashachar72` | 72 min | `getAlos72` |
| `misheyakir` | 11.5° | `getMisheyakir11Point5Degrees` |
| `misheyakirMachmir` | 10.2° | `getMisheyakir10Point2Degrees` |
| `hanetzHachama` | lever (sunrise) | `getSunrise` |
| `sofZmanShmaMGA` | MGA 72 min | `getSofZmanShmaMGA` |
| `sofZmanShmaGRA` | GRA | `getSofZmanShmaGRA` |
| `sofZmanTfilaMGA` | MGA 72 min | `getSofZmanTfilaMGA` |
| `sofZmanTfilaGRA` | GRA | `getSofZmanTfilaGRA` |
| `chatzot` | midi astronomique | `getChatzos` |
| `minchaGedola` | GRA (½ shaʿah) | `getMinchaGedola` |
| `minchaKetana` | GRA (9½ shaʿot) | `getMinchaKetana(sunrise, sunset)` |
| `plagHamincha` | GRA (10¾ shaʿot) | `getPlagHamincha(sunrise, sunset)` |
| `shkiaHachama` | coucher (sunset) | `getSunset` |
| `tzeitHakochavim` | 8.5° (3 étoiles) | `getTzaisGeonim8Point5Degrees` |
| `tzeit72` | 72 min (Rabbeinu Tam) | `getTzais72` |

- **Allumage bougies** = `sunset − candleMinutes` (défaut 18 ; minhagim 18/20/30/40).
- **Havdala** = 8.5° sous l'horizon (défaut, « 3 étoiles ») OU offset fixe (42 / 50 / 72 min après le coucher).

### 3.4 Règles & edge cases (à reproduire à l'identique)
- **Timezone / DST** : piloté par l'**identifiant IANA** de la ville (ex. `Asia/Jerusalem`), pas par l'offset fixe du device → correct pour toute date/lieu. En iOS : `TimeZone(identifier:)`.
- **Latitudes extrêmes** : si le soleil n'atteint jamais l'angle requis, le zman vaut **null** (jamais NaN) → l'UI doit gérer l'absence.
- **Le jour hébraïque commence au coucher** : conversions et occurrences acceptent un flag `afterSunset` qui avance la date hébraïque d'un jour.
- **Élévation** : utilisée pour lever/coucher seulement si `elevation > 0` ; sinon niveau de la mer (aligne sur le défaut Hebcal lat/lng).
- **Arrondi** effectué seulement à la fin (instants `Date` bruts conservés).
- **Israël vs Diaspora** : flag `il` change le calendrier des fêtes, la parasha et la haftara (2e jour de Yom Tov en diaspora, décalages de sedra).
- **Fêtes / jeûnes** : timing des jeûnes dérivé des zmanim — mineur = alot→tzeit ; majeur 25h (Kippour, 9 Av) = coucher de la veille→tzeit.
- **Piège hebcal (web)** : `@hebcal/*` ne connaît que les locales `en`/`he`. Ne jamais passer `locale:'fr'` au rendu hebcal ; le français retombe sur `en`. Les **noms de mois/jours FR sont fournis par des tables locales** (voir `hebrewDate.ts`). → En natif, prévoir des **tables de traduction maison** pour he/fr/en (mois hébreux, jours de semaine, libellés de zmanim, titres de fêtes si on veut du FR).

### 3.5 Personnel (yahrzeit / anniversaire)
- Yahrzeit : `HebrewCalendar.getYahrzeit(hyear, anchor)` (KosherJava : équivalent `JewishCalendar` yahrzeit) — applique les règles Cheshvan-30 / Kislev-30 / Adar.
- Anniversaire : `HebrewCalendar.getBirthdayOrAnniversary`.
- Énumération : à partir de l'année hébraïque de `from`, avancer année par année jusqu'à obtenir `count` occurrences ≥ `from` (comparaison au jour, temps ignoré). Garde-fou anti-boucle (`count + 200` ans).

### 3.6 Validation (OBLIGATOIRE, barre halakhique)
Le moteur web est validé par `validate.mjs` contre l'API publique Hebcal (`/converter`, `/zmanim`, `/shabbat`) sur une matrice **10 villes × 2 années × 4 types de dates** :
- Dates hébraïques : correspondance **exacte** (0 tolérance).
- Zmanim/allumage/havdala : idéal ±1 min, **échec si > 2 min**.
- **Dernier résultat : dates 8/8 exactes ; zmanim 1279/1280 ≤1 min, 1/1280 à ≤2 min, 0 échec → PASS.** (Seul résidu : un `chatzot` Montréal à 1.02 min dû à l'arrondi Hebcal.)
- Rapport écrit dans `validation-report.json`.

**Pour iOS** : rejouer la même matrice avec KosherCocoa et comparer soit à Hebcal, soit **directement aux sorties de kosher-zmanim/KosherJava** (référence interne). Livrer un rapport de validation équivalent avant toute mise en production. Documenter les shitot implémentées et afficher un **disclaimer halakhique** + la **source/shita** utilisée (déjà présent : `Disclaimer` sur la page zmanim).

---

## 4. Données statiques nécessaires (embarquées, zéro coût)

Tout est bundlé côté client. À porter tel quel (JSON/Swift/Kotlin) dans le natif.

### 4.1 Villes — `src/data/cities.ts` (~189 villes)
Type par ville :
```
slug (kebab-case unique), names {fr,en,he}, country (ISO2),
countryNames {fr,en,he}, lat, lng, tz (IANA), elevation? (m),
israel (bool), candleMinutes (int), community? (population approx)
```
Convention `candleMinutes` : Jérusalem 40 ; Haïfa/Petah Tikva/Beer Sheva 30 ; défaut 18 ; quelques communautés 20. Couverture forte francophone (~50 villes France) + Israël + US + UK + CA + BE/CH/AR/AU/MA/NL/DE/IT/ES/BR/ZA/RU/UA/MX. **Livrer ce dataset en asset natif** (ex. `cities.json`). Fonction utilitaire `getCity(slug)`.

### 4.2 Tsadikim — `src/data/tsadikim.ts` (~32 fiches)
Type par tsadik :
```
slug, names {fr,en,he}, epithet? {fr,en,he},
category ('tanna'|'rishon'|'acharon'|'hassid'|'habad'|'sefarade'),
hilula {day, month(EN translittéré)}, hilulaNote? {fr,en,he},
yearGregorian?, kever? {place, country}, works? [],
bio {fr,en,he}, confidence ('high'|'medium'|'traditional'), sources []
```
Répartition actuelle : sefarade 8, acharon 7, tanna 5, hassid 5, habad 3, rishon 3. **Biographies pré-générées trilingues** (jamais de LLM au runtime). **Sourcées** (Wikipedia / Sefaria). Visuels **symboliques par catégorie** (assets `tsadikim/motif-*`, `kever`, `hilula-candle`) — jamais de faux portrait.

### 4.3 Assets visuels (générés une fois via kie.ai, à embarquer)
- Marque : `logo-mark`, `logo-mark-ink`, `app-icon`, `og-base`, `hero`.
- Illustrations : candles, zmanim, parasha, omer, molad, synagogue, birthday, yahrzeit.
- Empty states : family, offline, search.
- Tsadikim : motifs par courant + kever + bougie de hiloula.
En natif : intégrer comme assets d'app (PNG / vecteurs), tailles multiples densités (iOS @1x/@2x/@3x, Android mdpi→xxxhdpi). App icon Moed = concept « croissant du molad → flamme » (voir §6).

### 4.4 Traductions (i18n)
Dictionnaires `src/messages/{fr,en,he}.json`, clés par section : `meta, brand, nav, common, home, zmanim, converter, personal, tsadikim, calendar, settings, install, offline`. À porter en `Localizable.strings` (iOS) / `strings.xml` + table Compose (Android — voir `Localization.kt`). **Attention** : certaines chaînes prennent des paramètres (ex. `home.omerDay {n}`, `zmanim.pageTitle {city}`).

---

## 5. Langues & RTL

- **3 langues à parité** : hébreu (`he`, **RTL, langue primaire du produit**), français (`fr`, LTR), anglais (`en`, LTR). Défaut de code : `fr`.
- `localeDir` : he=rtl, fr/en=ltr. `localeTag` (BCP-47) : he-IL, fr-FR, en-US (pour formatage `Intl`/`DateFormatter`).
- **RTL première classe** (voir `design/DA.md §5`) :
  - iOS : `environment(\.layoutDirection, .rightToLeft)` pour `he` ; utiliser propriétés logiques (leading/trailing), jamais left/right en dur ; SwiftUI gère le miroir automatique, forcer pour icônes directionnelles.
  - Android : `LocalLayoutDirection` / `supportsRtl`, propriétés `start/end`.
  - **Icônes directionnelles** (chevrons/flèches suivant-précédent) : miroir en RTL. Icônes non directionnelles (bougie, lune) : jamais.
  - **Chiffres d'horaires restent LTR** même en hébreu (unicode-bidi plaintext / équivalent natif), en **tabular numbers** (alignement colonne).
  - Police hébraïque agrandie ~+4 % pour équilibrer la couleur typographique.
- Le changement de langue est **in-app** (pas seulement langue système) : sélecteur dans Réglages. Prévoir de respecter la langue système au premier lancement (`system` → mappe vers he/fr/en, sinon en).

---

## 6. Design (direction artistique) — à respecter en natif

Autorité complète : `/root/apps/mvp-moed/design/DA.md`. Points clés :

- **Concept** : « la lumière fixée dans le temps » — aube douce sur parchemin, flamme/or comme accent rare. Trois mots : *Serein · Exact · Lumineux*. **Light mode par défaut, toujours** (dark préparé mais NON activé en v1).
- **Palette (tokens light)** : parchment `#FBF7EF` (fond, jamais blanc pur), parchment-raised `#FFFFFF`, parchment-deep `#F1E9D9`, line `#E7DECB` / line-strong `#D8CBB0` ; encre ink `#1A1B2E` / ink-soft `#55566E` / ink-mute `#8A8AA0` ; accent flamme ner `#C0792B` / ner-strong `#A6631C` / ner-glow `#F0B95C` / ner-wash `#FBEFDA` ; twilight `#35406E` / twilight-wash `#ECEEF6` ; sémantique sage `#5F7050` (Omer/positif), rose `#B0553F` (jeûne/alerte douce), focus `#2C6FB3`. La couleur **ponctue** (≈90 % parchemin+encre, la flamme sur UN élément fort par vue).
- **Typographie** : Display = **Fraunces** (latin) / **Frank Ruhl Libre** (hébreu) pour titres & chiffres de zmanim ; Body/UI = **Instrument Sans** (latin) / **Assistant** (hébreu). Échelle modulaire ~1.25, base 16. **Horaires toujours en tabular-nums.** Self-host les polices (zéro requête externe) — en natif, embarquer les fichiers de police.
- **Grille/espacement** : échelle 4px (4 8 12 16 20 24 32 40 56 72 96), marge page mobile 20px. **Rayons** : sm 8 (chips/inputs), md 14 (cartes), lg 22 (modales/sheets), full 999. **Ombres** douces teintées encre, 3 élévations (e1 repos, e2 hover/popover, e3 modale) + halo flamme `--glow-ner` pour le zman-clé.
- **Motion** : calme, un seul « moment » orchestré par vue (révélation en cascade au chargement) ; respecter *reduce motion*.
- **Adaptation native à fond** (exigence produit) :
  - **iOS** : navigation SwiftUI `TabView` (5 onglets), `NavigationStack` pour les détails, sheets natives pour ajout/formulaires, `WidgetKit` pour widgets home-screen + lock-screen, `UserNotifications` (local) pour rappels, Dynamic Type & VoiceOver, safe areas, gestes natifs, haptique légère sur actions clés.
  - **Android** : Jetpack Compose + Material 3 (thème DA light), Navigation Compose, **Glance** pour widgets home-screen, WorkManager/AlarmManager pour notifications planifiées.
- **Accessibilité** : contrastes AA garantis, focus visible, tailles tactiles ≥ 44pt (iOS) / 48dp (Android).

---

## 7. Backend & persistance — **il n'y a (quasi) pas de backend**

### 7.1 Aucun backend requis pour le fonctionnement
- Tout le calcul est on-device. Les datasets (villes, tsadikim) sont **embarqués**. Il n'y a **pas de compte utilisateur**, pas de login, pas de sync serveur nécessaire au produit.
- Le repo web contient un PocketBase (`pocketbase-moed`) et des routes `api/push/{subscribe,unsubscribe,send}` **uniquement** pour le **Web Push VAPID** de la PWA (planification côté serveur via un cron `*/15` qui POST `/api/push/send`). Collection `push_subscriptions` (endpoint, clés, ville, langue, prefs). **Ce dispositif n'existe que parce que le web ne peut pas planifier des notifications locales.**
- **En natif, on N'A PAS besoin de ce backend** : iOS (`UNUserNotificationCenter`, triggers calendaires) et Android (WorkManager/AlarmManager, cf. `NotificationScheduler.kt`) planifient **localement** tous les rappels, qui sont tous calculables à l'avance de façon déterministe. → **Zéro serveur, zéro coût marginal, offline complet.**

### 7.2 Persistance locale (préférences + carnet familial)
- **Réglages** (web `localStorage`) : `moed_city` (slug de la ville active), `moed_prefs` (`candleMinutes: number|'auto'`, `tzeitMethod: 'degrees'|'minutes'`, `region: 'auto'|'il'|'diaspora'`, `notif: {shabbat, omer, hilula, yahrzeit}`). Défauts : ville `paris`, candleMinutes `auto`, tzeit `degrees`, region `auto`, notifications toutes `false`.
- **Carnet familial** (web `localStorage` clé `moed_family`) : `[{id, type:'yahrzeit'|'birthday', name, date(ISO), afterSunset}]`.
- **Natif** :
  - iOS : `UserDefaults` (ou fichier JSON dans le container) pour prefs + carnet ; ou SwiftData/CoreData si on veut de la structure. Partager les prefs avec les widgets via un **App Group**.
  - Android (référence existante) : **DataStore Preferences** (`SettingsStore.kt`, `PersonalStore.kt`) ; widgets Glance lisent via `WidgetData.kt`.
- Aucune donnée personnelle ne quitte l'appareil (privacy by design, argument produit).

---

## 8. Widgets home-screen (produit de première classe)

Référence Android (`android/.../widget/`) : 3 widgets **Glance** — allumage (candle-lighting), zmanim du jour, Omer du jour ; palette DA (parchemin/encre/ner/twilight) ; refresh via WorkManager (`WidgetUpdater.kt`, `WidgetData.kt`).

À reproduire en natif :
- **Android** : Glance `GlanceAppWidget` (existant) — conserver les 3 widgets.
- **iOS** : **WidgetKit** — au minimum les mêmes 3 : (1) allumage bougies (heure + compte à rebours Chabbat), (2) zmanim clés du jour, (3) Omer du jour. Prévoir tailles small/medium et **widgets écran verrouillé (Lock Screen)** iOS 16+. `TimelineProvider` recalcule localement (offline), pas d'appel réseau. Données partagées via App Group.

---

## 9. Notifications natives (locales, planifiées)

Référence Android (`android/.../notif/`) : `NotificationScheduler.kt` (4 canaux : `moed_shabbat`, `moed_yahrzeit`, `moed_omer`, `moed_holiday`), `NotificationReceiver.kt`, `BootReceiver.kt` (replanifie au reboot), via AlarmManager/WorkManager.

À porter :
- **Types** : allumage Chabbat (vendredi), yahrzeit + kaddish, Omer quotidien (période Sefira), hiloula du jour, fêtes/jeûnes à venir. Tous **opt-in** (réglages).
- **Android** : conserver les 4 canaux + replanification au boot.
- **iOS** : `UNUserNotificationCenter`, contenu localisé, triggers `UNCalendarNotificationTrigger` pour chaque occurrence future (planifier une fenêtre glissante, ex. prochaines N occurrences, et replanifier à l'ouverture / via `BGTaskScheduler`). Demander l'autorisation au moment de l'opt-in, pas au lancement.
- Toutes les échéances sont **déterministes** → aucune dépendance à un push serveur.

---

## 10. Architecture native recommandée (récap de portage)

| Domaine | Web (réf.) | Android natif (réf.) | iOS natif (à créer) |
|---|---|---|---|
| Zmanim / calendrier hébraïque | kosher-zmanim + @hebcal/* | KosherJava 2.5.0 | **KosherCocoa** (+ Foundation Hebrew calendar en appoint) |
| Daf Yomi | @hebcal/learning | KosherJava YomiCalculator | KosherCocoa (ou table) |
| Parasha/haftara | @hebcal/leyning | KosherJava parshah | KosherCocoa (+ dataset haftara sépharade si besoin) |
| UI | Next.js/React/Tailwind | Compose + Material 3 | **SwiftUI** |
| Nav | 5 onglets + routes | Navigation Compose | TabView + NavigationStack |
| Persistance | localStorage | DataStore | UserDefaults / SwiftData (+ App Group) |
| Widgets | — (web) | Glance ×3 | **WidgetKit** ×3 (+ Lock Screen) |
| Notifications | Web Push VAPID (serveur) | AlarmManager/WorkManager, 4 canaux | UNUserNotificationCenter (local) |
| i18n | messages/*.json | Localization.kt | Localizable.strings (he/fr/en) |
| Données statiques | data/cities.ts, tsadikim.ts | AssetData.kt | cities.json + tsadikim.json |
| Backend | Aucun (push serveur en option) | **Aucun** | **Aucun** |

**Règles d'or à ne pas violer** :
1. **Aucun appel réseau au runtime** pour le calcul (offline complet).
2. **Parité de calcul** entre iOS / Android / Web — même shitot, mêmes noms, mêmes règles yahrzeit — **validée** contre référence (§3.6). Les gens jeûnent et allument selon ces heures : **zéro approximation**, disclaimer + shita affichés.
3. **Light mode par défaut**, RTL première classe, 3 langues à parité, hébreu primaire.
4. **Gratuit, sans compte, sans pub, sans collecte** : rien ne quitte l'appareil.

---

## 11. Annexe — chemins de référence

- Moteur web : `/root/apps/mvp-moed/src/lib/engine/` (`hebrewDate.ts`, `zmanim.ts`, `candles.ts`, `calendar.ts`, `personal.ts`, `gematria.ts`, `index.ts`, `types.ts`, `README.md`, `validate.mjs`, `validation-report.json`).
- Données : `/root/apps/mvp-moed/src/data/{cities.ts,tsadikim.ts}`.
- i18n : `/root/apps/mvp-moed/src/{i18n/config.ts,messages/{fr,en,he}.json}`.
- Écrans web : `/root/apps/mvp-moed/src/app/[locale]/{page,calendar,personal,tsadikim,tsadikim/[slug],zmanim/[city],converter,settings,offline}/`.
- Design : `/root/apps/mvp-moed/design/DA.md`.
- Android natif (modèle de portage) : `/root/apps/mvp-moed/android/app/src/main/java/com/moed/app/` (`engine/{JewishInfo,ZmanimEngine}.kt`, `ui/screens/*`, `widget/*`, `notif/*`, `data/*`).
- Contexte produit : `/root/apps/mvp-moed/CLAUDE.md`, `/root/apps/mvp-moed/PROMPT.md`.
