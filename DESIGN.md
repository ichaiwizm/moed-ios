# Moed iOS — Direction Artistique native (Apple Liquid Glass)

> מועד — « le temps fixé ». Compagnon de calendrier juif (louah), trilingue hébreu (RTL) / français / anglais à parité.
> Cette DA décrit l'implémentation **native SwiftUI**, adoptant le langage **Liquid Glass** d'Apple (iOS 26) : matériaux translucides qui réfractent le fond, superposés à un **fond doux « parchemin d'aube »**. Elle prolonge la DA web (`/root/apps/mvp-moed/design/DA.md`) — mêmes valeurs, même âme — mais l'exprime avec les matériaux, la profondeur et le mouvement natifs Apple.

**Trois mots :** *Serein · Exact · Lumineux.*
**Concept :** « la lumière fixée dans le temps » — une aube douce sur parchemin, le verre comme air, la flamme (or) comme accent rare et sacré.
**Règle cardinale :** ~90 % parchemin + encre + verre ; la flamme ne ponctue **qu'un seul élément fort par écran** (le zman clé, l'allumage). La couleur n'est jamais décorative — elle signale.

---

## 1. Philosophie Liquid Glass appliquée à Moed

Le Liquid Glass n'est pas un effet, c'est une **hiérarchie de profondeur**. Trois plans, jamais mélangés :

| Plan | Rôle | Matériau |
|---|---|---|
| **Canvas** (fond) | Le parchemin d'aube, dégradé calme, immobile | Couleur + gradient doux, jamais de verre |
| **Content** (contenu qui défile) | Cartes, listes, texte | Surfaces opaques mates (parchment-raised) ou verre *regular* léger |
| **Navigation** (chrome flottant) | TabBar, barres, boutons flottants, sheets | **Liquid Glass** (`.regular` / `.clear`) qui réfracte le contenu qui passe dessous |

**Règle d'or :** le verre appartient au **chrome et aux contrôles flottants**, pas au contenu de lecture. Un horaire de zman, une bio de tsadik, une date — ça se lit sur une surface **calme et opaque**. Le verre, lui, flotte : TabBar, boutons d'action, header au scroll, sheets. Cela garantit la lisibilité (halakhique : on jeûne et on allume selon ces heures — zéro compromis de lecture) tout en donnant l'air « vivant » d'iOS 26.

**Ne jamais empiler deux couches de verre** (verre sur verre = bouillie). Une couche de glass sur un contenu opaque, point.

---

## 2. Tokens de couleur

Le système Moed est un **overlay sémantique** posé sur les matériaux Apple. On définit un `Color` asset catalog par token, avec variantes Any/Dark. Les matériaux verre restent les `Material` système (`.regularMaterial`, `.thinMaterial`, `Glass`), **teintés** par nos couleurs quand nécessaire (`.tint()` / `glassEffect(.regular.tint(...))`).

### 2.1 Light (défaut, toujours)

**Fond / surfaces**
| Token | Hex | Usage |
|---|---|---|
| `canvas` | `#FBF7EF` | Fond racine (parchemin, jamais blanc pur) |
| `canvasGradientTop` | `#FDFBF6` | Haut du dégradé d'aube |
| `canvasGradientBottom` | `#F4ECDC` | Bas du dégradé (chaleur au sol) |
| `surface` | `#FFFFFF` | Carte de contenu (parchment-raised) |
| `surfaceDeep` | `#F1E9D9` | Zone enfoncée, champ, ligne de liste alternée |
| `line` | `#E7DECB` | Séparateurs fins |
| `lineStrong` | `#D8CBB0` | Bordure de carte, contour de contrôle |

**Encre (texte)**
| Token | Hex | Usage |
|---|---|---|
| `ink` | `#1A1B2E` | Titres, chiffres de zmanim |
| `inkSoft` | `#55566E` | Corps, sous-titres |
| `inkMute` | `#8A8AA0` | Labels secondaires, captions |

