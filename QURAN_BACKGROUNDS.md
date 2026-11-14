# D'où viennent les fonds de l'onglet Coran

Les 25 images de `Salat/Resources/backgrounds/` (`quranbg_01.jpg` à `quranbg_25.jpg`, 3,9 Mo)
ne sont **pas** produites ici. Sharik a demandé de vraies images « liées à l'islam », prises sur
**Pinterest** en pilotant Chrome, et non générées (14/11/2026). Elles ont été récupérées par le
service `~/.imagescraper` (skill `/scrapeImages`), puis triées à la main et réduites.

## Ce qui n'est pas réglé : les droits

**Ce sont des images du web ouvert, pas des images libres de droits.** Pinterest ne dit ni qui
les a faites ni sous quelle licence ; le service ne garde que le fichier, pas l'épingle
d'origine, donc l'auteur de chacune est **inconnu**. Plusieurs sont très probablement des
images de banque ou des images générées par IA republiées.

Elles partent dans un binaire App Store qui porte des pubs. C'est du contenu tiers de plus au
sens d'App Store Connect (`content_rights_contains_third_party_content` est déjà `true`), et
un ayant droit qui se reconnaît peut demander un retrait. Le risque est celui des récitations,
en moins documenté : là, on sait au moins d'où vient chaque fichier.

Pour s'en défaire sans toucher au code : remplacer les fichiers par des images à licence claire
(Unsplash, Pexels, Wikimedia Commons, ou des rendus maison). `QuranBackground` prend tout ce
qui s'appelle `quranbg_*.jpg`, et retombe sur des dégradés si le dossier est vide.

## Le tri

Sur 110 images rapportées par neuf recherches, 25 gardées. Écartées : tout ce qui montre une
personne, une silhouette humaine, un animal (oiseaux compris), du texte, ou qui n'a rien à voir
avec le sujet. Deux de plus par prudence : une façade dont le bas ressemblait à une foule, et
un zellige dont certaines étoiles pouvaient se lire à six branches (l'app ne montre que des
étoiles à huit branches).

Chaque image a été ramenée à 1560 px de haut au plus, JPEG qualité 76. À l'écran, elles passent
sous un voile sombre et une légère désaturation (`QuranBackdrop`), pour que l'œil reste sur le
verset et que des images de mains différentes aient la même tenue.

| Fichier | Ce qu'on y voit | Recherche Pinterest | Taille d'origine |
|---|---|---|---|
| `quranbg_01.jpg` | moucharabieh et rayons de lumière | « islamic architecture dark aesthetic wallpaper » | 1120×1991 |
| `quranbg_02.jpg` | voie lactée sur le désert | « desert night sky stars wallpaper iphone » | 941×1672 |
| `quranbg_03.jpg` | arche de lanternes | « ramadan lantern night aesthetic wallpaper » | 1152×2048 |
| `quranbg_04.jpg` | minaret et pleine lune | « mosque dome minaret moon wallpaper » | 1200×2141 |
| `quranbg_05.jpg` | galerie dorée, ombres des claustras | « mosque interior arches lanterns aesthetic » | 1024×1536 |
| `quranbg_06.jpg` | croissant, lanternes sur l'eau | « ramadan lantern night aesthetic wallpaper » | 675×1200 |
| `quranbg_07.jpg` | colonnes et stucs de l'Alhambra | « alhambra islamic arches tiles » | 1200×2133 |
| `quranbg_08.jpg` | silhouette de mosquée, croissant | « mosque dome minaret moon wallpaper » | 673×1200 |
| `quranbg_09.jpg` | lanterne dans une salle bleu nuit | « mosque interior arches lanterns aesthetic » | 1152×2048 |
| `quranbg_10.jpg` | dunes sous les étoiles | « desert night sky stars wallpaper iphone » | 897×1601 |
| `quranbg_11.jpg` | arcades et lanternes au crépuscule | « mosque interior arches lanterns aesthetic » | 1120×2240 |
| `quranbg_12.jpg` | minarets en silhouette, croissant | « mosque dome minaret moon wallpaper » | 768×1408 |
| `quranbg_13.jpg` | salle de prière, lustre et minbar | « mosque interior arches lanterns aesthetic » | 1086×1448 |
| `quranbg_14.jpg` | lanternes et croissant au couchant | « ramadan lantern night aesthetic wallpaper » | 1080×1920 |
| `quranbg_15.jpg` | désert et étoiles, aube | « desert night sky stars wallpaper iphone » | 736×1593 |
| `quranbg_16.jpg` | salle sombre, fenêtres ajourées | « islamic architecture dark aesthetic wallpaper » | 720×1280 |
| `quranbg_17.jpg` | lanterne et mosquée illuminée | « ramadan lantern night aesthetic wallpaper » | 720×948 |
| `quranbg_18.jpg` | minaret et croissant | « mosque dome minaret moon wallpaper » | 1080×1920 |
| `quranbg_19.jpg` | salle hypostyle au soleil rasant | « mosque interior arches lanterns aesthetic » | 1024×1536 |
| `quranbg_20.jpg` | lanterne, tapis de prière, nuit | « ramadan lantern night aesthetic wallpaper » | 940×1672 |
| `quranbg_21.jpg` | fenêtre en arc de l'Alhambra | « alhambra islamic arches tiles » | 1152×2048 |
| `quranbg_22.jpg` | dôme vert et minaret, lune | « mosque dome minaret moon wallpaper » | 1080×1920 |
| `quranbg_23.jpg` | arcs et lanternes suspendues | « mosque interior arches lanterns aesthetic » | 736×1103 |
| `quranbg_24.jpg` | arc, mosquée et lanternes | « ramadan lantern night aesthetic wallpaper » | 1080×1920 |
| `quranbg_25.jpg` | coupoles bleues et reflets | « sheikh zayed mosque night wallpaper » | 1284×2778 |
