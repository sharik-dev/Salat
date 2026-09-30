# D'où viennent les récitations

Les 115 clips de `Salat/Resources/audio/` ne sont **pas** produits ici. Ce sont des
enregistrements téléchargés par `tools/fetch-recitations.py` depuis **everyayah.com**
(le Coran, découpé ayah par ayah) et **hisnmuslim.com** (les adhkar de la prière, un mp3
par dhikr, découpés localement — voir plus bas).

Ce sont les seules dépendances externes de l'app, et c'est du **contenu tiers au sens
d'App Store Connect** — `content_rights_contains_third_party_content` vaut donc `true`
dans la lane `release`. Ne pas le rebasculer à `false` en croyant simplifier : c'est une
déclaration légale, et elle est fausse tant qu'un mp3 de ce dossier est dans le binaire.

## Ce qui est embarqué

| Récitateur | Style | Dossier everyayah | Clips |
|---|---|---|---|
| Mahmoud Khalil Al-Husary (1917–1980) | *muallim* — lent, ayah par ayah, fait pour être répété | `Husary_Muallim_128kbps` | 11 |
| Mahmoud Khalil Al-Husary | *murattal* | `Husary_128kbps` | 11 |
| Mishary Rashid Alafasy (né en 1976) | *murattal* | `Alafasy_128kbps` | 11 |
| Ayman Sowaid (né en 1955) | *muallim* — professeur de tajwid, articulé lettre à lettre | `Ayman_Sowaid_64kbps` | 11 |
| Muhammad Siddiq Al-Minshawi (1920–1969) | *murattal* | `Minshawy_Murattal_128kbps` | 11 |
| Abdul Basit Abdus-Samad (1927–1988) | *murattal* | `Abdul_Basit_Murattal_64kbps` | 11 |
| Abu Bakr Ash-Shatri (né en 1970) | *murattal* | `Abu_Bakr_Ash-Shaatree_64kbps` | 11 |
| Abdurrahman As-Sudais (né en 1960) | *murattal* | `Abdurrahmaan_As-Sudais_192kbps` | 11 |
| Saud Ash-Shuraym (né en 1964) | *murattal* | `Saood_ash-Shuraym_128kbps` | 11 |

Dix voix (neuf coraniques + Hisn al-Muslim), 115 clips, 9,2 Mo. Deux d'entre elles sont des récitations **d'enseignement**
(Husary Muallim, Sowaid) : c'est la seule distinction que l'app expose, parce que c'est la
seule qui change ce qu'on fait de la voix. Les autres sont là pour que l'oreille ne se
fixe pas sur un seul timbre.

## Les timings mot à mot : la seule pièce réellement libre