**Accent flamme (ner) — l'or sacré, rare**
| Token | Hex | Usage |
|---|---|---|
| `ner` | `#C0792B` | Accent principal (allumage, zman clé) |
| `nerStrong` | `#A6631C` | État pressé, texte sur ner-wash |
| `nerGlow` | `#F0B95C` | Halo, dégradé de flamme, glow du verre |
| `nerWash` | `#FBEFDA` | Fond de badge / capsule flamme |

**Crépuscule (twilight) & sémantique**
| Token | Hex | Usage |
|---|---|---|
| `twilight` | `#35406E` | Roch Hodech, nuit, secondaire froid |
| `twilightWash` | `#ECEEF6` | Fond de badge twilight |
| `sage` | `#5F7050` | Omer, positif |
| `rose` | `#B0553F` | Jeûne, alerte douce |
| `focus` | `#2C6FB3` | Anneau de focus / accessibilité |

### 2.2 Dark (préparé, activable — voir §9)

Le dark Moed n'est pas un simple négatif : c'est une **nuit de veille**, bleu-encre profond, la flamme y gagne en présence.

| Token | Hex |
|---|---|
| `canvas` | `#14151F` |
| `canvasGradientTop` | `#1B1C28` |
| `canvasGradientBottom` | `#0F1017` |
| `surface` | `#20212E` |
| `surfaceDeep` | `#191A24` |
| `line` | `#2C2D3B` |
| `lineStrong` | `#3A3B4D` |
| `ink` | `#F3EFE4` |
| `inkSoft` | `#B8B7C6` |
| `inkMute` | `#7C7C90` |
| `ner` | `#E4A34D` |
| `nerStrong` | `#F0B95C` |
| `nerGlow` | `#F6C871` |
| `nerWash` | `#33281A` |
| `twilight` | `#8A94C4` |
| `twilightWash` | `#242742` |
| `sage` | `#8DA07C` |
| `rose` | `#D48068` |
| `focus` | `#5B9BD8` |

Sur les surfaces verre en dark, utiliser `.regularMaterial` (Apple gère l'inversion) ; le glow flamme passe en `nerGlow` à opacité réduite (0.5).

### 2.3 Le fond doux (canvas) — spécification

Le fond n'est **jamais** plat. C'est un `LinearGradient` vertical très subtil (`canvasGradientTop` → `canvasGradientBottom`), sur lequel repose un **halo d'aube** radial extrêmement diffus en haut, teinté `nerGlow` à **3 % d'opacité** (light) / `twilight` à 8 % (dark), positionné derrière le header. Aucun mouvement. C'est la « lumière fixée ». Le verre du chrome réfracte ce dégradé quand on scrolle.

```
ZStack {
  LinearGradient(canvasGradientTop → canvasGradientBottom)
  RadialGradient(nerGlow.opacity(0.03), center: .top, radius: 420)  // halo d'aube
  content
}
.ignoresSafeArea()
```

---

## 3. Typographie

Deux familles Display (latin + hébreu) pour les titres et **tous les chiffres d'horaires** ; deux familles Body (latin + hébreu) pour l'UI. **Self-hosted / embarquées** (zéro requête réseau). Le sélecteur de police se fait par langue active.

| Rôle | Latin | Hébreu | Remarque |
|---|---|---|---|
| **Display** (titres, chiffres zmanim) | Fraunces | Frank Ruhl Libre | Sérif chaud ; les chiffres en **tabular** |
| **Body / UI** | Instrument Sans | Assistant | Sans-serif net, lisible en petit |

**Fallback système :** si une police manque, retomber sur `.serif` (Display) / `.system` (Body) via `Font.custom(...).fallback`, jamais d'écran nu.

### 3.1 Échelle typo (modulaire ~1.25, base 16, Dynamic Type)

Chaque style est mappé à un `Font.TextStyle` Apple pour respecter **Dynamic Type** (l'app scale avec les réglages d'accessibilité). Tailles au cran `.large` par défaut :

| Style Moed | pt | Poids | Famille | Apple TextStyle | Usage |
|---|---|---|---|---|---|
| `hero` | 40 | Semibold | Display | `.largeTitle` | Chiffre d'allumage, grand horaire |
| `title1` | 30 | Semibold | Display | `.title` | Date hébraïque en tête |
| `title2` | 24 | Medium | Display | `.title2` | Titres de carte / section |
| `title3` | 20 | Medium | Display | `.title3` | Nom de tsadik, sous-titre fort |
| `body` | 16 | Regular | Body | `.body` | Corps courant |
| `bodyEmph` | 16 | Semibold | Body | `.body` | Label de zman, nom en liste |
| `callout` | 15 | Regular | Body | `.callout` | Descriptions secondaires |
| `caption` | 13 | Medium | Body | `.caption` | Badges, méta, sources |
| `micro` | 11 | Semibold | Body | `.caption2` | Uppercase tracking, labels d'onglet |
| `zmanTime` | 22 | Medium | Display | — | **Horaire** : `.monospacedDigit()` obligatoire |

**Réglages typographiques fixes :**
- **Chiffres d'horaires** : toujours `.monospacedDigit()` (tabular-nums) → alignement en colonne dans les listes de zmanim et le compte à rebours qui change chaque seconde sans « sauter ».
- **Line-height** : titres ×1.15, corps ×1.45 (via `.lineSpacing`).
- **Tracking** : `micro`/labels d'onglet en +8 % (uppercase). Corps neutre. Hébreu : tracking 0 (jamais d'espacement de lettres en hébreu).
- **Hébreu +4 %** : quand `locale == he`, appliquer un multiplicateur d'échelle de **1.04** sur la taille de police pour équilibrer la couleur typographique (l'hébreu « pèse » moins que le latin à taille égale). Implémenter via un `ViewModifier` `.hebrewBalanced()`.

