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
  de la planète, orientés et à l'échelle du jeu. Les soldats (armures) sont des sprites animés pas
  encore décodés : petits blocs bleus (SFC) / rouges (ennemis). Étiquette avec le nom et le groupe.
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
| MISSx.RES 170 / 172 / 173 / 176 / 177 | carte / groupes / entités (50 o, 16.16) / coordonnées des zones / noms des zones |

Carreau d'un point : `octet & 0x3F`. Le bit 7 (~57 % des points) n'est pas une orientation : l'orientation des
carreaux de transition n'est pas stockée, elle se déduit des matières des 8 cases voisines (auto-raccordement).

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

## À faire

- Soldats : sprites animés à 16 directions (RESTNOBJ 800-883), table des types à trouver.
- Ciel de la planète (SKYn.RES).