Le curseur karaoké (le mot doré qui suit la voix) vient de **quran-align** (Collin Fair,
**CC BY 4.0** — une vraie licence, posée par l'auteur des données) : des timestamps mot à
mot mesurés sur les enregistrements d'everyayah eux-mêmes. Huit voix sur neuf sont
couvertes ; Sowaid ne l'est pas, et son curseur reste simplement éteint.

Deux fichiers d'alignement visent un autre débit que celui qu'on embarque (Husary 64 vs
128 kbps, Shatri 128 vs 64) : mêmes masters, écarts mesurés sous 80 ms, moins d'un mot.
Le fichier As-Sudais du paquet 2016 commence par une ligne de log parasite avant le JSON ;
le script la saute.

**L'attribution CC BY est payée dans l'app** : `settings.audio.timing`, sous les crédits
des récitateurs, dans les quatorze langues. `tools/fetch-recitations.py` valide à chaque
run que chaque ayah alignée a exactement le compte de mots de notre texte arabe — un
curseur qui dériverait d'un mot mentirait sous un texte sacré, silencieusement — et
`RecitationTests.testWordTimingsPairWithArabicWordsWhereTheyExist` le revérifie côté app.

Onze clips par récitateur : les 7 versets de la Fatiha (1:1–1:7) et les 4 d'Al-Ikhlas
(112:1–112:4). Un fichier par **ligne** d'étape, pour que l'audio suive le même
appariement ligne à ligne que l'arabe, la phonétique et la traduction — c'est
`check_line_counts()` qui empêche l'audio de dériver d'un verset quand une traduction
change de découpage.

## Les adhkar : la voix Hisn al-Muslim

Les formules non coraniques ont désormais leur voix : **hisnmuslim.com**, le site officiel
du livre *Hisn al-Muslim* (Sa'id al-Qahtani), publie un mp3 par dhikr. Sept étapes en sont
tirées : istiftah, ruku, itidal (2 lignes), sujud (+ sujud2, même clip), jalsa, tashahhud
(4 lignes), salawat (2 lignes). Le récitateur n'est pas nommé sur le site (l'app officielle
du livre crédite Hamad al-Duraihem, sans certitude que ce soit la même voix) : l'app crédite
donc la source, « Hisn al-Muslim », sans inventer un nom. Même statut juridique que les
récitations coraniques : diffusion libre de fait, pas de licence écrite — couvert par la
même décision du 6 août 2026.

Les enregistrements bruts portent un **titre parlé** et parfois une annotation (« ثلاث
مرات ») : chaque clip est **découpé** à la fenêtre exacte de la formule. Les fenêtres et les
timings mot à mot sont mesurés (whisper.cpp small + DTW, coupes calées sur les silences) et
versionnés dans `tools/adhkar_cuts.json` ; chaque clip coupé a été retranscrit et vérifié
contre le texte attendu, mot pour mot. La formulation de hisnmuslim colle à la nôtre partout
(tashahhud d'Ibn Mas'ud compris).

Le **taawwudh** vient des récitateurs coraniques eux-mêmes : quatre dossiers everyayah
(husary, alafasy, shatri, shuraym) publient un `audhubillah.mp3`, aligné de la même façon.

Seuls **takbir** (اللَّهُ أَكْبَرُ) et **taslim** restent sans voix — aucun corpus propre ne
les couvre, et une voix d'amateur en guise de modèle apprendrait mal. `ReciterPanel` traite
cette absence comme le cas normal ; ne pas la « réparer » avec une TTS.

## Ce qui est vérifié, et ce qui ne l'est pas

**Vérifié.** Le *texte* coranique est du domaine public : il n'a pas d'auteur au sens du
droit d'auteur, et aucune juridiction ne lui reconnaît de titulaire.

**Non vérifié — et c'est le point ouvert.** Un enregistrement est une *interprétation*, et
une interprétation porte des droits voisins distincts du texte qu'elle récite.
everyayah.com diffuse ces fichiers librement et sans mention de licence, ce qui n'est pas
la même chose qu'une autorisation de redistribution dans une app publiée. Concrètement :

- Al-Husary est mort en 1980. Selon le pays, les droits voisins sur ses enregistrements
  des années 1960 sont éteints ou courent encore (70 ans après publication dans l'UE).
- Alafasy est vivant et actif. Ses récitations circulent très largement dans des apps
  gratuites, ce qui suggère une tolérance — **pas** une licence écrite.

**Une récitation professionnelle sous licence libre, ça n'existe pas — vérifié en août 2026.**
everyayah ne publie aucune mention de licence, ni sur son accueil ni sur sa page des
récitateurs ; quranicaudio non plus. Les jeux de données Hugging Face et Kaggle qui affichent
« CC BY » republient ces mêmes fichiers : la licence y est posée par celui qui a téléversé, pas
par l'ayant droit, donc elle ne vaut rien. Wikimedia Commons héberge des récitations sous
CC BY-SA, mais ce sont des sourates entières, non découpées, par des amateurs, et certains
fichiers sont manifestement des reversements d'enregistrements commerciaux. Ce qui est
réellement libre, c'est le **texte** (Tanzil, CC BY 3.0), jamais l'interprétation. Chercher une
septième fois une source « open source » est du temps perdu : le choix réel est entre demander
une autorisation écrite, ne garder que les enregistrements dont les droits voisins sont éteints,
ou sortir les mp3 du binaire.

Aucune autorisation écrite n'a été obtenue à ce jour.

## Le risque est assumé — décision de Sharik, 6 août 2026

Les voix partent dans le binaire **sans** licence écrite (les neuf coraniques comme celle
des adhkar), et ce n'est pas un oubli :
c'est un arbitrage pris en connaissance de cause, une fois établi qu'aucune récitation
professionnelle segmentée n'est disponible autrement. Ça ne bloque pas la publication, et
**ce n'est pas une tâche ouverte** : ne pas remettre le sujet sur la table, ne pas retirer
de voix « par prudence », ne pas proposer une TTS de remplacement.

Si Apple ou un ayant droit réclame quelque chose, on avise **à ce moment-là**, et les deux
issues restent celles décrites plus haut : obtenir l'accord, ou retirer les mp3 et ne garder
que l'enregistrement de sa propre voix. Ce qui reste vrai entre-temps : les récitateurs sont
cités dans l'app, et `content_rights_contains_third_party_content` vaut `true`.

## L'attribution est une dette, pas une option

Les récitateurs sont cités **dans l'app publiée** — `SettingsView`, section crédits — et
pas seulement dans ce fichier. Un nom qui ne vit que dans un `.md` du dépôt n'attribue
rien à personne.

## Refaire les clips

```bash
python3 tools/fetch-recitations.py          # complète ce qui manque
python3 tools/fetch-recitations.py --force  # retélécharge tout
```

Le script réécrit `Salat/Resources/recitations.json`, le manifeste que lit
`Recitations.swift`. Les mp3 vivent sous `Salat/` et non `SalatKit/` : SalatKit est
compilé dans le widget aussi, et le widget ne joue aucun son — 6,1 Mo y seraient
embarqués deux fois.

## La voix de l'utilisateur ne sort pas du téléphone

`Documents/recordings/<étape>_<ligne>.m4a` (AAC mono 44,1 kHz), dans le conteneur de
l'app — **pas** dans l'App Group `group.com.salat`. Une voix qui prie n'a rien à faire
dans un conteneur partagé avec un widget qui n'en a aucun usage. Rien n'est envoyé sur le
réseau, et Réglages → Récitation efface tout d'un coup.