---

## 4. Matériaux, formes, profondeur

### 4.1 Rayons (continuous / squircle Apple)

Toujours `RoundedRectangle(cornerRadius:, style: .continuous)`.

| Token | pt | Usage |
|---|---|---|
| `radiusSm` | 10 | Chips, champs, petits badges |
| `radiusMd` | 16 | Cartes de contenu |
| `radiusLg` | 26 | Sheets, modales, carte Chabbat feature |
| `radiusCapsule` | ∞ (`Capsule`) | Boutons pilule, segmented, TabBar flottante |

### 4.2 Matériaux

| Nom Moed | Base Apple | Où |
|---|---|---|
| `glassChrome` | `.regularMaterial` + `glassEffect(.regular)` | TabBar, header au scroll, toolbar |
| `glassFloat` | `Glass.clear` teinté | Bouton d'action flottant (FAB « Ajouter »), capsule de compte à rebours |
| `glassSheet` | `.regularMaterial` | Fond de sheet / formulaire |
| `cardSolid` | `surface` opaque + bordure `lineStrong` | **Contenu lisible** (zmanim, bios, listes) |
| `cardInset` | `surfaceDeep` | Champ de saisie, ligne enfoncée |

Le verre flottant clé (bouton d'ajout, capsule d'allumage) reçoit un **halo flamme** : `glassEffect(.regular.tint(ner.opacity(0.14)))` + ombre `shadowNerGlow`.

### 4.3 Élévations (ombres teintées encre, jamais noires)

| Token | Spec | Usage |
|---|---|---|
| `e1` | y 2, blur 10, `ink` @0.06 | Carte au repos |
| `e2` | y 6, blur 22, `ink` @0.10 | Carte active, popover, verre flottant |
| `e3` | y 16, blur 44, `ink` @0.16 | Sheet / modale |
| `glowNer` | y 0, blur 30, `nerGlow` @0.30 | **Zman clé / allumage uniquement** |

Le verre a sa propre ombre système ; on n'ajoute `e2` que si un verre flotte sur du contenu clair sans contraste suffisant.

### 4.4 Grille & espacement

