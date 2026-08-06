# D'où viennent les récitations

Les 77 clips de `Salat/Resources/audio/` ne sont **pas** produits ici. Ce sont des
enregistrements de récitateurs nommés, téléchargés par `tools/fetch-recitations.py`
depuis **everyayah.com**, un dépôt public qui republie le Coran découpé ayah par ayah.

C'est la seule dépendance externe de l'app, et c'est du **contenu tiers au sens
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

Sept voix, 77 clips, 6,1 Mo. Deux d'entre elles sont des récitations **d'enseignement**
(Husary Muallim, Sowaid) : c'est la seule distinction que l'app expose, parce que c'est la
seule qui change ce qu'on fait de la voix. Les cinq autres sont là pour que l'oreille ne se
fixe pas sur un seul timbre.

Onze clips par récitateur : les 7 versets de la Fatiha (1:1–1:7) et les 4 d'Al-Ikhlas
(112:1–112:4). Un fichier par **ligne** d'étape, pour que l'audio suive le même
appariement ligne à ligne que l'arabe, la phonétique et la traduction — c'est
`check_line_counts()` qui empêche l'audio de dériver d'un verset quand une traduction
change de découpage.

Les étapes non coraniques (takbir, tasbih du ruku, tashahhud) n'ont **pas** de clip : il
n'existe pas de corpus segmenté équivalent, et une voix d'amateur en guise de modèle
apprendrait mal. L'app le gère : `RecitationPanel` s'affiche sur **toute** étape parlée,
mais là où il n'y a pas de clip il le dit et ne propose que de s'enregistrer, en renvoyant
à la phonétique écrite. C'est le cas de douze étapes sur quatorze — l'absence de récitateur
est le cas normal, pas un asset manquant à réparer.

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

Les sept voix partent dans le binaire **sans** licence écrite, et ce n'est pas un oubli :
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
