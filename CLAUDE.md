# Salat — apprendre la prière

App iOS (SwiftUI, iOS 17+) qui enseigne **ce qu'il faut dire pendant la salat** : le texte arabe,
sa prononciation écrite dans la langue du lecteur, et sa traduction. Deux modes d'apprentissage :
actif (onglet *Learn*, 14 étapes détaillées) et passif (onglet *Practice* + **widget** qui fait
défiler les positions tout seul).

## Le projet est généré — ne pas éditer `Salat.xcodeproj`

`project.yml` (XcodeGen) est la source de vérité. Après avoir ajouté un fichier :

```bash
xcodegen generate
xcodebuild -project Salat.xcodeproj -scheme Salat -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build
```

Quatre cibles : `Salat` (app), `SalatWidgetExtension` (widget), `SalatTests`, `SalatUITests`.
**`SalatKit/` est compilé dans les trois** — c'est là que vit tout ce que l'app et le widget
partagent (thème, i18n, contenu, illustrations). Un fichier posé ailleurs n'existe pas pour le
widget.

## Le contenu est de la donnée, pas du code

`SalatKit/Resources/` :

| Fichier | Rôle |
|---|---|
| `steps.base.json` | ce qui ne dépend pas de la langue : ordre, arabe, posture, répétitions |
| `steps.<code>.json` | par langue : nom, description du geste, **phonétique**, traduction, note |
| `ui.<code>.json` | les chaînes d'interface |
| `pos_*.png` | les illustrations, détourées sur transparence |

**Ajouter une langue = déposer `steps.xx.json` + `ui.xx.json` et ajouter le cas dans
`AppLanguage`.** Rien d'autre dans l'app ne connaît les langues. L'anglais sert de filet :
une clé manquante y retombe au lieu d'afficher du vide.

La **phonétique est propre à chaque langue** — un francophone ne lit pas `Subhaana` comme un
anglophone lit `Soubhâna`. Ne jamais recopier la phonétique EN dans un autre fichier.

Les blocs multi-lignes (Fatiha, Tashahhud…) sont **appariés ligne à ligne** entre l'arabe, la
phonétique et la traduction : l'écran de détail affiche une carte par ligne, et c'est cet
alignement qui enseigne. Un test le vérifie (`testLinesPairUpBetween…`) — s'il casse, c'est
qu'une traduction a fusionné ou coupé un verset.

## Contenu religieux : périmètre assumé