Échelle 4 px : `2 4 8 12 16 20 24 32 40 56 72 96`. Marge de page mobile = **20**. Espacement inter-cartes = **16**. Padding interne de carte = **20** (16 en compact). Respecter les **safe areas** ; la TabBar verre flotte au-dessus du contenu (le contenu scrolle dessous et se réfracte).

---

## 5. Composants clés (specs)

### 5.1 En-tête « Aujourd'hui » (date du jour)

Le premier regard. **Pas de carte** — le texte respire directement sur le canvas, sous un header verre qui apparaît au scroll.

- **Ligne ville** : icône `location.fill` (`ner`, 15pt) + nom de ville (`bodyEmph`, `inkSoft`). Tap → sélecteur de ville (sheet).
- **Date hébraïque** : `title1`, `ink`, Display. Formatée dans la langue active (tables maison he/fr/en — hebcal ne connaît que en/he). En hébreu : chiffres et lettres hébraïques, RTL.
- **Date grégorienne** : `callout`, `inkMute`, sous la date hébraïque.
- **Rangée de badges** (voir §5.6) : jour du Omer (`sage`), fête / Yom Tov (`ner`), Roch Hodech (`twilight`). Wrap flexible, max 3 visibles.
- **Header au scroll** : à > 12 pt de scroll, un bandeau `glassChrome` glisse depuis le haut avec la date hébraïque en `title3` condensée. Transition `.smooth`.

### 5.2 Carte Chabbat (feature) — le seul « héros » de l'écran

La carte la plus riche, l'unique porteuse de flamme pleine.

- Conteneur `radiusLg`, fond `surface`, bordure `lineStrong`, ombre `e2` **+ `glowNer`**.
- Filet de dégradé flamme en haut (`nerGlow → ner`, 3 pt) comme « braise ».
- **Titre** : « Prochain Chabbat » (`caption` uppercase, `inkMute`) + nom parasha (`title3`, `ink`).
- **Illustration bougies** (asset symbolique) en trailing, discrète, avec un halo `nerGlow` @0.2 en `blur`.
- **Heure d'allumage** : `hero` (40pt), `ner`, `.monospacedDigit()`. Label « allumage » en `micro`.
- **Compte à rebours live** dans une **capsule verre flottante** (`glassFloat` teinté ner) : « allumage dans 2 h 14 min », `bodyEmph` tabular, mise à jour **chaque seconde**. La capsule pulse imperceptiblement (scale 1.0↔1.006, 2 s, ease-in-out) — *désactivé si Reduce Motion*.
- **Havdala** : ligne discrète en bas, `callout`, `twilight`, icône `sparkles`.

### 5.3 Liste de zmanim (contenu lisible, calme)

**Aucun verre ici** — lisibilité halakhique absolue. Carte `cardSolid`, lignes séparées par `line`.

