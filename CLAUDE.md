# Salat — apprendre la prière

App iOS (SwiftUI, iOS 17+) qui enseigne **ce qu'il faut dire pendant la salat** : le texte arabe,
sa prononciation écrite dans la langue du lecteur, et sa traduction. Trois temps : on lit (onglet
*Learn*, 14 étapes détaillées), on se fait interroger (onglet *Memorise*, exercices + travail de
la voix), et ça revient tout seul entre deux (**widget** qui fait défiler les positions).

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

## Illustrations

Générées par NanoBanana (`/generateImage`), puis détourées et recadrées par
`tools/cutout.py` (fond → alpha, crop sur la figure, sortie 512×512).

Contrainte non négociable, rappelée dans le prompt : **aucun trait de visage** (pas d'yeux, pas
de bouche, pas de nez), silhouette pleine d'un jeune homme en thobe. Toute régénération doit
repartir du prompt de `tools/generate-positions.py`.

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

**L'icône d'app est dessinée, pas assemblée.** `tools/make-appicon.py` la fabriquait en
polygones — étoile sable, socle doré extrudé, silhouette de sujud posée dessus : trois idées
empilées dans un carré qui se regarde à 20 mm. Le fichier ne porte plus que le prompt
NanoBanana qui l'a remplacée (une étoile khatam en or, la prosternation dedans, rien d'autre),
et un `--install` qui efface l'étincelle du générateur et force 1024×1024 **sans alpha** — iOS
refuse une icône transparente. Même contrainte de pudeur que les positions, et l'étoile est à
**huit** branches : à écrire « star » tout court, le modèle rend un hexagramme.

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

Le bouton de vitesse n'est **pas** en police pixel : `04b30` n'a pas de « × » et le glyphe sortait
en bloc vide à côté du chiffre.

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
jusqu'à 0,45). L'illustration est retombée à une pastille de 30–40 pt : elle situe la posture d'un
coup d'œil, elle n'est pas le contenu. Une étape muette (le niyyah) affiche son geste à la place.

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
`\.widgetRenderingMode` : en `fullColor` la DA normale (plaques, sable, or), sinon tout est
redessiné en clair, l'illustration passée en `.template` (le PNG porte la figure dans son alpha)
et le `containerBackground` laissé vide. La règle : **rien ne doit dépendre d'une couleur sombre
sur un fond clair pour être visible**. Le simulateur, lui, est en clair — cette panne ne s'y voit
pas, elle se vérifie par `-startTab widgetPreview`, qui affiche les deux rendus l'un sous l'autre.

Le widget est archivé ici puis **dessiné par un autre processus**, qui ne résout que les polices
déclarées par le bundle : la police pixel est donc listée dans `UIAppFonts`
(`SalatWidget/Info.plist`) en plus de l'enregistrement CoreText de `Theme.registerPixelFont()`.
Sans ça le compteur sort vide (même panne que sur 5min).

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
`-openStep <id>` ouvrent un écran directement, `-openLanguages 1` ouvre la liste des langues,
`-remindersOn 1` allume le rappel quotidien pour
que son sélecteur d'heure soit visible sans passer par l'alerte système : Sharik pilote depuis son
téléphone et ne peut pas taper dans le simulateur, donc chaque écran doit être atteignable au
lancement.

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

`TARGETED_DEVICE_FAMILY: "1"` — iPhone seul. L'app est verrouillée en portrait ; déclarer la
famille iPad obligerait à livrer un jeu de captures 2048 × 2732 d'écrans jamais pensés pour
cette taille.

Les déclarations sont dans `fastlane/metadata/` et sont **légales, pas techniques** : 4+,
`DATA_NOT_COLLECTED`, et `content_rights_contains_third_party_content: true` — ce dernier
reste vrai tant qu'un mp3 d'everyayah est dans le binaire. Ne pas le rebasculer pour
« simplifier ».

Le support et la confidentialité sont deux pages GitHub Pages —
`sharik-dev/salat-support`, EN + FR sur la même page. Elles décrivent l'absence de requête
réseau et des enregistrements qui ne quittent pas l'appareil : changer ça dans l'app sans
changer la page transforme la page en déclaration fausse.

### Ce qui reste

Les enregistrements everyayah ne sont **plus** un point ouvert : les sept voix partent
embarquées sans licence écrite, risque assumé, on avise si quelqu'un réclame (décision du
6 août 2026, motivée dans `AUDIO_SOURCES.md`). Ne pas rouvrir le sujet ni retirer de voix.

- Captures d'écran App Store (aucune envoyée) — obligatoire pour soumettre.
- La confidentialité doit être **publiée** sur ASC : c'est le seul geste que la clé `.p8` ne
  sait pas faire (l'API est celle du site, pas la publique). `fastlane spaceauth -u <apple-id>`
  capture la session, mais réclame mot de passe + code 2FA au terminal — Sharik doit la lancer
  lui-même.
- Relecture du contenu religieux par quelqu'un de qualifié — l'app le dit elle-même dans
  ses réglages, mais ça reste à faire.
