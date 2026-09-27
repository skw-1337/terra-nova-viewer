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
- Objets de la mission en blocs de couleur : bleu = SFC, rouge = ennemis, gris = bâtiments,
  marron = décor, cônes verts = arbres, boules vertes = buissons. Étiquette avec le nom et le groupe.
- Forêts générées comme dans le jeu : la carte de végétation 128 × 128 de la map choisit, case par case
  (4 × 4 unités), une des 30 listes de plantes (arbres, buissons, rochers en formes simples).
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
| MISSx.RES 170 / 172 / 173 / 176 / 177 | carte / groupes / entités (50 o, 16.16) / coordonnées des zones / noms des zones |

Carreau d'un point : `octet & 0x3F`. Le bit 7 (~57 % des points) n'est pas une orientation : l'orientation des
carreaux de transition n'est pas stockée, elle se déduit des matières des 8 cases voisines (auto-raccordement).

## À faire

- Modèles 3D des objets (ressources 800-886 de RESTNOBJ.RES, format à décoder).
- Vrais modèles des arbres et rochers (mêmes ressources que les objets).
- Ciel de la planète (SKYn.RES).
