# Salat — apprendre la prière

App iOS (SwiftUI, iOS 17+) qui enseigne **ce qu'il faut dire pendant la salat** : le texte arabe,
sa prononciation écrite dans la langue du lecteur, et sa traduction. Trois temps : on lit (onglet
*Learn*, 14 étapes détaillées), on se fait interroger (onglet *Memorise*, exercices + travail de
la voix), et ça revient tout seul entre deux (**widget** qui fait défiler les positions).

## Nom : Learn Salah (depuis la 1.5, 17/11/2026)

Rebrand appseo : sous l'icône, l'app s'appelle **Learn Salah** (EN ; sur l'App Store **« Learn Salah: Muslim Prayer »**, « Learn Salah » seul étant pris par un autre compte),
**Apprendre la Prière** (FR), « Learn Salah: تعلم الصلاة » (AR). Le nom affiché vient de
`Salat/{en,fr}.lproj/InfoPlist.strings` (avec les trois textes de permission traduits) et doit
égaler le nom de la fiche dans chaque langue (règle 2.3.8). **Garder `en.lproj` à côté de
`fr.lproj`** : un bundle qui ne déclare que `fr` sert le français à un téléphone anglais. Le code,
le bundle, l'abonnement (« Salat Premium ») et les clés i18n gardent « Salat ». Les textes EN/FR de
la fiche viennent de `appseo/appseo.json`, captures de `appseo/out/redesign/iphone69/`.

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

Quatorze langues sont livrées : en, fr, ar, id, ms, ur, bn, tr, ru, es, pt, de, it, nl.

Quinze lignes empilées dans les réglages poussaient les rappels, le récitateur et le widget sous
la ligne de flottaison, pour un choix qu'on fait **une fois**. Le bloc n'en garde qu'une ligne
(code, langue en cours, chevron) et la liste vit dans `LanguagePickerView`, une feuille. Le
sous-titre doré « celle de mon téléphone » n'apparaît que si la préférence est `.system` : sans
lui, suivre le téléphone et avoir choisi cette langue à la main se ressemblent trop.

La **phonétique est propre à chaque langue** — un francophone ne lit pas `Subhaana` comme un
anglophone lit `Soubhâna`. Ne jamais recopier la phonétique EN dans un autre fichier. Le turc,
l'indonésien et le malais ont leurs propres traditions de translittération (`Sübhâneke`,
`Subhaanakallaahumma`) : ce sont elles qu'on suit, pas une romanisation maison. Le bengali écrit
sa phonétique en bengali, l'ourdou en romain ourdou.

**La langue du téléphone se lit dans `AppleLanguages`, jamais dans `Locale.preferredLanguages`.**
iOS rabote cette dernière aux localisations que déclare le *bundle*, et l'app n'en déclare aucune
(son contenu est du JSON, pas des `.lproj`) : un téléphone en turc y répondait « en », et toute la
détection retombait sur l'anglais. `AppLanguage.devicePreferredLanguages` lit la liste brute.

Les blocs multi-lignes (Fatiha, Tashahhud…) sont **appariés ligne à ligne** entre l'arabe, la
phonétique et la traduction : l'écran de détail affiche une carte par ligne, et c'est cet
alignement qui enseigne. Un test le vérifie (`testLinesPairUpBetween…`) — s'il casse, c'est
qu'une traduction a fusionné ou coupé un verset.

## Contenu religieux : périmètre assumé