Chaque ligne de zman :
```
[icône 20pt · ner/inkSoft]   Label (bodyEmph, ink)          HH:MM (zmanTime, ink, monospacedDigit, trailing)
                              Shita (caption, inkMute)        [null → « — » inkMute]
```
- **Alignement des heures** : colonne trailing rigide grâce aux tabular numbers (les heures s'empilent parfaitement).
- **Zman clé du jour** (ex. prochain zman à venir) : fond de ligne `nerWash`, heure en `ner`, léger `glowNer`. **Un seul** par liste.
- **Shita affichée** systématiquement (label de la méthode) — exigence produit (transparence halakhique).
- **Valeur `null`** (latitude extrême, soleil n'atteint pas l'angle) : afficher « — » en `inkMute` + tap révèle un tooltip explicatif. Jamais « NaN », jamais de ligne vide.
- **Chiffres restent LTR** même en hébreu (voir §8).
- Lien de pied de carte : « Tous les zmanim » (`bodyEmph`, `ner`, chevron trailing miroité en RTL) → page ville détaillée.
- **Disclaimer halakhique** obligatoire sous la liste complète (`caption`, `inkMute`) + shita active.

### 5.4 Listes (Personnel, Tsadikim, Calendrier)

Style commun : `List` SwiftUI avec `.listStyle(.plain)`, fond canvas transparent, lignes en `cardSolid` avec insets de 16, séparateurs `line`.

**Ligne Personnel (carnet familial)** :
- Leading : pastille de type — cercle `nerWash` (anniversaire, icône `gift`) ou `twilightWash` (yahrzeit, icône `flame`).
- Titre : nom (`bodyEmph`, `ink`). Sous-titre : prochaine occurrence — date grégorienne + date hébraïque (`caption`, `inkSoft`).
- Trailing : badge « dans X jours » (`caption`, capsule `surfaceDeep`).
- **Swipe leading→trailing** : action supprimer (`rose`), avec confirmation haptique.
- **Empty state** illustré (asset `family`) + CTA « Ajouter un proche ».
- **FAB « Ajouter »** : bouton verre flottant `glassFloat` teinté ner, ancré bottom-trailing (bottom-leading en RTL), icône `plus`, ouvre une **sheet** de formulaire.

**Ligne Calendrier (jour du mois)** :
- Date hébraïque + grégorienne, badges d'événements colorés par catégorie : fête = `ner`, jeûne = `rose`, roch hodech = `twilight`, omer = `sage`, autre = `line`.
- En-tête = mois + année (langue active), chevrons précédent/suivant (**miroités en RTL**), transition de mois en glissement horizontal (respecte la direction de lecture).

**Ligne / grille Tsadikim** :
- Section « Hiloula du jour » en tête : cartes `cardSolid` avec visuel **symbolique par catégorie** (motif tanna/rishon/hassid/habad/sefarade — **jamais de portrait photoréaliste**, exigence éditoriale).
- Répertoire : grille 2 colonnes, vignette motif + nom trilingue + épithète.
- Fiche détail (`NavigationStack` push) : nom (langue), épithète, catégorie, date de hiloula (+ note ex. « Lag BaOmer »), prochaine hiloula, kever (lieu/pays), œuvres, bio longue, **badge de confiance** (high/medium/traditional — couleurs `sage`/`ner`/`inkMute`), **sources** cliquables, note sur le visuel symbolique.

### 5.5 Formulaire (sheet d'ajout Personnel)

- **Sheet** native, `.presentationDetents([.medium, .large])`, fond `glassSheet`, coins `radiusLg`, poignée de préhension visible.
- **Segmented** type : Anniversaire / Yahrzeit (`Picker(.segmented)` teinté ner).
- Champ nom (`cardInset`, `radiusSm`).
- **Date picker** natif (`.graphical` ou `.wheel`).
- **Toggle** « après le coucher du soleil » (`afterSunset`) + explication `caption` (ancre la date hébraïque correctement).
- Bouton de validation : capsule pleine `ner` → `nerStrong` au press, texte `surface`.

### 5.6 Badges & chips

Capsule (`radiusCapsule`), padding H12/V6, `caption` :
| Type | Fond | Texte | Icône |
|---|---|---|---|
| Omer | `sageWash` (sage@0.14) | `sage` | `leaf` |
| Fête / Yom Tov | `nerWash` | `nerStrong` | `flame` |
| Roch Hodech | `twilightWash` | `twilight` | `moon` |
| Jeûne | rose@0.12 | `rose` | `moon.stars` |
| Neutre | `surfaceDeep` | `inkSoft` | — |

### 5.7 TabBar (5 onglets, Liquid Glass)

- `TabView` natif iOS 26 → TabBar **Liquid Glass flottante** automatique (`glassChrome`), qui se réfracte sur le contenu qui scrolle dessous.
- Onglets dans l'ordre : **Aujourd'hui** (`sun.max` / soleil d'aube), **Calendrier** (`calendar`), **Personnel** (`person.2`), **Tsadikim** (`flame` / motif bougie), **Réglages** (`gearshape`).
- Onglet actif teinté `ner` ; inactif `inkMute`. Label `micro`.
- **En RTL (hébreu)** : l'ordre des onglets **se miroite** (Aujourd'hui à droite). SwiftUI le gère si on utilise l'ordre logique.

---

## 6. Motion

Calme, un seul « moment » orchestré par écran. Le mouvement suggère la lumière qui se pose, jamais l'agitation.

**Courbes & durées**
| Intention | Animation SwiftUI | Durée |
|---|---|---|
| Apparition de contenu | `.smooth(duration: 0.5)` | 500 ms |
| Réponse tactile (press) | `.snappy(duration: 0.22)` | 220 ms |
| Transition de navigation | Push/sheet natifs | système |
| Compte à rebours (tick) | `.default` sur le texte | — (tabular = pas de saut) |
| Pulse capsule allumage | `.easeInOut.repeatForever(autoreverses:)`, scale 1↔1.006 | 2 s |

**Le « moment » d'écran (révélation en cascade)** : au montage de « Aujourd'hui », les blocs (en-tête → carte Chabbat → zmanim → parasha) apparaissent en **stagger** de 60 ms, opacity 0→1 + translation Y 8→0, courbe `.smooth`. **Une seule fois** par présentation (pas à chaque re-render). Le calcul étant synchrone en natif (offline), pas de skeleton — la cascade masque l'unique frame de layout.

**Transitions verre** : au scroll, le header verre entre via `.transition(.opacity.combined(with: .move(edge: .top)))` avec `.smooth`.

**Reduce Motion (obligatoire)** : si `accessibilityReduceMotion` → supprimer la cascade (apparition en fondu simple ≤ 150 ms), figer la pulse, remplacer les glissements par des cross-fades. Ne jamais bloquer une info derrière une animation.

---

## 7. Haptique

Discrète, sémantique, jamais gratuite. Via `UIFeedbackGenerator` / `.sensoryFeedback`.

| Événement | Feedback |
|---|---|
| Sélection d'onglet, segmented, ville | `.selection` |
| Ajout d'un proche (succès) | `.success` |
| Suppression (swipe confirmé) | `.impact(.rigid)` léger |
| Erreur de saisie (date invalide converter) | `.error` |
| **Entrée du Chabbat** (compte à rebours atteint 00:00) | `.success` doux + éventuelle notif locale |
| Changement de mois (calendrier) | `.impact(.soft)` |
| Toggle notification activé | `.impact(.light)` |

Jamais d'haptique sur le scroll, le tick de seconde, ou l'apparition de contenu.

---

## 8. RTL & hébreu (première classe)

L'hébreu est la **langue primaire du produit**. Le RTL n'est pas un mode dégradé, c'est un citoyen de première classe.

- **Direction** : `locale == he` → `.environment(\.layoutDirection, .rightToLeft)` à la racine. fr/en → LTR. Défaut de code : fr ; au premier lancement, respecter la langue système (`system` → he/fr/en, sinon en).
- **Propriétés logiques uniquement** : `.leading`/`.trailing`, `.padding(.horizontal)`, jamais `.left`/`.right` en dur. SwiftUI miroite automatiquement.
- **Icônes directionnelles** (chevrons précédent/suivant, flèche « voir plus », back) : **miroitées** en RTL (`.flipsForRightToLeftLayoutDirection(true)` ou `.scaleEffect(x: -1)` conditionnel).
- **Icônes non directionnelles** (bougie `flame`, lune `moon`, localisation, feuille) : **jamais** miroitées.
- **Chiffres d'horaires restent LTR** même en hébreu : envelopper les heures et le compte à rebours dans un conteneur forcé `.environment(\.layoutDirection, .leftToRight)` (équivalent unicode-bidi plaintext), en **tabular numbers**, pour que `18:42` s'affiche `18:42` et non inversé, tout en s'alignant à droite dans la ligne RTL.
- **Hébreu +4 %** : multiplicateur de police 1.04 (voir §3.1).
- **Ponctuation & mixte** : les libellés mixtes (hébreu + heure) utilisent l'alignement naturel ; tester « Chabbat entre à 18:42 » en he/fr/en.
- **Sélecteur de langue in-app** dans Réglages (he / fr / en) — change locale + direction **sans redémarrage**, avec transition douce `.smooth`.

---

## 9. Light / Dark

- **Light mode par défaut, toujours.** C'est l'identité de Moed (parchemin d'aube). L'app démarre en light quel que soit le thème système en v1.
- **Dark préparé mais NON activé en v1** : la palette dark (§2.2) existe dans l'asset catalog (variantes Dark), prête à être branchée sur `preferredColorScheme` ou un réglage in-app en v2. Ne pas suivre le thème système tant que le dark n'est pas validé visuellement (contrastes AA, glow flamme, verre).
- Quand dark s'activera : les `Material` Apple s'inversent seuls ; vérifier que le halo d'aube passe en `twilight` @0.08, le glow ner en `nerGlow` @0.5, et que les surfaces de contenu restent **plus claires** que le canvas (élévation par la lumière, pas par l'ombre).

---

## 10. Accessibilité (non négociable)

- **Contrastes AA** garantis sur toutes les paires texte/fond (ink/canvas, inkSoft/surface, ner sur nerWash vérifié ≥ 4.5:1 pour le texte).
- **Dynamic Type** : tous les styles mappés sur `Font.TextStyle` → l'app scale. Tester jusqu'à `.accessibility3` ; les cartes passent en layout vertical si nécessaire.
- **VoiceOver** : chaque zman lu comme « [label], [shita], [heure] » ; les badges ont un `accessibilityLabel` explicite ; le compte à rebours annonce via `accessibilityValue` mis à jour (pas chaque seconde — throttle à la minute). Ordre de lecture respectant la langue.
- **Tailles tactiles ≥ 44 pt** (lignes de liste, chips tapables, chevrons).
- **Focus visible** : anneau `focus` (`#2C6FB3`) 2 pt sur les éléments interactifs au clavier / switch control.
- **Reduce Transparency** : si activé, remplacer le verre `glassChrome` par `surface` opaque + bordure `lineStrong` (garantir la lisibilité de la TabBar et du header).
- **Reduce Motion** : voir §6.

---

## 11. Widgets (WidgetKit) — cohérence DA

Trois widgets, même langage : fond **parchment gradient** (pas de verre — les widgets ne réfractent rien d'utile), une seule flamme par widget.

1. **Allumage** (small / medium + Lock Screen) : heure d'allumage (`hero`/`title1`, `ner`, tabular) + compte à rebours + nom parasha. Illustration bougie discrète.
2. **Zmanim du jour** (medium) : 3–4 zmanim clés en colonne tabular, zman à venir surligné `nerWash`.
3. **Omer** (small + Lock Screen) : « Jour N » (`sage`), grand chiffre Display.

`TimelineProvider` recalcule **localement** (offline, App Group partagé avec l'app) ; refresh au passage de minuit et aux transitions de zmanim. Lock Screen : glyphes monochromes teintables, respect du rendu `.accented`.

---

## 12. Ce qu'on ne fait jamais

- ❌ Verre sur verre, ou verre sous un contenu de lecture dense (zmanim, bios).
- ❌ Blanc pur en fond (`#FFFFFF` = surface de carte uniquement, jamais le canvas).
- ❌ Flamme (ner) sur plus d'un élément fort par écran.
- ❌ Chiffres d'horaires non-tabular, ou inversés en RTL.
- ❌ Portrait photoréaliste de tsadik (motif symbolique par catégorie uniquement).
- ❌ Dark mode par défaut en v1.
- ❌ Animation qui retarde l'accès à une heure halakhique.
- ❌ Ombre noire pure (toujours teintée `ink`).
- ❌ Icône non directionnelle miroitée en RTL.

---

*Autorité amont : `/root/apps/mvp-moed/design/DA.md` (DA multi-plateforme) et `NATIVE_SPEC.md` (périmètre produit). Cette DA iOS en est la déclinaison Liquid Glass native — toute divergence de calcul (zmanim, dates) reste interdite ; la DA n'habille jamais l'exactitude.*
