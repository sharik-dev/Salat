# D'où viennent les récitations

Les 33 clips de `Salat/Resources/audio/` ne sont **pas** produits ici. Ce sont des
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

Onze clips par récitateur : les 7 versets de la Fatiha (1:1–1:7) et les 4 d'Al-Ikhlas
(112:1–112:4). Un fichier par **ligne** d'étape, pour que l'audio suive le même
appariement ligne à ligne que l'arabe, la phonétique et la traduction — c'est
`check_line_counts()` qui empêche l'audio de dériver d'un verset quand une traduction
change de découpage.

Les étapes non coraniques (takbir, tasbih du ruku, tashahhud) n'ont **pas** de clip : il
n'existe pas de corpus segmenté équivalent, et une voix d'amateur en guise de modèle
apprendrait mal. L'app le gère — `RecitationPanel` ne s'affiche que là où un clip existe.

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

Aucune autorisation écrite n'a été obtenue à ce jour. Si Apple demande une preuve de
droits pendant l'examen (c'est le motif d'aller-retour attendu sur cette version), les
deux issues sont : obtenir l'accord des ayants droit, ou retirer les mp3 et ne garder que
l'enregistrement de sa propre voix.

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
compilé dans le widget aussi, et le widget ne joue aucun son — 3,6 Mo y seraient
embarqués deux fois.