Le déroulé retenu est le **tronc commun sunnite** (ce sur quoi les quatre écoles s'accordent).
Là où elles divergent (formulation du Tashahhud, position des mains, Qunut), la divergence est
**signalée dans le champ `note`, jamais tranchée**. Ne pas « corriger » une étape vers une école
particulière sans que Sharik l'ait demandé.

## Illustrations : une figurine 3D, modélisée en code

Depuis la refonte « Jardin » (14/11/2026), les neuf `pos_*.png` sont des **rendus Blender** :
une figurine en pâte à modeler (thobe crème, calotte verte), écrite en Python dans
`tools/blender/icons.py` (dictionnaire `FIGURES`) avec les briques du kit
`~/Documents/tools/icon3d`. C'est la même matière que les icônes 3D de l'app : les postures et
les objets parlent la même langue.

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b -P tools/blender/icons.py -- --figures --still ruku   # une image de réglage
$B -b -P tools/blender/icons.py -- --figures               # les neuf, dans Design/figures-render/
python3 tools/pack_figures.py                               # ombre nettoyée, 512×512, vers SalatKit/Resources
```

Contrainte non négociable : **aucun trait de visage** (pas d'yeux, pas de bouche, pas de nez).
La tête est une boule lisse ; une légère bosse de la même couleur dit seulement de quel côté
elle regarde, sans quoi le salam (tête tournée) ne se lit pas. Ne rien ajouter dessus.

L'ancienne chaîne (NanoBanana, `tools/generate-positions.py`, `cutout.py`, `pixelate.py`) est
restée dans `tools/` mais ne sert plus : les silhouettes plates pixellisées ont été remplacées.

**L'assise finale a deux dessins, et c'est voulu.** `pos_tashahhud` (étape 12) montre le poing
fermé posé sur le genou, `pos_tashahhud_index` (étape 13) le même corps avec l'index tendu :
c'est Sharik qui a tranché que le doigt ne se lève qu'à la prière sur le Prophète. Ne pas les
fusionner « puisque c'est la même posture ». Dans les deux, la main **repose sur le genou** —
elle a été livrée une fois pointant en l'air, et c'est la première chose qu'il a vue.

Le texte du geste, lui, dit l'index tendu dès l'étape 12, dans les 14 langues. La contradiction
avec l'image du poing est **connue et assumée** : le contenu religieux ne se réécrit pas sans
que Sharik l'ait demandé, et il a demandé l'inverse. Ne pas « réparer » ça de son propre chef.

Si un `pos_*.png` manque, `PositionMedallion` retombe sur `PostureFigure` — les silhouettes
dessinées en `Path`. C'est un vrai plancher, pas un placeholder : l'app reste utilisable et
conforme sans aucune image.

**L'icône d'app (depuis le 14/11/2026) : la mosquée 3D du bandeau, sur le vert de l'app.**
C'est Sharik qui l'a désignée (« la mosquée que t'as sur la bannière est pas mal »). L'icône
est donc le **même objet** que celui qu'on voit en ouvrant *Apprendre*, rendu par le même
script :

```bash
$B -b -P tools/blender/icons.py -- --appicon     # Design/appicon-render/mosque.png, 1024 px
python3 tools/make-appicon.py                    # pose la mosquée sur le fond, écrit AppIcon.png
```

`make-appicon.py` calcule le fond (dégradé vert, treillis d'étoiles à **huit** branches, halo
derrière la coupole), retire l'ombre au sol du rendu et sort du 1024×1024 **sans alpha** : iOS
refuse une icône transparente. Les icônes précédentes (étoile khatam sur crème en 1.0, arche
dorée sur fond nuit générée par NanoBanana en 1.1) sont dans l'historique git. L'icône de la
fiche App Store se met à jour avec le prochain binaire, pas avant.

## *Mémoriser* est un hall, pas un écran

L'onglet ouvre `ReviseHubView` : une liste d'**outils**, parce qu'il en viendra d'autres que les
exercices et la pratique vocale. Un outil = un cas de `ReviseTool` (titre, sous-titre et icône se
déduisent du `rawValue`, les clés i18n sont `revise.tool.<cas>.title|body`) plus un cas dans le
`switch` de `navigationDestination`. Rien d'autre à toucher.

Le nom interne est resté *Revise* (`AppTab.practice`, `ReviseRoute`, `-startTab practice`) : c'est
ce que disent tous les scripts de lancement et les liens profonds. Ce que lit l'utilisateur, lui,
est `tab.memorize`.

**La révision passive a été retirée de l'onglet.** Le carrousel montrait les quatorze mêmes étapes
que *Learn*, en plus lent : c'est le travail du widget, et le refaire ici ne donnait aucune raison
d'ouvrir cet onglet. Ce qui justifie un onglet, c'est d'être interrogé.

Trois niveaux, et l'ordre compte : **hall → galerie des étapes → page d'une étape**. La galerie
(`VocalGalleryView`) n'affiche que les étapes **parlées** — le niyyah ne se dit pas — et porte deux
marques distinctes : une onde dorée s'il existe un récitateur, un micro vert avec le nombre de
lignes déjà enregistrées. Ce ne sont pas des notes, juste des faits.

Le routage est une valeur (`ReviseRoute`), donc un lien profond est un tableau :
`-startTab practice -openTool vocal` ouvre la galerie, `-openTool drill` la manche d'exercices,
`-openStep <id>` descend directement sur l'étape. C'est la même règle que partout ici — Sharik
pilote depuis son téléphone et ne peut pas taper dans le simulateur, donc chaque niveau doit être
joignable au lancement. `-learnAll 1` marque les quatorze étapes acquises : sans ça un simulateur
neuf n'ouvre que l'état vide des exercices, et il n'y a rien à photographier.

## Les exercices : une leçon, sept façons de poser la même question

`SalatKit/Drill.swift` fabrique les questions à quatre réponses ; `SalatKit/DrillExercise.swift`
y ajoute deux **plateaux** et assemble la manche (`Drill.round`, huit exercices). Rien ne crée
**aucun contenu** : tout sort de `steps.<langue>.json`, questions comme mauvaises réponses. Un
distracteur tiré de la prière elle-même est plausible ; un distracteur inventé se repère au style,
et on répondrait sans rien savoir.

**La manche se joue comme une leçon Duolingo** (`DrillSessionView`) : barre de progression en
haut, un exercice plein écran, et le bas de l'écran appartient à un seul bouton large — Vérifier,
puis Continuer, avec le verdict au-dessus (vert sauge si juste, sable sinon, et la bonne réponse
écrite quand on a manqué). On choisit d'abord, on vérifie ensuite : une réponse encore modifiable
après le verdict ferait du verdict un indice. Pendant la manche la barre d'onglets flottante
s'efface (`TabBarHiddenKey`, une préférence lue par `ContentView`) : en pleine manche il n'y a
nulle part ailleurs où aller, et la barre d'action a besoin du bas de l'écran. Le trou du texte à
trous est un **emplacement doré souligné** qui reçoit l'option choisie — une rangée de puces se
lisait comme de la censure, pas comme « ton mot va ici ».

Cinq types de questions (`DrillQuestion.Kind`) : ce qui vient **après** une étape, quelles paroles
vont avec une **posture**, quelle **ligne** suit, quel **mot** manque, quelle ligne porte un
**sens**. La clé i18n se déduit du cas (`drill.q.<rawValue>`) : ajouter un type, c'est un cas, une
fonction de candidats et une clé dans les quatorze `ui.*.json`. Et deux plateaux, façon Duolingo
mais taillés dans le contenu : **associer les paires** (quatre lignes d'une même étape, phonétique
contre sens, colonnes mélangées et jamais alignées — des colonnes de niveau résoudraient chaque
rangée par sa voisine) et **remettre les mots dans l'ordre** (la ligne elle-même, coupée aux
espaces, jamais servie déjà en ordre ; en arabe la ligne arabe n'est pas montrée au-dessus de la
banque, ce serait la réponse entière). Une manche ouvre toujours sur une question à cartes,
jamais sur un plateau, et les plateaux s'intercalent aux positions paires. `-drillBoard
pairs|order` saute au premier plateau, `-drillVerdict right|wrong` pré-répond la première
question : l'état entre Vérifier et Continuer n'existe qu'un instant, et rien d'autre ne permet
de le photographier.

Trois garde-fous, chacun tenu par un test :

- **Quatre options distinctes ou pas de question.** Une option en double, ce sont deux bonnes
  réponses, et rien ne permet de corriger honnêtement : `build` rend `nil` plutôt que d'improviser.
- **Seules les étapes lues sont interrogées** (`known` ∪ `learning`). Interroger sur une étape
  jamais ouverte, ce n'est pas un exercice, c'est un tirage au sort ; l'état vide renvoie à
  *Learn*. C'est là qu'est le « plus » sur la lecture : la manche ne montre rien de neuf, elle
  redemande.
- **La posture ne s'appuie que sur une illustration unique.** Quatre étapes partagent `pos_qiyam`
  et deux `pos_sujud` : au-dessus de ces dessins, la question a plusieurs bonnes réponses.

Le texte à trous masque la **phonétique**, jamais l'arabe, et la carte ne montre pas l'arabe de la
ligne : ce serait la réponse, en entier. En arabe (où le champ phonétique est vide par construction)
`readingLines` retombe sur l'arabe lui-même.

Le tirage est **déterministe** : même graine, même manche (`SeededRandom`). Sans ça, une manche qui
sort une question fausse ne peut pas être rejouée, donc pas testée.

**On entre par une galerie, pas par une manche imposée** (`DrillPickerView`). L'outil *Exercices*
ouvre sur les huit portes — la manche mixte en pleine largeur, puis les cinq types de questions et
les deux plateaux, chacun nommé par la question qu'il pose (les clés `drill.q.*`, déjà traduites
quatorze fois) et portant le **nombre** d'exercices qu'il ouvre. Une rangée de puces filtre par
**étape** : le filtre rétrécit les sujets, jamais les distracteurs (`DrillRun.subject`), sinon la
manche filtrée se répondrait par élimination. Une carte à zéro se grise au lieu de disparaître —
une carte qui s'évapore avec le filtre ressemble à un bug. `Drill.run(_:)` sert toutes les portes
et **délègue à `Drill.round` quand rien n'est choisi** : un test vérifie l'égalité, pour que le
bouton du hall et la première carte ouvrent exactement la manche d'avant. Le bouton du hall et
`-openTool drill` atterrissent toujours **dans** une manche mixte (le geste quotidien reste un
tap, et tous les scripts attendent une question à l'écran), la galerie posée dessous sur le
chemin du retour ; `-drillPicker 1` s'arrête sur la galerie.

## Cartes mémoire et récitation en effacement : le rappel, pas la reconnaissance

Deux outils de plus dans le hall (`SalatKit/MemoryTools.swift`, vues dans `Views/Revise/`), et ils
posent une question que le drill ne sait pas poser : **dire la ligne sans qu'on la propose**. Le
drill reconnaît parmi quatre ; la carte mémoire montre le **sens seul** au recto — l'arabe ou la
phonétique au recto seraient la réponse — et le verso (arabe + phonétique) ne sert qu'à vérifier.
Le verdict est celui du lecteur (« je le savais » / « pas encore ») : un auto-jugement n'est pas
un score, donc **rien n'écrit dans `DrillLog`** — seules les pastilles du drill comptent des
réponses vérifiées. Une carte ratée retourne **sous** le paquet, jamais en case suivante : la
revoir dix secondes plus tard ne testerait que les dix secondes. Le paquet est tiré comme une
manche (même règle de pool, `SeededRandom`, plafonné à `deckSize`).

L'effacement (`Fade`) est l'échelle classique du hifz : la même étape, montrée avec de moins en
moins de mots, jusqu'à réciter sur rien. Le plan est **une propriété du texte, pas de la séance**
— pas de graine d'appel : `Fade.seed` (FNV-1a, parce que `String.hashValue` change à chaque
lancement) fait qu'une étape s'efface toujours dans le même ordre, et un mot caché **reste caché**
au cran suivant (monotone, tenu par un test). Un mot caché garde sa largeur (insécables soulignés
d'or, le même gabarit que le trou du drill) : le laisser s'effondrer referait la mise en page
sous la voix. La traduction ne s'efface jamais — elle est l'amorce, pas la matière. Grimper au
premier cran vaut `noteStudied` ; atteindre le dernier ne joue **pas** `win`, la fanfare reste
réservée à « étape acquise ». Lien profond : `-openTool flash`, `-openTool fade`, et
`-openTool fade -openStep <id>` descend sur l'échelle d'une étape (un `-openStep` nu garde son
sens d'avant, la page vocale).

## Ce qui revient, et ce que ça ne mesure pas

`DrillLog` compte, par étape, combien de fois elle a été demandée, combien de fois elle est revenue
juste, et quand elle a été ratée. C'est un **compteur, pas un second planificateur** : `StudyPlanner`
reste seul à décider quoi rouvrir, sinon le rappel nommerait une étape et l'écran une autre. Ce que
`DrillLog` fait, et rien d'autre : mettre en tête de la manche suivante ce qu'on rate
(`Drill.session(priority:)`).

Les pastilles du hall ne se remplissent qu'à partir de deux réponses, et jamais au-delà du nombre
de réponses données : une rangée pleine après un coup de chance serait un mensonge en images. Et
c'est bien un compte de réponses aux questions **de l'app**, pas un jugement sur une récitation :
ça, l'app ne le fait nulle part et le dit (`audio.compare.hint`).

Chaque réponse est écrite tout de suite, pas à la fin : une manche abandonnée au milieu a quand
même dit quelque chose. Répondre compte aussi comme avoir travaillé l'étape (`noteStudied`), donc
une journée passée uniquement dans les exercices garde la série vivante.

## Ce qui est récité est la seule chose allumée

Sur `VocalStepView`, la ligne en cours est **centrée, sur une plaque dorée, en pleine taille**, et
le reste de l'étape recule (opacité 0,72 — atténué, pas grisé : une ligne non sélectionnée reste
lisible si on la regarde exprès). La traduction n'apparaît que sur la ligne allumée, sinon la page
triple de hauteur et l'œil ne trouve plus l'arabe.

C'est **la lecture qui commande, pas le doigt** : `activeLine` prend `player.line` dès qu'une voix
sonne et ne retombe sur la sélection qu'au silence. Un `ScrollViewReader` recentre la ligne, sans
quoi « tout enchaîner » allume des versets sortis de l'écran.

Le numéro de ligne appartient à la page, pas au panneau (`RecitationPanel(step:line:)` prend un
`@Binding`) : deux copies dériveraient dès que l'un des deux bouge.

## Le son : dix voix, et presque toute la prière

`Salat/Resources/audio/` (dans **l'app, pas dans SalatKit** — le widget ne joue rien et n'a pas à
peser 9,2 Mo de plus) porte un mp3 par **ligne** d'étape, plus `recitations.json` qui les mappe
et porte les timings mot à mot. Tout est reproductible par `python3 tools/fetch-recitations.py`
(ffmpeg requis : les clips d'adhkar sont découpés au vol).

Le son vient de **deux sources**, et la coupure est nette :

- **Le Coran** (`fatiha`, `surah`) : neuf récitateurs d'everyayah.com, dont deux récitations
  d'enseignement (Husary *muallim*, Ayman Sowaid) — la seule distinction que l'app expose. Quatre
  d'entre eux (husary, alafasy, shatri, shuraym) prêtent aussi leur `audhubillah.mp3` au
  `taawwudh`. En ajouter un = une entrée dans `RECITERS` (+ `TIMING_FILES` si quran-align le
  couvre).
- **Les adhkar** (istiftah, ruku, itidal, sujud, jalsa, tashahhud, salawat) : la voix **Hisn
  al-Muslim** (hisnmuslim.com, site officiel du livre), un mp3 par dhikr, **découpé** à la fenêtre
  exacte de la formule — les enregistrements bruts portent un titre parlé et parfois « ثلاث
  مرات ». Les fenêtres et les timings mot à mot sont mesurés (whisper DTW + silences) et versionnés
  dans `tools/adhkar_cuts.json` ; chaque clip coupé a été retranscrit et comparé au texte attendu.
  Ne pas éditer ce fichier à la main : on remesure.

**Le repli est la règle** (`Recitations.effectiveReciter`) : la voix choisie dans les réglages joue
ce qu'elle couvre, et toute étape qu'elle ne couvre pas retombe sur la première voix qui la couvre.
Choisir Minshawy ne rend pas le tashahhud muet. Le menu du panneau n'offre que les voix qui
couvrent l'étape ; les réglages ne listent que les voix coraniques (les adhkar n'ont qu'une voix,
un « choix » d'une ligne serait du bruit). `sujud2` réutilise le clip de `sujud` : même texte.

Seuls **takbir et taslim** restent sans voix : deux formules courtes qu'aucun corpus propre ne
couvre. Ne pas boucher ces deux trous avec une TTS ou un clip d'amateur. Le détail des sources et
licences est dans `AUDIO_SOURCES.md`.

Le script refuse de tourner si les comptes (versets mappés, mots alignés) ne collent plus à
`steps.base.json`, et les tests le revérifient côté app (`RecitationTests`) : une dérive d'un
verset ferait jouer la ligne 3 sous la ligne 4 sans que rien ne plante.

## Écouter appartient à *Apprendre*, s'enregistrer à *Réviser*

Le son est coupé en deux panneaux, et la coupure est pédagogique : `ReciterPanel` (la voix du
récitateur, le choix de la voix, le 0,6×, « tout enchaîner ») est ce qu'il faut pour **apprendre**
une étape, donc il vit dans la page d'étape de *Apprendre* ; `RecitationPanel` (le micro, les deux
tracés) est un outil de **mémorisation**, donc il reste dans *Réviser*.

`VocalStepView` affiche les deux : on écoute le modèle, puis on le dit. Un micro posé dans
*Apprendre* demandait de réciter à quelqu'un qui n'a pas encore entendu la formule.

**Le panneau d'écoute se place juste sous l'illustration, jamais après le texte.** Posé en bas de
page, il arrivait derrière les sept cartes de la Fatiha : Sharik a ouvert l'étape et a demandé où
étaient passés les récitateurs. Un bouton qu'il faut chercher n'existe pas. Le micro, lui, reste
en bas : on s'enregistre après avoir lu, et c'est le seul geste ici qui mérite un défilement
volontaire.

Dans *Apprendre*, le panneau **disparaît** sur les douze étapes sans clip (`hasReciter`) au lieu
d'afficher « aucune récitation » : sans micro à proposer en face, c'est une phrase sur rien, en
haut de page. *Mémoriser* la garde, parce qu'elle y explique pourquoi il n'y a pas de modèle.

Les pastilles vertes sur les numéros de verset (ce qui est déjà enregistré) ne s'allument que
là où le micro existe : `marksRecordings`. Dans *Apprendre* elles pointeraient vers rien.

## Le karaoké : deux curseurs, deux honnêtetés

Le mot en train d'être dit s'allume pendant la lecture. Les timings viennent de
**quran-align** (CC BY 4.0, la seule pièce réellement libre de la chaîne audio — attribution
payée dans les réglages, clé `settings.audio.timing`), embarqués dans `recitations.json` et
servis par `Recitations.wordSpans`. Huit voix coraniques sur neuf sont couvertes ; Sowaid n'a
pas de timing et son curseur reste éteint — ne pas le fabriquer à la main. Les adhkar et les
taawwudh ont leurs timings **mesurés maison** (whisper DTW, `tools/adhkar_cuts.json`) : même
contrat d'exactitude, autre instrument.

- Le curseur **arabe est exact** : une plage temporelle par mot, mesurée sur ces
  enregistrements. `tools/fetch-recitations.py` refuse de tourner si une ayah alignée n'a pas
  exactement le compte de mots de notre texte, et un test le revérifie
  (`testWordTimingsPairWithArabicWords…`).
- Le curseur **phonétique est une projection** (`Karaoke.projected`) : aucune langue ne découpe
  sa translittération comme l'arabe (`Bismillaahi` fusionne deux mots), donc l'index arabe est
  projeté proportionnellement, ancré aux deux bouts. C'est un guide pour l'œil, pas une mesure —
  ne pas « réparer » les phonétiques pour forcer un appariement 1:1, elles suivent les
  traditions de translittération de chaque langue.
- Un seul mot doré, **pas de traînée** côté récitateur : sur la plaque dorée de la ligne active,
  la traînée rendait la ligne entière or et le curseur disparaissait.
- Pendant l'enregistrement, la reconnaissance vocale **sur l'appareil uniquement**
  (`requiresOnDeviceRecognition`, arabe `ar-SA`) allume en **vert cumulatif** les mots déjà
  entendus (`VoiceRecorder.matchedWords`). Position, jamais jugement : ça avance quand un mot
  est entendu, ça ne note rien, ça ne bloque rien. Si l'appareil ne sait pas reconnaître
  l'arabe localement, le curseur reste éteint et l'enregistrement marche comme avant — pas de
  repli réseau, la page de confidentialité promet que rien ne sort du téléphone.
- L'horloge du curseur est une `TimelineView(.periodic)` **montée seulement sous la ligne qui
  sonne** : quatorze cartes qui interrogent l'horloge en continu, c'est un écran qui chauffe
  pour rien.
- `-recite 1` (avec `-openStep`) lance « tout enchaîner » à l'arrivée : le curseur n'existe que
  pendant qu'une voix sonne, et personne n'est là pour appuyer sur lecture avant la capture.

Le recorder est un `AVAudioEngine` (plus un `AVAudioRecorder`) : le même robinet de buffers
écrit le m4a, mesure le niveau et nourrit le recognizer. Fermer le fichier **avant** de bumper
`revision`, sinon les vues lisent un m4a sans header final.

## Comparer n'est pas noter

Le panneau enregistre la voix de l'utilisateur (`Documents/recordings/<étape>_<ligne>.m4a`, jamais
dans l'App Group : une voix qui prie ne se range pas dans un conteneur partagé) et pose les deux
tracés **sur le même axe de temps**. C'est là toute la comparaison : deux formes d'onde étirées
chacune à sa largeur donneraient exactement la même image à une récitation précipitée et au modèle.

Les deux tracés passent par le **même** extracteur (`Waveform`, AVAssetReader) et sont normalisés
chacun sur son propre pic : on compare la forme et le rythme, pas le volume d'un micro de téléphone
contre un studio. Mesurer les deux différemment (le compteur dB du recorder d'un côté, les crêtes
décodées de l'autre) donnerait deux dessins qu'on n'a pas le droit de superposer.

**Aucun score.** Rien ici ne juge une prononciation — aucune app ne sait le faire, et prétendre le
contraire sur un texte sacré serait un mensonge coûteux. L'écran le dit lui-même
(`audio.compare.hint`) : ça montre la forme, pas si c'est juste.

La session audio revient toujours en `.ambient` + `mixWithOthers` après coup
(`AudioSession.release`) — une app de prière qui tue définitivement la récitation qu'on écoutait en
fond est une app qu'on ferme.

## Trois états, pas deux — et une page qui les raconte

Une étape est `untouched`, `learning` ou `known` (`SalatKit/StudyLog.swift`). Le milieu est le
point : c'est là que vivent la plupart des quatorze étapes pendant des semaines, et sans lui
l'app ne savait dire que « pas fait », c'est-à-dire exactement ce qu'elle disait le jour de
l'installation. La fiche d'étape pose donc **deux** questions (« Je l'apprends », « Acquise ») ;
retaper le bouton allumé annule ce statut, il ne fait pas redescendre d'un cran.

`StudyLogState` porte les statuts **et** le journal dans une seule valeur, écrite d'un bloc :
un changement de statut enregistré sans son événement serait un trou dans l'historique que la
page de progression dessine. **Ouvrir la fiche est la session d'étude** (`noteStudied`) — c'est
ce que compte le calendrier et c'est là-dessus que se mesure « pas revu depuis longtemps » ;
cocher une case après coup est un avis, être devant l'étape est un fait. Une même étape rouverte
dix fois dans la journée n'écrit **qu'une** ligne de journal, et le journal est plafonné à 500
lignes (les plus vieilles partent).

`StudyPlanner.queue` est **l'unique ordre** de l'app : commencé-puis-abandonné le plus longtemps
d'abord, puis jamais ouvert (dans l'ordre de la prière — une étape sans histoire n'a pas d'âge),
puis acquis mais pas revu depuis dix jours. La page *Ma progression* et le rappel du jour lisent
la **même** file : deux ordres voudraient dire que la notification nomme une étape et l'écran une
autre.

L'ancienne liste plate (`progress.learned`) n'est plus lue que pour **migrer** — les coches d'une
version à deux états deviennent `known`, sans date inventée. Elle continue d'être écrite pour que
restaurer une sauvegarde ne fasse pas disparaître quatorze coches.

`-demoProgress 1` (DEBUG) remplit un mois de lecture plausible : la page de progression est
l'image d'un historique, et un historique met des semaines à exister. `-openAnalytics 1`
l'ouvre directement — même raison que partout ici.

## Le rappel : écrit d'avance, et il s'arrête tout seul

`StudyReminders` planifie **quatorze notifications datées** (une par jour, à l'heure choisie),
pas un déclencheur répétitif : iOS ne réveille jamais l'app pour en fabriquer une, donc tout ce
qui doit survivre à une app jamais ouverte s'écrit à l'avance. Le plan est réécrit à chaque
retour au premier plan, ce qui garde les messages pointés sur la tête de `StudyPlanner.queue` —
donc sur ce qui a été commencé puis laissé de côté, avant ce qui n'a jamais été ouvert.

Passé deux semaines sans retour, il n'y a plus rien : une app qui tape sur l'épaule de quelqu'un
qui ne répond plus se fait supprimer, pas ouvrir. C'est un choix, pas un oubli.

`StudyReminders.plan(...)` est **pur** (des étapes, une heure, une horloge → des brouillons) et
c'est là que vivent les tests : dates dans le futur, jamais une étape déjà cochée, message de
fin quand les quatorze sont acquises. Le reste n'est que le passage à `UNUserNotificationCenter`.

L'autorisation est demandée **quand l'interrupteur passe à ON**, jamais au lancement ; un refus
remet l'interrupteur à sa place plutôt que de le laisser allumé sur un système qui ne postera
rien. Rien ne s'affiche quand l'app est ouverte (`willPresent` → `[]`) : le rappel sert à faire
revenir, et l'utilisateur est déjà là. Taper le rappel ouvre **l'étape qu'il nommait**
(`pendingStepID`, consommé une fois par `LearnView`).

Les trois formulations tournent (`notif.body.1..3`) pour que la même phrase n'arrive pas tous
les matins, et elles nomment l'étape — un rappel générique se lit comme une pub. Une étape
**commencée** a son propre message (`notif.body.learning`) et une étape acquise qui redemande un
passage le sien (`notif.body.review`) : « une chose de plus à faire » et « tu avais commencé »
ne se disent pas pareil.

## Le widget n'est pas un carrousel animé

WidgetKit ne rend que des instantanés statiques et **c'est iOS qui décide quand les échanger**.
Le « défilement » est donc une timeline d'une entrée par minute, rebâtie quand elle s'épuise
(`CarouselProvider`). Une rotation à la seconde est impossible — le système l'ignorerait. La
rotation est calée sur l'horloge (`timeIntervalSince1970 / 60`) pour que deux widgets restent
en phase.

**Ce qu'il montre est un rappel, pas un sommaire.** `CarouselPlan` — une valeur pure, donc testée
depuis `SalatTests` — décide de l'étape, dans cet ordre : ce qui est **`learning`** d'abord (mettre
une étape en apprentissage, c'est le lecteur qui dit *c'est celle-là que je travaille* — le widget
ne répond qu'à ça) ; sinon tout ce qui n'est pas encore `known`, le comportement d'avant, qui tient
tant qu'aucune étape n'a été prise en main ; sinon les quatorze, parce qu'un lecteur qui sait tout
mérite une répétition, pas une carte vide. Et pendant `pinWindow` (5 min) après l'ouverture
d'une étape, le widget **s'arrête sur celle-là** avant de reprendre le cycle : en sortant de
l'app, on doit encore voir ce qu'on travaillait. C'est `lastStudied` du `StudyLog` qui le dit —
aucun état en plus — et `noteStudied` déclenche déjà le `reloadAllTimelines`.

**Le sujet du widget est la phonétique, affichée en entier.** C'est elle qu'on essaie
d'apprendre : jamais de `lineLimit` dessus, jamais une première ligne suivie de points de
suspension — une demi-formule n'enseigne rien, on préfère la laisser rétrécir (`minimumScaleFactor`
jusqu'à 0,45). Une étape muette (le niyyah) affiche son geste à la place.

**En couleur, le widget est le bandeau de l'app en petit** (14/11/2026) : un fond vert au
treillis blanc qui porte la figurine 3D, le nom de l'étape et le compteur, et les paroles sur
blanc à côté. Le vert court en haut sur le petit et le grand (`banded`), sur le côté sur le
moyen (`sided`), où les paroles ont besoin de la largeur. Il va **jusqu'au bord** : l'extension
déclare `contentMarginsDisabled()`, et c'est aussi ce qui rend l'aperçu dans l'app exact (lui
n'a jamais eu les marges du système autour).

**Le reste vient s'il y a la place, et ce n'est pas nous qui en décidons.** Les trois tailles
partagent une seule mise en page ; c'est `ViewThatFits` qui essaie la version la plus complète
— phonétique + arabe + traduction —, puis retombe d'un cran à la fois. Une formule courte remplit
donc la carte jusqu'à l'arabe même en petit, la Fatiha ne garde que sa phonétique même en grand.
Ne pas remplacer ça par des `if family == …` : c'est la longueur du texte qui commande, pas la
taille du widget. `-startTab widgetPreview -openStep fatiha` cadre le cas long, celui qui casse.

État partagé app ⇄ widget via l'App Group `group.com.salat` (`SharedStore`). Toute écriture de
réglage doit passer par `AppSettings`, qui déclenche `WidgetCenter.reloadAllTimelines()`.

**Un écran d'accueil teinté ne montre pas ce que le widget a peint** : iOS n'en garde que la
*luminance* et la reteinte. La crème disparaît, l'encre brune avec — le widget se lit comme une
carte vide, et c'est exactement la panne qu'on a livrée une fois. `CarouselWidgetView` lit donc
`\.widgetRenderingMode` : en `fullColor` la DA normale (plaque blanche, pastille verte), sinon tout est
redessiné en clair, l'illustration passée en `.template` (le PNG porte la figure dans son alpha)
et le `containerBackground` laissé vide (mise en page `bare`, sans bandeau). La règle : **rien ne doit dépendre d'une couleur sombre
sur un fond clair pour être visible**. Le simulateur, lui, est en clair — cette panne ne s'y voit
pas, elle se vérifie par `-startTab widgetPreview`, qui affiche les deux rendus l'un sous l'autre.

Le widget est archivé ici puis **dessiné par un autre processus**, qui ne résout que les polices
déclarées par le bundle. Il n'utilise plus que des polices système depuis la refonte ; si une
police embarquée y revient, elle doit être listée dans `UIAppFonts` de `SalatWidget/Info.plist`,
sinon son texte sort vide.

## Direction artistique « Jardin » (refonte du 14/11/2026)

Demande de Sharik : refaire tout le design en s'inspirant de **SelfTransfer**
(`~/Documents/IOS/SelfTransfer`), objets 3D, très amical, palette verte et beige, écrans moins
encombrés. Tout est dans `SalatKit/Theme.swift` :

| Rôle | Couleur |
|---|---|
| page | beige `#FAF4E6` |
| cartes | blanc, contour pastel `#E7DBC1` |
| tout ce qui se presse, bandeau, onglet actif | vert `#2FA56F` (arête `#1E7A50`) |
| sélection, médaillon de posture | menthe `#E1F4E8` |
| accent : le mot récité, une étape en cours, une récompense | or `#DE9A12` |
| texte | encre verte `#1F3329`, secondaire `#6C7B70` |

Le vert est **la** couleur d'action ; l'or ne sert plus qu'à trois choses (le curseur du
récitateur, « en cours », la récompense). Un bouton doré est donc un bug, pas une variante.