Le déroulé retenu est le **tronc commun sunnite** (ce sur quoi les quatre écoles s'accordent).
Là où elles divergent (formulation du Tashahhud, position des mains, Qunut), la divergence est
**signalée dans le champ `note`, jamais tranchée**. Ne pas « corriger » une étape vers une école
particulière sans que Sharik l'ait demandé.

## Illustrations

Générées par NanoBanana (`/generateImage`), puis détourées et recadrées par
`tools/cutout.py` (fond → alpha, crop sur la figure, sortie 512×512).

Contrainte non négociable, rappelée dans le prompt : **aucun trait de visage** (pas d'yeux, pas
de bouche, pas de nez), silhouette pleine d'un jeune homme en thobe. Toute régénération doit
repartir du prompt de `tools/generate-positions.py`.

Si un `pos_*.png` manque, `PositionMedallion` retombe sur `PostureFigure` — les silhouettes
dessinées en `Path`. C'est un vrai plancher, pas un placeholder : l'app reste utilisable et
conforme sans aucune image.

## Le widget n'est pas un carrousel animé

WidgetKit ne rend que des instantanés statiques et **c'est iOS qui décide quand les échanger**.
Le « défilement » est donc une timeline d'une entrée par minute, rebâtie quand elle s'épuise
(`CarouselProvider`). Une rotation à la seconde est impossible — le système l'ignorerait. La
rotation est calée sur l'horloge (`timeIntervalSince1970 / 60`) pour que deux widgets restent
en phase.

État partagé app ⇄ widget via l'App Group `group.com.salat` (`SharedStore`). Toute écriture de
réglage doit passer par `AppSettings`, qui déclenche `WidgetCenter.reloadAllTimelines()`.

## Direction artistique

Crème `#FBF6EC`, sable `#EFE3CC`, or `#C1962C`, encre brune `#2E2A22`. Titres en **serif**
(ça doit lire comme un livre, pas comme une app), texte courant en système. Pas de noir pur,
pas de couleur saturée, pas de photo. Le motif de fond est un `Canvas` (étoiles à huit branches)
— jamais une image, pour rester net à toutes les tailles et ne rien peser dans le widget.

## Les formes viennent de 5min (`~/Documents/IOS/5min`)

Le langage de formes est celui de `5min/Design/Plate.swift` : rectangle arrondi, **contour d'encre
épais**, et une **face inférieure pleine extrudée vers le bas** — jamais d'ombre portée floue.
C'est cette face qui fait qu'un bloc se lit comme un objet posé et non comme une zone coloriée.
Les boutons s'enfoncent dessus (`chunky`), et **c'est le déplacement de la face qui fait sentir
l'appui**, pas un changement de couleur — que le pouce cache de toute façon.

**Seules les formes sont reprises.** 5min est sur feutre sombre avec des accents saturés ; ici les
mêmes formes sont taillées dans la crème, le sable et l'or, et le contour est l'encre brune — un
quasi-noir sur de la crème percerait des trous au lieu de dessiner des arêtes. Contour 2 pt et non
3 pt, pour la même raison.

Le retour du geste vient aussi de 5min (`Feedback.swift`) : vibration **à la descente** (c'est le
seul instant où elle coïncide avec ce que fait le doigt), clic sonore en même temps, gerbe d'or au
relâchement. Les rôles ne se piochent pas pour décorer — `select` pour un cran de choix, `press`
pour un geste plein, `win` pour la seule fanfare (marquer une étape acquise).

Les éclats sont des **étoiles à huit branches** (khatam) — le motif du fond, pas un scintillement
générique. Ce n'est pas une étoile de David : l'hexagramme est le symbole du judaïsme et n'a rien à
faire dans une app de salat.

La police pixel `04b30.ttf` vient aussi de 5min, et sert **uniquement aux nombres** : le badge
d'étape, le compteur du widget, les secondes. Elle n'a ni arabe ni `É` — « ÉTAPE » y retombait
glyphe par glyphe en un mélange visible de deux fontes, d'où le badge numéral. Jamais pour le texte
de prière : un texte sacré en fonte d'arcade serait grotesque.

Les illustrations sont légèrement pixellisées (`tools/pixelate.py`, grille 72) pour parler la même
langue, sans aller jusqu'à rendre les postures illisibles en 62 pt.

Le `FloatingTabBar` reprend la structure de la convention maison mais **recolorée pour un fond
clair** : encre sur crème, plaque dorée en relief derrière l'onglet actif, pas de glow néon
(invisible sur du papier). Les onglets inactifs n'ont **aucun contour** — trois boîtes cerclées
dans une boîte cerclée, et plus rien ne ressort.

## Tests : ce qu'ils gardent

`SalatTests` est **hébergé par l'app** (`TEST_HOST`), pas une seconde compilation de `SalatKit` —
sinon `@testable import Salat` ne linke pas. `SalatUITests` traverse l'onboarding en tapant :
c'est la régression qui compte, l'app a déjà été livrée une fois avec un onboarding dont on ne
pouvait pas sortir.

Cette panne mérite d'être retenue : `@Observable` **ne suit que les propriétés stockées**. Un
`var x: Bool { get { UserDefaults… } }` change la valeur sans jamais prévenir SwiftUI, donc la
vue ne se redessine pas. Toute préférence exposée à l'UI se stocke et se persiste dans `didSet`.
Et une `sheet(isPresented: .constant(…))` ne peut rien écrire en retour — elle ne se ferme jamais.

`-resetOnboarding 1` (DEBUG) force l'onboarding, `-startTab practice|settings|widgetPreview` et
`-openStep <id>` ouvrent un écran directement : Sharik pilote depuis son téléphone et ne peut pas
taper dans le simulateur, donc chaque écran doit être atteignable au lancement.

## À faire avant publication

- App Group `group.com.salat` à créer sur le portail Apple + `DEVELOPMENT_TEAM` à renseigner
  dans `project.yml` (vide aujourd'hui, build simulateur seulement).
- Icône d'app (le `AppIcon.appiconset` est vide).
- Relecture du contenu religieux par quelqu'un de qualifié — l'app le dit elle-même dans
  ses réglages, mais ça reste à faire.
