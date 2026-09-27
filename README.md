# Terra Nova map viewer

Visualiseur 3D des cartes de *Terra Nova: Strike Force Centauri* (1996), fait avec Godot 4.7.
Il lit **directement les fichiers de ton installation** (GOG ou Steam) : rien n'est copié ni converti.

Lancement : double-clic sur `Lancer le visualiseur.bat` (Godot est dans `C:\Tools\Godot`).

## Contenu

- Relief complet : carte détaillée 513 × 513 (1 unité entre deux points) au centre,
  entourée de la grille grossière 257 × 257 (4 unités) qui forme l'horizon, de −256 à 768.
- Vraies textures du sol (carreaux 64 × 64 du fichier planète RESPLNTn), une par case de terrain,
  avec les transitions orientées comme le fait le moteur (d'après les cases voisines).
- Eau quand une grande zone plate est au niveau le plus bas.
- Vrais modèles 3D des objets (véhicules, vaisseaux, bâtiments, décor), texturés avec la palette
  de la planète, orientés et à l'échelle du jeu. Étiquette avec le nom et le groupe.
- Soldats en armure dessinés comme dans le jeu : un squelette dont chaque membre est une image
  étirée entre deux articulations, vue choisie selon l'angle de la caméra. Pose debout réelle du
  jeu (relevée en mémoire, arme en main), adaptée aux longueurs d'os de chaque armure ; les poses
  relevées pour une armure précise (`data/soldier_poses.json`, écrit par `_MODS/re/poses.bat`
  pendant une mission) sont prioritaires. Le bipède mécanique est fait de petits modèles 3D.
- Ciel de chaque mission (SKY0 bleu, SKY0S orage, SKY1 vert, SKY2 orange, SKY3 / SKY4 espace) : plafond de nuages du jeu fondu dans la couleur de brume (aussi celle du brouillard), nuages, soleil et planètes placés à leur azimut / hauteur, lumière venant du soleil ; étoiles générées sur les mondes sans air.
- Fumées (bâtiments type 61) : colonne de fumée animée du jeu (animation translucide RESTNOBJ 1186).
- Arbres, buissons et rochers : les vrais sprites du jeu, à la taille que leur donne le moteur.
- Galerie (dernière entrée de la liste) : les 119 modèles 3D distincts, avec leur nom de fichier
  et les types d'objets qui les utilisent.
- Forêts générées comme dans le jeu : la carte de végétation 128 × 128 de la map choisit, case par case
  (4 × 4 unités), une des 30 listes de plantes.
- Zones nommées du script (points de largage, déclencheurs, « mystery pt »...) en poteaux jaunes.
- 61 entrées : 37 missions de campagne, entraînement, missions coupées 40-41 (sur le terrain
  plat du générateur, leurs cartes n'existent plus), 16 modèles du générateur, 4 missions des démos.

## Commandes

| Touche | Action |
|---|---|
| Clic droit maintenu + souris | regarder |
| ZQSD (AZERTY) / WASD (QWERTY) | se déplacer (touches physiques) |
| Espace / Ctrl | monter / descendre |
| Maj | ×4 |
| Molette | vitesse |
| Tab | panneau des missions |
| F2 / F3 / F4 | étiquettes / zones / végétation |

## Formats (rétro-ingénierie)

| Fichier / ressource | Contenu |
|---|---|
| LG Res v2 | en-tête 128 o, répertoire à 0x7C ; entrées id u16, taille 24 bits + flags, taille compressée 24 bits + type |
| MAPx.RES 86 | 513 × 513 × 3 octets : type de sol, altitude s16 (× 0,6875 / 256) |
| MAPx.RES 85 | 257 × 257 × 3 octets, même format, pas de 4, décalage 256 |
| MAPx.RES 80 | nom du fichier planète (`resplntN.res`) |
| MAPx.RES 84 | 30 noms de types de sol (16 o) |
| MAPx.RES 83 | carte de végétation 128 × 128 octets, rangée colonne par colonne (index = x × 128 + y), cases de 4 × 4 unités ; valeur v > 0 → liste 119 + v |
| MAPx.RES 120-149 | 30 listes de végétation (entrées de 50 o : classe, sous-type, décalages X/Y en 16.16 de 0 à 4 dans la case) |
| RESPLNTn 48 | carreaux de sol 64 × 64 rangés à la suite (4096 o chacun ; 64 carreaux, 53 et 59 pour les planètes 2 et 3) |
| RESPLNTn 43 | carreau → matière (64 entrées) |
| RESPLNTn 47 | matière → premier carreau, nombre de variantes |
| RESPLNTn 46 | table des transitions : index = matièreA × 50 + matièreB × 5 + forme → carreau |
| RESPLNTn 49 | les 64 carreaux en 16 × 16 (version basse résolution) |
| RESPLNTn 50 | palette : 239 couleurs RGB à partir de l'indice 17 |
| RESPLNTn 51 | noms des matières (water, sand, grass, rock, snow, grass2, road, concrete, cliff, rock2) |
| RESTNOBJ 1343-1362 | modèles 3D, plusieurs par ressource (voir plus bas) |
| RESTNOBJ 1160-1163 | sprites des arbres, buissons, rochers (bitmaps LG, type 2 brut ou 4 compressé RSD) |
| RESTNOBJ 1196-1342 | textures des modèles |
| RESTNOBJ 1371 / 1372 / 1373 / 1374 | type d'objet → modèle ou sprite pour les classes 0 (décor), 2 (véhicules), 3 (vaisseaux), 4 (bâtiments) : réf. = u16 image, u16 ressource ; décor et bâtiments ont 2 réf. par type (intact, détruit) |
| RESTNOBJ 1364 + classe | propriétés par type : forme de collision (u16 genre, u16 index de l'entrée rayon / hauteur, entrées de 8 o) |
| RESMAP.RES 1440 | n° de texture global → réf. (ressource, image) |
| RESGAME / casques | couleurs 0-16 de la palette (fixes) ; la planète fournit 17-255 |
| MISSx.RES 178 | nom du fichier ciel (16 o) puis paramètres non décodés |
| SKYn.RES 152 | images : 0 = texture de nuages 256 × 256 (absente sur SKY3 / SKY4), puis nuages, soleil, lunes, planètes |
| SKYn.RES 153 | disposition : u16 nombre, u8 couleur de base ; après la texture et l'emplacement de la lune, éléments de 12 o : u16 azimut, u16 hauteur (1/65536 de tour), réf. (image, 152), 4 o |
| SKYn.RES 150 / 151 | tables de brume (16 × 256 / 8 × 256 couleurs) ; niveau 15 de 150 = couleur entièrement brumeuse |
| SKYn.RES 154 (SKY3 / SKY4) | champ d'étoiles (table de décalages + données, non décodé) |
| MISSx.RES 170 / 172 / 173 / 176 / 177 | carte / groupes / entités (50 o : classe, type, … x, y, z en 16.16 à 8 / 12 / 16, cap u16 à 20 ; z = hauteur au-dessus du sol, 0 partout sauf le pont de Nid d'aigle) / coordonnées des zones / noms des zones |

Carreau d'un point : `octet & 0x3F`. Le bit 7 (~57 % des points) n'est pas une orientation (le bit 6 n'est
jamais à 1) : l'orientation n'est pas stockée, elle se déduit des matières des 8 cases voisines
(auto-raccordement). Ça vaut pour les carreaux de transition de la table 46, et aussi pour les carreaux
« à un seul côté » d'une matière (bord de route en triangle, bordure rayée des dalles, coins) : leur partie
de la matière (repérée avec le carreau le plus uni de cette matière) regarde les cases de la même matière.
Le visualiseur fait une première estimation d'après les matières voisines, puis recommence avec
l'orientation déjà choisie des voisins jusqu'à stabilité (une route diagonale faite uniquement de carreaux de
transition se règle de proche en proche), puis polit les transitions par continuité des couleurs de bord.
Résultat mis en cache par carte (`user://tilemaps`), premier chargement de 1 à 7 s.

### Modèles 3D

Un modèle est un programme pour l'interpréteur 3D de Looking Glass (même famille que System Shock),
lu dans l'exe du jeu (table des opcodes en 0x36069c de `__FF.EXE`). En-tête : nom (8 o), boîte
englobante et rayon en 16.16, nombre de polygones (0x40), de points (0x42), de paramètres (0x44),
de points chauds (0x47, 16 o chacun à 0x5e), de textures (0x49, 10 o chacun ensuite : octet 1 = n°
local, u16 à 2 = n° global), taille (0x4a), début du code (0x4e).
Repère du modèle : y vers le bas (les objets posent sur y = 0 et montent en négatif), z vers l'avant.
Opcodes utiles : 03 / 15 / 16 / 21 définissent des points, 0a-0f des points relatifs (décalage sur 1 ou
2 axes), 06 = nœud BSP (deux sous-programmes), 10-12 = pièce articulée (tourelle, canon), 28 / 29 =
pièce avec sa matrice, 14 = sous-programme, 33 = polygone avec sa normale (sous-opcode 0 plat, 1 fil
de fer, 2 texturé avec u, v en 16.16), 04 = polygone plat, 26 = polygone texturé, 24 / 25 / 1d =
coordonnées de texture, 05 = couleur. Couleur de polygone plat : bit 0x8000 = indice de palette, sinon
couleur donnée à l'exécution (voyant d'alarme).
Sprites : le moteur leur donne une largeur de 2 × le rayon de collision du type, la hauteur suit les
proportions de l'image.

### Soldats

Type de soldat → n° d'armure : octet à 0x395CA5 + 70 × type dans `__FF.EXE` (SFC léger / standard /
lourd 0-2, Hog 3, Hog éclaireur 4, Hog lourd 5, clones 6-8, pirate 9, capitaine 10, bipède 11).
Armure s → RESTNOBJ 800 + 7 s + pièce (0 pied, 1 tibia, 2 cuisse, 3 bras, 4 avant-bras, 5 torse,
6 autre avant-bras). Une pièce : u8 nombre de vues (16 tout autour, 9 de dos à face pour le torse),
longueur en pixels entre les deux articulations (u32 à 9), décalages des vues (u32 à 13) ; chaque vue
est un bitmap LG dont les octets 16-19 donnent la position des deux articulations dans l'image.
Squelettes : 884 (la plupart), 885 (clones, pirates : 7e pièce), 886 (bipède, pièces = modèles 3D
877-883) ; octet 1 = nombre de segments, segments de 16 o à partir de 0x14 : articulation a, b, chaîne,
drapeaux, u16 pièce. 16 articulations : 0/1 orteils, 2/3 chevilles, 4/5 genoux, 6/7 hanches, 8 bassin,
9 cou, 10/11 épaules, 12/13 coudes, 14/15 mains. Longueur d'une pièce : u16 à 9 (l'octet 12 est un
drapeau). Longueur d'os en jeu = pixels / 256 × taille propre du soldat (tirée au hasard, ~±12 %).
Pas de pose stockée : le jeu calcule la marche à l'affichage (0x280934) et range les 16 articulations
(x, y, z en 16.16, z vers le haut) à +0x1AF de la fiche soldat (0x3A56B8 + 0x582 × n, n = mot à +3 de
l'entrée de la table maîtresse ; n° d'armure à +0xDE).

Bitmaps de type 5 (translucides) : non compressés, 248 / 249 = fumée claire / dense passée par les
tables de transparence du jeu.

## À faire

- Soldats : animation de marche ; pieds posés sur les pentes. Tourelles orientables.
- Ciel : position de la lune et paramètres de mission (178), champ d'étoiles 154.