Tout le texte est en **SF Rounded** (`Theme.rounded`), graisses heavy et black : c'est ce qui
rend l'app amicale. L'arabe reste en Geeza Pro. La police pixel `04b30` a été **retirée**
(fichier supprimé, plus de `UIAppFonts` dans le widget) ; `Theme.pixel()` existe encore parce
que tous les compteurs l'appellent, mais rend des chiffres ronds à chasse fixe.

## Les formes viennent de SelfTransfer

`SalatKit/Plate.swift`. Deux objets, et on ne les mélange pas :

- **Ce qu'on lit est une carte** : face blanche, contour **pastel** épais (2,5 pt), jamais
  d'ombre floue. Le contour n'est jamais l'encre : un trait sombre dessine des boîtes, un trait
  pastel dessine des objets. `.card()` pour une carte, `.card(padding: 0)` pour une carte de
  lignes (elle est alors rognée, pour qu'une ligne pressée garde les coins).
- **Ce qu'on presse est une dalle sur son arête** (`ChunkyFace`) : la face descend d'un coup
  sur l'arête plus sombre, remonte sur un ressort, et un tap éclair reste enfoncé 0,09 s pour
  être vu. La vibration part **à la descente**. `.chunky(couleur)` pour un bouton libre,
  `.buttonStyle(.cta(.primary | .secondary | .gold | .danger))` pour **le** bouton de l'écran :
  un seul par écran, vert, pleine largeur.

Une ligne dans une carte ne s'enfonce pas, elle se teinte (`RowPressStyle`) : la carte est
l'objet, la ligne n'est qu'un endroit dessus.

Les rôles du retour haptique n'ont pas changé (`Feedback.swift`) : `select` pour un cran de
choix, `press` pour un geste plein, `win` pour la seule fanfare (marquer une étape acquise).
Le motif de fond reste l'étoile à **huit** branches (khatam), jamais un hexagramme.

## Les objets 3D (kit `~/Documents/tools/icon3d`)

27 icônes modélisées en code dans `tools/blender/icons.py` (dictionnaire `ICONS`), sept images
chacune, rangées dans `Salat/Assets.xcassets/Icons3D` :

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b -P tools/blender/icons.py -- --still mosque     # régler une icône
$B -b -P tools/blender/icons.py -- mosque             # ses sept images (environ 1 min)
python3 ~/Documents/tools/icon3d/pack_icons.py Design/icons-render Salat/Assets.xcassets/Icons3D
```

`pack_icons.py` **réécrit le dossier entier** : il lui faut tous les rendus dans
`Design/icons-render/` (git-ignoré, reproductible). Ajouter une icône = une fonction dans
`ICONS`, un cas dans `enum Icon3D` (`Salat/Components/LofiIcon.swift`), puis rendre et ranger.

Côté app : `LofiIcon(.book, size:, interval:, animated:)` joue l'icône en lofi, `IconTile` la
pose sur un carré menthe. **L'élément qui compte s'anime, le reste est sage** : l'onglet actif,
le héros du bandeau, la récompense. Les SF Symbols restent pour les contrôles purs (fermer,
chevrons, lecture, micro).

## Les écrans : un bandeau, une chose à faire, le reste derrière

La refonte a surtout **rangé**. La règle : chaque onglet ouvre sur un `Banner` vert (titre +
objet 3D), puis sur l'unique chose à faire, en vert ; tout ce qui se choisit une fois vit dans
une feuille (`SheetScaffold`).

- *Apprendre* : la pastille du bandeau **est** le bouton de progression ; la carte « à ouvrir
  maintenant » lit la tête de `StudyPlanner.queue` ; les quatorze étapes sont une seule carte
  de lignes. Acquise = écusson 3D, en cours = pousse 3D : deux formes, pas seulement deux
  couleurs.
- *Mémoriser* : une carte de démarrage (la manche mixte), puis les outils en tuiles.
- *Réglages* : des lignes qui disent leur valeur ; langues, récitateurs et crédits sont trois
  feuilles (`LanguagePickerView`, `ReciterPickerView`, `AboutView`).
- La barre d'onglets (quatre onglets : Apprendre, Coran, Mémoriser, Réglages) est **arrimée** en bas (`NavBar`, ex `FloatingTabBar`), avec les icônes
  3D ; les inactives sont désaturées. Elle s'efface toujours pendant une manche
  (`TabBarHiddenKey`).
- Marquer une étape acquise joue `CelebrationView` (plein écran, objet qui tombe, étincelles,
  fanfare) puis referme la fiche.

## L'onboarding : « continue de scroller, mais scrolle le Coran » (25/11/2026)

Réécrit le 22/11, puis **retourné le 25/11/2026** à la demande de Sharik (zéro vente) : on ne
reproche plus le scroll, on le **redirige**. Même mécanique (calqué sur SelfTransfer,
`Salat/Views/OnboardingView.swift`) : chaque page est une scène qui boucle (`MotionLoop` +
`MotionCanvas`) sur un ciel vert, un titre et une phrase dessous. Huit pages (`WelcomePage`),
une seule histoire, chacune tenue par une technique de conversion :

1. **L'accroche.** `scroll` : un fil gris défile sous le pouce, puis le même geste fait
   monter une carte du fil du Coran (`QuranFeedCard` : photo, verset, sens, cœur qui
   s'allume). Titre : « Continue de scroller. Mais scrolle le Coran. »
2. **La personnalisation.** `goal` : *qu'est-ce que tu veux le plus ?* (`WelcomeGoal` :
   moins scroller, lire le Coran chaque jour, apprendre ma prière, l'apprendre par cœur ;
   `GoalPicker`, `onboarding.goal.<cas>`). `hours` : les heures par jour (`HoursPicker`).
   « Continuer » attend une réponse sur les deux.
3. **Le coût.** `reckoning` : les heures multipliées en jours par an
   (`OnboardingManager.daysPerYear`, 4 h → 61 jours), puis « et si dix minutes allaient au
   Coran ? ».
4. **Le produit en main.** `feed` : un vrai petit fil (`FeedDemo`) qu'on fait défiler au
   doigt, cinq lignes de la Fatiha sur photo, double tap = cœur. Puis `words` et `widget`.
5. **Le plan.** `plan` (`PlanBuild`) : quatre lignes qui se remplissent (langue, fil du
   Coran, prière, widget), puis une carte « Ton objectif : … / 10 minutes par jour, à la
   place du fil ». « Continuer » attend la fin (instantané avec Réduire les animations).
6. **L'engagement.** `WelcomeCommitView` : l'heure du rappel, comme avant.

Puis, sans Premium, **le paywall prend l'écran**. Il reprend la réponse (`paywall.headline`
« Échange ton fil contre le Coran », l'objectif en tête de l'accroche), montre une carte du
fil au lieu d'un aperçu générique, et, quand l'essai est offert, une **frise d'essai**
(aujourd'hui / rappel la veille / début de l'abonnement) et « Rien à payer maintenant ». Le
rappel de la frise est **vrai** : `TrialReminder` pose la notification `trial.end` la veille
de la fin d'essai après un achat réussi. `StudyReminders` ne retire plus que ses propres
`study.reminder.*` (avant, il effaçait toutes les notifications en attente, rappel d'essai
compris).

**Ce que ces pages s'interdisent** (règle 5.6 et choix de Sharik) : aucune statistique ni
aucun avis inventé, le seul chiffre est la réponse du lecteur multipliée par 365/24 ; aucune
promesse au-delà de ce que fait l'app ; rien qui tranche entre les écoles. Les heures
(`onboarding.phoneHours`) restent dans `UserDefaults` et ne partent jamais ; l'objectif
(`onboarding.goal`) aussi, et seul son identifiant part dans la télémétrie
(`onboarding_goal`).

**Entonnoir mesuré** (app-metrics) : `onboarding_step` (valeur = rang, `page` = nom) à chaque
page, `onboarding_goal`, `onboarding_done`, `paywall_view`, `purchase_tap` (`trial` oui/non).
C'est ce qui dit où l'on perd les gens avant de toucher au prix.

Il est monté en **surcouche** dans `ContentView`, plus en feuille : une feuille
`.constant(true)` ne se ferme jamais, c'est la panne qui a déjà été livrée une fois. Les
textes sont les clés `welcome.<page>.title/body`, `welcome.goal.*`, `welcome.feed.*`,
`welcome.plan.*`, `welcome.hours.*`, `welcome.reckoning.*`, `welcome.commit.*`,
`paywall.timeline.*`, `paywall.nopay`, `notif.trial.*` et `common.continue`, dans les quatorze
langues.

## La page du widget : le voir, l'ajouter, le régler

`WidgetToolView` (outil *Widget d'accueil* du hall) tient en un écran :

- **L'aperçu** est le vrai `CarouselWidgetView` posé sur un écran d'accueil dessiné
  (`Salat/Components/HomeScreenMock.swift`, fond d'écran vert sombre, icônes pastel sans
  glyphe). Sur le beige de la page il se lisait comme une carte de plus ; sur un fond d'écran
  il se lit comme ce qu'il est. Les mêmes pièces servent à l'onboarding et au tutoriel.
- **Un bouton, « Ajouter à l'écran d'accueil »**, ouvre `WidgetGuideView` : trois pages, chacune
  un petit téléphone qui montre où va le doigt (appui long, Modifier puis Ajouter un widget,
  chercher Salat). Calqué sur le guide de DoodleNest. Les libellés `guide.edit` et
  `guide.addWidget` sont **ceux d'iOS dans chaque langue** ; en ourdou et en bengali ils
  restent en anglais, iOS n'ayant pas d'interface dans ces langues.
- **Les réglages sont trois lignes à menu** (`MenuRow`) : ce qu'il montre (la prière ou des
  extraits du Coran, voir plus bas), l'étape (seulement si « une seule étape ») ou « Mes
  extraits » (seulement si Coran), le texte affiché en premier. Avant, sept choix en boutons radio sur
  deux écrans, pour une chose qu'on règle une fois.

`-openTool widget -openWidgetGuide 1 -guidePage 0…2` ouvre le tutoriel sur une page.

Le son des clics a été baissé le même jour (`Sound.bank`, 0,34 → 0,13) : avec un clic sur
chaque ligne et chaque puce, c'était ce qu'on entendait le plus dans l'app.
Le 25/11/2026, Sharik l'a trouvé **trop aigu** : l'ancien clic de clavier avait sa brillance à
7 kHz. `ui-click.mp3` est désormais un **coup de bois sourd en ré grave** (banque earshot
`knock/wood --pitch D4`, son fabriqué en code, aucune licence), brillance ~770 Hz, le registre de
`ui-nav`. Rendu : `earshot sfx render knock/wood --pitch D4`, puis −8 dB et un fondu de 30 ms.

## L'onglet *Coran* : le livre entier, en fil d'extraits

Demande de Sharik (14/11/2026), en deux temps. D'abord : une page dans la barre d'onglets où
l'on fait défiler le Coran, l'écriture au milieu, un récitateur, et la possibilité de couper
le son. Puis, le même jour : « vraiment un style à la TikTok », avec les cœurs sur le côté,
des commentaires personnels (modèle : `~/Documents/IOS/selfShortVideo/localShort`), des
extraits courts au lieu de versets entiers, et de vraies images liées à l'islam en fond, sous
un filtre sombre. C'est le deuxième onglet (`AppTab.quran`, `Salat/Views/QuranView.swift`,
icône 3D `quran` : un mushaf fermé, pour ne pas se confondre avec le livre ouvert
d'*Apprendre*).

**Le fil est une seule liste** d'écrans (`Quran.pages`) : pour chaque sourate, sa page
d'ouverture puis ses versets, un verset long occupant plusieurs écrans (`part` sur `parts`).
Une seule liste et non une par sourate, pour que le pouce passe du dernier verset d'une
sourate à la suivante sans rencontrer de bord. Défilement paginé
(`scrollTargetBehavior(.paging)`), image bord à bord sous la barre d'état, et l'identifiant
d'un écran **est** son rang.

Quatre règles tiennent l'écran :

- **La basmala a sa page.** Les fichiers des récitateurs coupent le Coran verset par verset.
  Tanzil colle la basmala au verset 1 de chaque sourate ; les mp3, non (`002001.mp3` ne dit
  que « Alif Lam Mim »). `tools/fetch-quran.py` la détache donc, et l'app la montre sur la
  page d'ouverture, où le récitateur la dit (c'est le fichier `001001`). La Fatiha, dont elle
  *est* le verset 1, et at-Tawba, qui n'en a pas, ouvrent sur une page muette qui tourne seule.
- **Un verset long est coupé en extraits, et pas n'importe où** (`QuranExcerpt`). Jusqu'à
  quatorze mots, le verset reste entier. Au-delà il est coupé aux **signes de pause du
  mushaf** (U+06D6, 06D7, 06D8, 06DA), en morceaux d'une douzaine de mots ; jamais sur
  U+06D9, qui veut dire « ne t'arrête pas ici ». Rien n'est retiré ni déplacé : les extraits
  remis bout à bout **sont** le verset, et un test le tient pour les 6236. La traduction est
  coupée aux mêmes proportions (poids en lettres de chaque extrait arabe), de préférence sur
  une ponctuation : c'est une **approximation**, elle ne prétend pas que tel mot traduit tel
  mot. Une traduction trop courte pour être coupée reste entière sur chaque écran.
- **La voix ne redémarre pas au milieu d'un verset.** Un verset reste **un seul fichier** :
  chaque écran en joue une portion (`Quran.span`, les mêmes poids en lettres), la fin de la
  portion tourne la page sans arrêter le son, et `QuranPlayer.carryOn` dit seulement à la
  lecture où s'arrêter ensuite. La portion est une estimation, pas une mesure : la page peut
  tourner un mot trop tôt ou trop tard. Ne pas la vendre comme un karaoké.
  La page tournée par la voix est **échangée, pas défilée** (`advance`) : les mots
  s'estompent, le fil saute, les mots reviennent. Un défilement animé d'une `LazyVStack`
  lâche la page quittée avant d'avoir dessiné la suivante, et l'on voyait un écran vert vide
  au milieu d'un verset. Dans un même verset l'image ne bouge donc pas ; entre deux versets
  elle change sous un instant de noir. Ne pas remettre de `withAnimation` sur `position`.
- **La voix suit le pouce.** Arriver sur une page lance son extrait (après 0,35 s, pour ne
  rien lancer sur une page seulement traversée) ; seul un extrait allé au bout tourne la
  page. Un tap met la voix en pause, un double tap pose un cœur. Son coupé, rien ne tourne
  tout seul : c'est de nouveau un livre.

**Ce qu'il faut lire est au milieu, et rien ne lui dispute l'œil.** Le verset est posé sur
une plaque sombre translucide, en blanc, la traduction dessous ; `ViewThatFits` essaie cinq
tailles. Autour : la sourate en haut à gauche (elle ouvre la liste), le son en haut à droite,
la référence, les tirets d'extraits et le récitateur en bas à gauche, la colonne d'actions à
droite (cœur, notes, partager, mes versets). Tout ce qui n'est pas le verset est en verre
(`GlassCircle`), jamais en dalle verte : sur une photo, une dalle pleine devient le sujet.

**Les fonds sont des photos, pas des rendus** : 25 images dans
`Salat/Resources/backgrounds/quranbg_*.jpg` (3,9 Mo), prises sur Pinterest à la demande de
Sharik (« pas générer »). `QuranBackground.index` en choisit une d'après la sourate et le
verset, donc un verset garde toujours la sienne et tous ses extraits la partagent.
`QuranBackdrop` les passe sous une légère désaturation et un voile noir : c'est le filtre
demandé, « pour ne pas détourner l'œil » et pour que des images de mains différentes aient la
même tenue. **Les droits ne sont pas réglés** (auteurs inconnus) : tout est dit dans
`QURAN_BACKGROUNDS.md`, avec les règles de tri (aucun être vivant, aucun texte, aucune étoile
à six branches). Ajouter ou remplacer une image = déposer un `quranbg_NN.jpg` ; dossier vide,
le fil retombe sur des dégradés.

**Les cœurs et les notes sont un carnet, pas un réseau** (`Salat/Quran/QuranJournal.swift`,
feuilles dans `Salat/Views/QuranSheets.swift`). La feuille de notes a la forme d'un fil de
commentaires parce que c'est le geste qu'un fil a appris, mais elle n'a qu'un auteur : tout
reste dans les `UserDefaults` du téléphone, rien ne part, et la feuille le dit
(`quran.notes.hint`). Un cœur ou une note appartient au **verset** (`VerseRef`), jamais à un
écran : le découpage en extraits peut changer, un cœur doit survivre. « Mes versets »
(`QuranSavedView`) liste tout ce qui est marqué ; sans elle un cœur est un cul-de-sac.
`QuranLikes.all()` rend les cœurs lisibles hors du fil (pour le choix d'extraits du widget).
Rien de tout ça ne va dans la télémétrie : seule l'ouverture de l'onglet est comptée.

**Le texte est de la donnée** (`Salat/Resources/quran.base.json` + `quran.<code>.json`, dans
l'app seulement, 15 Mo), reproductible par `python3 tools/fetch-quran.py` : texte arabe
*simple* de Tanzil (le même script que la Fatiha de l'app, lisible en police système) et une
traduction par langue, via api.alquran.cloud. Le script refuse d'écrire si un compte ne colle
pas (114 sourates, 6236 versets, 112 basmalas détachées, chaque traduction verset pour
verset) et `QuranTests` le revérifie côté app. **Ne jamais éditer un verset à la main.** La
basmala se lit dans la source, elle ne se tape pas : les mêmes lettres peuvent être encodées
avec leurs signes dans un autre ordre, et une copie tapée ne correspond alors à rien.

Les traductions (Hamidullah en français, Saheeh International en anglais, etc. : la table est
dans le script) sont créditées dans *À propos* avec le nom du traducteur. **Il n'y a pas de
phonétique** : aucune translittération du Coran entier n'existe dans les traditions de chaque
langue, et recopier l'anglaise partout est exactement ce que ce fichier interdit plus haut.

**Le son est téléchargé, pas embarqué** (`Salat/Quran/QuranAudio.swift`) : neuf récitateurs
fois 6236 versets pèsent plusieurs gigaoctets. Chaque verset vient d'everyayah.com à la
première écoute (`Reciter.source` + `SSSVVV.mp3`), le suivant est préchargé pendant que
celui-ci sonne, et tout est gardé dans `Caches/quran-audio/`, plafonné à 250 Mo. Le
récitateur est celui des réglages. Hors connexion, le verset s'affiche et une ligne le dit
(`quran.offline`). `QuranPlayer` est distinct de `RecitationPlayer` : il attend un
téléchargement, et un verset demandé puis dépassé ne doit jamais partir en retard sur le
suivant (jeton `token`). La session audio est tenue d'un verset à l'autre et rendue à
l'arrêt.

**C'est le seul endroit où l'app télécharge du contenu**, et ça engage deux déclarations :
la page de confidentialité (`sharik-dev/salat-support`) dit encore que le réseau se limite
aux pubs et aux statistiques, elle doit mentionner everyayah.com **avant** la prochaine
soumission ; et les traductions sont du contenu tiers de plus, dont les licences n'ont pas
été vérifiées une à une.

La place est retenue (`QuranBookmark`, sourate et verset, pas un rang).
Liens profonds : `-startTab quran -quranSurah 2 -quranVerse 255` (arrive sur le premier extrait
du verset), `-quranMuted 1`, `-openSurahs 1`, `-openQuranNotes 1`, `-openQuranSaved 1`.

**Le simulateur est partagé** avec les autres sessions et les studios d'agents : une capture
blanche ou un écran d'une autre app au milieu d'une série, c'est quelqu'un d'autre qui vient
de lancer la sienne, pas un plantage. Reprendre la capture avant de chercher un bug.

## Salat Premium : toute l'app, 0,99 par mois, 3 jours d'essai, paywall dur

**Décision de Sharik du 22/11/2026** (remplace le modèle du 14/11 : app gratuite avec pubs,
Premium à 1,99 qui débloquait le widget et retirait les pubs). Désormais : **plus aucune
pub**, et **l'app entière est derrière Salat Premium**, 0,99 €/mois (4,99 du 23 au 26/11, baissé à
0,99 le 25/11/2026 par Sharik, effectif le 27/11) avec **3 jours d'essai
gratuit** pour les comptes éligibles. Un seul produit, mensuel, auto-renouvelable :
`com.salat.premium.monthly` (`Store.productID`, inchangé : un identifiant ne se réutilise
jamais). StoreKit 2, aucun serveur : l'App Store sait qui a payé, et l'app le lui redemande à
chaque retour au premier plan (`Store.refresh`, plus l'écoute de `Transaction.updates`).

**Le paywall dur.** Dans `ContentView`, une fois l'onboarding refermé, tant que
`!store.isPremium` une surcouche `PaywallView(hard: true)` couvre l'app : **pas de bouton
fermer** (`SheetScaffold(closable: false)`), le contenu dessous est masqué à VoiceOver. Tant
que `store.hasChecked` est faux (premier `refresh` pas encore revenu), c'est un simple fond
`Theme.paper` : un abonné qui réinstalle ne voit jamais un prix clignoter. Un ancien
utilisateur non abonné tombe dessus **au lancement suivant, sans rejouer l'onboarding**
(`hasSeenOnboarding` est déjà vrai). Il n'y a plus aucun « pop » de l'offre ailleurs :
`PremiumShortcut`, `PremiumBadge`, `PaywallReason` et la sollicitation périodique sont
supprimés. Un abonné ouvre la même vue en feuille (fermable) depuis la ligne « Premium est
actif » des *Réglages* : elle mène à la page de gestion de l'App Store.

**L'essai.** `Store.loadTrial()` lit l'offre d'introduction du produit
(`paymentMode == .freeTrial`, sa période en jours) **et** l'éligibilité du compte
(`isEligibleForIntroOffer`) ; `offeredTrialDays` n'est non nul que si les deux disent oui.
Alors le bouton dit « Essayer 3 jours gratuitement » (`premium.subscribe.trial`), une
pastille annonce l'essai (`paywall.trial`) et la phrase légale devient
`premium.legal.trial` (« 3 jours gratuits, puis 0,99 €/mois… »). Sinon : « S'abonner »
et `premium.legal`. Un compte qui a déjà eu l'essai ne se le voit jamais promettre.

**Le prix n'est écrit nulle part dans l'app.** `0,99` vit dans App Store Connect (et dans
`StoreKit/Premium.storekit`, avec l'offre `P3D` gratuite, pour un lancement depuis Xcode) ;
l'écran imprime `Product.displayPrice`, dans la monnaie et avec la taxe du lecteur, glissé
dans les phrases par `%@` (et la durée d'essai par `%d`). Sans produit chargé, le paywall dit
que l'App Store est injoignable et propose de réessayer : il ne vend jamais sans prix affiché.

**Ce qu'Apple exige d'un écran d'abonnement**, et qui est sur le paywall : le prix **et la
période**, la phrase sur le renouvellement automatique (et la fin de l'essai), « Restaurer
mes achats », les liens Conditions d'utilisation (la licence standard d'Apple) et
Confidentialité. En retirer un pour ranger la page, c'est un refus en revue. L'accroche
reprend la réponse de l'onboarding (`premium.pitch.hours`) ; cinq avantages : la prière, le
Coran, la révision, le widget, les rappels.

**Le widget reste réservé aux abonnés.** `Store` écrit la réponse dans la suite partagée
(`Premium.isActive`, clé `premium.active`) et relance les timelines ; un oui ou non **sans
date d'expiration** (une date verrouillerait le widget à la fin de chaque mois payé jusqu'à la
prochaine ouverture de l'app). Sans abonnement le widget dessine `lockedCard` ; le toucher
ouvre l'app, qui montre le paywall de toute façon. `WidgetToolView` n'a plus qu'un bouton,
« Ajouter à l'écran d'accueil » : on n'y arrive qu'abonné.

Rien dans `DrillLog`. La télémétrie ne compte que l'entonnoir (`paywall_view`, `purchase_tap`,
voir l'onboarding), jamais un montant ni un reçu ; pour le reste, aucun évènement d'achat ne part vers
app-metrics, App Store Connect compte les abonnés mieux que nous.

Liens profonds (DEBUG) : `-premium 1|0` force l'abonnement (un simulateur lancé par
`simctl` n'a rien acheté), `-paywallPrice "0,99 €"` imprime un prix faute de produit,
`-paywallTrial N` simule un essai de N jours (`0` = pas d'essai, compte non éligible),
`-openPaywall 1` ouvre la feuille d'un abonné, `-startTab widgetPreview -widgetLocked 1`
dessine le widget verrouillé. Sur un vrai téléphone, la carte de développement des
*Réglages* (DEBUG) garde l'interrupteur « Salat Premium » (`Store.setDebugPremium`).

`PremiumUITests` garde : sans abonnement, le paywall dur porte le prix, l'essai dans le
bouton, Restaurer et les deux liens, **pas** de `sheet.close`, et l'app (`tab.learn`) est
inaccessible ; sans essai, ni pastille ni promesse d'essai ; un abonné voit « Ajouter » sur
la page du widget, la ligne active des réglages, et une feuille qui se referme. Aucun achat
n'y est fait.

### La note : demandée seule, rarement, sur une victoire

`Salat/Services/Nudges.swift`, **réduit à la demande de note** le 22/11/2026 (l'offre ne se
sollicite plus : le paywall dur s'en charge, et les pubs ont disparu). La décision est une
valeur pure (`NudgePlanner`), donc « rare » et « au bon moment » sont tenus par
`NudgeTests`. `AppStore.requestReview` ne se demande que sur une victoire (une étape tout
juste acquise, `stepAcquired()`, ou une manche à trois bonnes réponses sur quatre,
`pause(_:)`), après trois jours d'usage différents et trois étapes ouvertes ; une fois par
version, jamais à moins de deux mois d'écart, et rien dans les 20 h qui suivent une autre
sollicitation. iOS plafonne la carte à trois par an, et elle ne sort jamais sur TestFlight.
`-forceNudge review` (DEBUG) la déclenche peu après le lancement.

### Côté App Store Connect

```bash
set -a; source ~/.config/ios-testflight-cicd/config.env; set +a
ruby scripts/asc_subscription.rb                             # lecture seule : dit ce qui manque
ruby scripts/asc_subscription.rb --apply --start AAAA-MM-JJ  # prix 0,99 daté + essai 3 jours
ruby scripts/asc_subscription.rb --apply --screenshot fastlane/screenshots_raw/paywall.png
```

Le script se relance sans rien dupliquer. Prix de base : 0,99 € en France, le palier
équivalent partout ailleurs, 0,99 $ imposé aux États-Unis ; l'offre d'introduction
`FREE_TRIAL` / `THREE_DAYS` dans chaque pays. **État au 25/11/2026** : l'abonnement est `APPROVED` ; 4,99 € en
vigueur depuis le 23/11, **0,99 € programmé au 27/11** dans les 175 pays (`--start 2026-11-27` :
Apple refuse une date à moins de deux jours), essai de 3 jours posé partout. Une baisse
s'applique aussi aux abonnés en cours. Les fiches en/fr/ar de l'abonnement restent à changer
dans le site (409 `UNMODIFIABLE` en état ACTIVE). Ce qu'il ne fait pas : **soumettre** l'abonnement (il part avec une version, voir
« Ce que la 1.4 a appris »).

Les descriptions de `fastlane/metadata` (en, fr, ar) disent que l'app fonctionne avec Salat
Premium, l'essai de 3 jours pour les comptes éligibles, la phrase de renouvellement, « sans
pub », et gardent les liens Conditions et Confidentialité. La note de revue (`Fastfile`,
`review_contact`) explique l'onboarding, le paywall dur, l'essai et le compte Sandbox.

## Les extraits du Coran dans le widget

Quatrième choix du menu « Ce qu'il montre » (`WidgetScope.quran`) : au lieu des étapes de la
prière, le widget fait défiler **les versets que le lecteur a choisis**, un par minute, dans
l'ordre de sa liste, pour qu'un passage se lise du premier verset au dernier
(`CarouselPlan.verseSlot`, la même horloge que les étapes, rien d'épinglé).

**Le widget n'ouvre jamais le Coran.** Les `quran.*.json` pèsent quinze mégaoctets et vivent
dans l'app seule ; une extension est tuée au-delà de trente. L'app **résout** donc les
passages (`WidgetPassage` : une sourate, un verset de début, un de fin) en versets déjà écrits
(`WidgetVerse` : arabe et traduction du lecteur) et dépose cette petite liste dans la suite
partagée (`QuranExcerpts`, `SalatKit/WidgetExcerpts.swift`). Ce que lit le widget, c'est du
texte, pas des références. `QuranExcerpts.resolve` est pur (le Coran lui est passé en
argument), donc testé sans fixtures : bornes rabotées, sourate inconnue ignorée, un verset
nommé par deux passages n'apparaît qu'une fois.

La traduction est cuite dans la liste : changer de langue relance la résolution
(`AppSettings.resolveWidgetVerses`, hors du fil principal, avec un numéro de génération pour
qu'une résolution lente n'écrase pas une plus récente), et la langue cuite est notée à côté
(`versesLanguage`) pour rattraper au lancement un téléphone qui a changé de langue app fermée.

Un verset est dessiné par la carte qui dessine déjà une étape (`PrayerStep(verse:)`) : le nom
de la sourate et la référence à la place du nom de l'étape, le Coran 3D
(`widget_quran.png`) à la place de la figurine. **Il n'y a pas de phonétique** (voir l'onglet
Coran) : un lecteur dont le widget ouvrait sur la prononciation lit l'arabe, et ce choix
quitte le menu tant que le widget est sur le Coran. Liste vide : le widget retombe sur la
prière, jamais sur une carte vide.

Le choix se fait dans `ExcerptPickerView`, une feuille derrière la ligne « Mes extraits » :
la liste du lecteur, « Ajouter un extrait » (la liste des sourates de l'onglet Coran, puis
deux menus, du verset et au verset), et des suggestions en un tap. **Les suggestions et la
graine sont des références, jamais des titres** : l'app ne nomme aucun passage elle-même, le
texte et les noms viennent tous des fichiers du Coran. La graine (2:255 et les sourates 112 à
114) ne sert qu'à ne pas ouvrir sur le vide la première fois.

Les deux objets 3D que le widget dessine hors posture (`widget_quran.png`,
`widget_lock.png`) sont rangés dans le kit par `python3 tools/pack_widget_art.py`, à partir de
`Design/icons-render` : le widget ne voit pas le catalogue `Icons3D` de l'app.

Liens profonds (DEBUG) : `-widgetScope quran` met le widget sur le Coran pour ce lancement
(avec la graine si la liste est vide), `-openTool widget -openExcerpts 1` ouvre la feuille.

## Tests : ce qu'ils gardent

`SalatTests` est **hébergé par l'app** (`TEST_HOST`), pas une seconde compilation de `SalatKit` —
sinon `@testable import Salat` ne linke pas. `SalatUITests` traverse l'onboarding en tapant
(les huit pages en répondant `onboarding.goal.quran` et `onboarding.hours.4`, en attendant le plan, puis « Plus tard » : le seul chemin qui ne
lève pas l'alerte système), et vérifie qu'il débouche sur le paywall sans Premium, sur
`tab.learn` avec :
c'est la régression qui compte, l'app a déjà été livrée une fois avec un onboarding dont on ne
pouvait pas sortir.

Cette panne mérite d'être retenue : `@Observable` **ne suit que les propriétés stockées**. Un
`var x: Bool { get { UserDefaults… } }` change la valeur sans jamais prévenir SwiftUI, donc la
vue ne se redessine pas. Toute préférence exposée à l'UI se stocke et se persiste dans `didSet`.
Et une `sheet(isPresented: .constant(…))` ne peut rien écrire en retour — elle ne se ferme jamais.

`-resetOnboarding 1` (DEBUG) force l'onboarding (`-welcomePage 0…7` choisit la page — au-delà
de la question, la réponse vaut 4 h si elle manque —, `-welcomeBeat N` fige sa scène sur un
temps, `-welcomeQuestion 0` ouvre l'écran du rappel),
`-startTab practice|settings|widgetPreview` et `-openStep <id>` ouvrent un écran directement,
`-openLanguages 1`, `-openReciters 1` et `-openAbout 1` ouvrent les feuilles des réglages,
`-celebrate 1` (avec `-openStep`) joue la célébration,
`-remindersOn 1` allume le rappel quotidien pour
que son sélecteur d'heure soit visible sans passer par l'alerte système : Sharik pilote depuis son
téléphone et ne peut pas taper dans le simulateur, donc chaque écran doit être atteignable au
lancement.

## Pubs en pause (depuis le 22/11/2026)

Les interstitielles AdMob (26/10 → 22/11/2026) sont **en pause, pas supprimées** : Sharik
veut pouvoir les rallumer si le paywall dur ne rapporte pas. Tout est resté en place —
`Salat/Services/Ads.swift`, `Salat/Info.plist` (`GADApplicationIdentifier`, `SKAdNetworkItems`),
les paquets GoogleMobileAds et UserMessagingPlatform de `project.yml`,
`NSUserTrackingUsageDescription`, les appels `Ads.shared.start()` (`SalatApp`) et
`breakPoint()` (`Nudges.pause`). Seul **`Ads.enabled = false`** coupe tout : ni SDK démarré,
ni formulaire RGPD, ni invite ATT, ni interstitielle. Ne pas supprimer ce code.

**Pour les rallumer** : `Ads.enabled = true`, retirer le paywall dur (`ContentView`), remettre
la publicité et le suivi dans `app_privacy.json`, `age_rating.json` et les étiquettes du site.

`fastlane/metadata/app_privacy.json` ne déclare plus que l'interaction produit (statistiques)
et les données de plantage, non liées, sans suivi ; `age_rating.json` a `advertising: false`.
Restent à faire **dans le site** : les étiquettes de confidentialité de l'App Store et la
question publicité du classement d'âge, la page `sharik-dev/salat-support` (elle décrit
encore les pubs), et l'app dans la console AdMob (compte `pub-3988815743198389`, app
`~5768518688`) avec sa ligne d'`app-ads.txt` dans `sharik-dev/sharik-dev.github.io` — à
retirer une fois la version sans pub en ligne, pas avant (les versions installées en
affichent encore).

## Les métriques (app-metrics, depuis la 1.3)

`Salat/Services/Telemetry.swift` est le client de `~/Documents/tools/app-metrics`, le même
serveur que MeowTube et Last Soldier : tableau de bord sharik.fr/metrics/, page « Stats apps »
de Marvin. Constante d'app `salat`, qui doit figurer dans `APPS` de `/etc/app-metrics.env`
sur le VPS : sans elle, le serveur répond 400 et le client **jette** le lot (pas de rattrapage).

Identifiant d'installation tiré au hasard, aucun IDFA. Ce qui part : sessions, langue affichée,
étape ouverte, statut posé, outil ouvert, réponses et fin de manche, écoute d'un récitateur,
début d'enregistrement. **Jamais** une voix, un mot reconnu ni un texte : les propriétés sont
des identifiants d'étape ou des oui/non. La liste exacte est dans le README d'app-metrics.
Les builds de debug envoient une version suffixée `-debug`. La page de confidentialité décrit
cette liste : un évènement qui transporterait autre chose (texte, mot reconnu) la rendrait fausse.

## La publication : la fiche et le binaire, séparés

`fastlane/` et `scripts/` viennent de `godotGame/kit/template`, réécrits pour lire tous les
identifiants dans **`project.yml`** au lieu d'`export_presets.cfg`. Rien de ce qui identifie
l'app n'y est retapé : une deuxième copie du bundle est ce qui fait publier un jour la fiche
d'une app sous le binaire d'une autre.

```bash
set -a; source ~/.config/ios-testflight-cicd/config.env; set +a   # `set -a` obligatoire
fastlane ios bootstrap            # 1× — App ID + fiche (fait : 6798837070)
ruby scripts/asc_price_free.rb    # 1× — gratuit (fait)
fastlane ios metadata             # textes + captures
scripts/build_ios.sh              # xcodegen → archive → IPA
scripts/upload_testflight.sh      # monte le binaire
fastlane ios release              # déclarations, precheck, soumission
ruby scripts/asc_state.rb         # où en est la soumission
```

**La lane `metadata` échoue la première fois** sur « Error fetching app store review detail —
No data », et c'est normal : `deliver` **lit** la fiche de revue avant de l'écrire, et sur une
app jamais soumise elle n'existe pas. La relancer la crée. Ce n'est pas une erreur de contact.

**Depuis la 1.1, la fiche se publie aussi par App Store Studio** (`~/Documents/Web/appstore-studio`),
qui a écrit les textes et les captures de la 1.1. `fastlane/metadata/` et `fastlane/screenshots/`
en sont la **copie** : les garder alignés sur ce qui est en ligne, sinon un `fastlane ios metadata`
remet l'ancienne fiche. `fastlane/screenshots/` ne contient que les captures **marketing** (vraies
captures dans des iPhone 3D inclinés, titrées par langue, rendues par shotsmith) ;
les captures brutes de l'app, qui en sont la source, vivent dans `fastlane/screenshots_raw/`
— hors de portée de `deliver`, qui enverrait tout ce qu'il trouve.

`TARGETED_DEVICE_FAMILY: "1"` — iPhone seul. L'app est verrouillée en portrait ; déclarer la
famille iPad obligerait à livrer un jeu de captures 2048 × 2732 d'écrans jamais pensés pour
cette taille.

Les déclarations sont dans `fastlane/metadata/` et sont **légales, pas techniques** : 4+,
`DATA_NOT_COLLECTED`, et `content_rights_contains_third_party_content: true` — ce dernier
reste vrai tant qu'un mp3 d'everyayah est dans le binaire. Ne pas le rebasculer pour
« simplifier ».

Le support et la confidentialité sont deux pages GitHub Pages —
`sharik-dev/salat-support`, EN + FR sur la même page. Elles décrivent un réseau limité aux pubs
et aux statistiques anonymes (les pubs ont disparu le 22/11/2026 : à retirer de la page avec
la version qui les retire), et des enregistrements qui ne quittent pas l'appareil : changer ça dans l'app sans
changer la page transforme la page en déclaration fausse.

### Les captures App Store (`Design/screenshots/`, 14/11/2026)

Demande de Sharik : « aussi beau que SelfTransfer ». Dix écrans 6,9" (1290×2796), EN, FR et AR,
composés par **shotsmith** dans la DA « Jardin ». L'ensemble forme **une seule bande continue** :
le vert de l'app, son treillis d'étoiles à huit branches, une guirlande dorée avec des lanternes
qui traverse tous les écrans, les objets 3D de l'app posés là où l'écran en parle. Deux iPhone 3D
sont **à cheval sur deux écrans** (3→4 la ligne récitée, 7→8 la ligne aux mots effacés), avec
une loupe sur l'écran suivant.

```bash
tools/store_shots.sh [nom …]                 # captures brutes produites par l'app → fastlane/screenshots_raw/<langue>/
python3 Design/screenshots/make-design.py    # écrit design.json (EN, FR) et design.ar.json
shotsmith Design/screenshots/design.json    --out fastlane/screenshots --fastlane
shotsmith Design/screenshots/design.ar.json --out fastlane/screenshots --fastlane
```

- Ne modifier que `make-design.py`, jamais les JSON générés.
- **L'arabe a son fichier parce que sa bande est en miroir** : l'App Store arabe range les
  captures de droite à gauche. Sans le miroir, les deux moitiés d'un iPhone à cheval seraient
  montrées dans le mauvais ordre. Pour relire la bande arabe, assembler les images de la
  dixième à la première.
- Les captures brutes viennent de l'**iPhone 17e** (même rapport d'écran que le 6,9", le
  simulateur le moins gourmand), avec `-premium 1` : sans lui, le paywall dur couvre tout.
- La capture du widget dépend de la minute : le widget tourne entre les étapes en cours, et
  le Tashahhud, long, donne un pavé illisible. La reprendre quand il montre « 1 / 3 » (le Sujud).
- L'écran du widget dit **« avec Salat Premium »** dans son sous-titre : Apple exige qu'une
  capture qui montre une fonction payante le dise (règle 2.3.2). Ne pas retirer la mention.
- Aucune marque tierce ni chiffre promotionnel dans les titres. L'écran Coran montre une des
  photos de fond dont les droits ne sont pas réglés (`QURAN_BACKGROUNDS.md`).

### Ce que la 1.4 a appris (14/11/2026)

- **Une nouvelle version s'ouvre avec `fastlane ios metadata version:1.4`** : sans l'option,
  la lane écrit dans la version déjà ouverte et échoue s'il n'y en a pas.
- **L'abonnement existe** : groupe « Salat Premium », `com.salat.premium.monthly`, 1,99 € en
  France, palier équivalent ailleurs, 1,99 $ aux États-Unis (prix de la 1.4 ; 4,99 + essai
  de 3 jours décidés le 22/11/2026, voir « Salat Premium »), capture du paywall envoyée
  (`fastlane/screenshots_raw/paywall.png`). Dans `asc_subscription.rb`, la disponibilité se
  pose **avant** les prix : un prix dans un pays où l'abonnement n'est pas encore disponible
  est refusé (409 `UNSUPPORTED_TERRITORY`).
- **Le premier abonnement d'une app ne se soumet pas par l'API**
  (`FIRST_SUBSCRIPTION_MUST_BE_SUBMITTED_ON_VERSION`) : dans le site, « Add for Review » sur
  l'abonnement, puis sur son groupe, puis sur la version, pour les mettre dans le **même
  brouillon de soumission**, et l'envoi part de ce brouillon. Il n'y a plus de case à cocher
  sur la page de la version. `fastlane ios release submit:false` pose tout le reste sans
  appuyer sur le bouton ; **ne pas lancer `fastlane ios release` tout court** dans ce cas, il
  envoie la version seule (c'est arrivé le 14/11/2026, soumission retirée dans la foulée). Les
  abonnements suivants, eux, passent par `subscriptionSubmissions`.
- La 1.4 (build 7) est partie en examen le 14/11/2026 à 17 h 10 avec l'abonnement et son
  groupe dans la même soumission. `automatic_release` est à faux : la sortie se déclenche à
  la main après l'acceptation.
- Chrome piloté par Claude n'est pas connecté à App Store Connect, et Claude ne saisit pas de
  mot de passe : tout geste « dans le site » revient à Sharik.

### Ce qui reste

Les enregistrements everyayah ne sont **plus** un point ouvert : les sept voix partent
embarquées sans licence écrite, risque assumé, on avise si quelqu'un réclame (décision du
6 août 2026, motivée dans `AUDIO_SOURCES.md`). Ne pas rouvrir le sujet ni retirer de voix.

- Captures d'écran App Store : refaites le 14/11/2026 (voir « Les captures App Store »), pas
  encore envoyées à App Store Connect.
- La confidentialité doit être **publiée** sur ASC : c'est le seul geste que la clé `.p8` ne
  sait pas faire (l'API est celle du site, pas la publique). `fastlane spaceauth -u <apple-id>`
  capture la session, mais réclame mot de passe + code 2FA au terminal — Sharik doit la lancer
  lui-même.
- Relecture du contenu religieux par quelqu'un de qualifié — l'app le dit elle-même dans
  ses réglages, mais ça reste à faire.
