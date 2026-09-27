# Terra Nova map viewer

Visualiseur 3D des cartes de *Terra Nova: Strike Force Centauri* (1996), fait avec Godot 4.7.
Il lit **directement les fichiers de ton installation** (GOG ou Steam) : rien n'est copié ni converti.

Lancement : double-clic sur `Lancer le visualiseur.bat` (Godot est dans `C:\Tools\Godot`).

## Contenu

- Relief complet : carte détaillée 513 × 513 (1 unité entre deux points) au centre,
  entourée de la grille grossière 257 × 257 (4 unités) qui forme l'horizon, de −256 à 768.
- Couleurs du sol tirées des vraies textures de la planète (atlas + palette du fichier RESPLNTn).
- Eau quand une grande zone plate est au niveau le plus bas.
- Objets de la mission en blocs de couleur : bleu = SFC, rouge = ennemis, gris = bâtiments,
  marron = décor, cônes verts = arbres. Étiquette avec le nom et le groupe.
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
| F2 / F3 | étiquettes / zones |

## Formats (rétro-ingénierie)

| Fichier / ressource | Contenu |
|---|---|
| LG Res v2 | en-tête 128 o, répertoire à 0x7C ; entrées id u16, taille 24 bits + flags, taille compressée 24 bits + type |
| MAPx.RES 86 | 513 × 513 × 3 octets : type de sol, altitude s16 (× 0,6875 / 256) |
| MAPx.RES 85 | 257 × 257 × 3 octets, même format, pas de 4, décalage 256 |
| MAPx.RES 80 | nom du fichier planète (`resplntN.res`) |
| MAPx.RES 84 | 30 noms de types de sol (16 o) |
| MAPx.RES 120-149 | végétation fixe (50 o, x et y en 24.8) |
| RESPLNTn 48 | atlas de textures du sol, 512 de large, bandes de 32 px (eau, sable, herbe, roche, neige, transitions...) |
| RESPLNTn 50 | palette : 239 couleurs RGB à partir de l'indice 17 |
| RESPLNTn 51 | noms des matières (water, sand, grass, rock, snow, grass2, road, concrete, cliff, rock2) |
| MISSx.RES 170 / 172 / 173 / 176 / 177 | carte / groupes / entités (50 o, 16.16) / coordonnées des zones / noms des zones |

Type de sol d'un point : `(octet & 0x1F) >> 2` = bande de l'atlas.

## À faire

- Textures du sol plaquées (atlas) au lieu des couleurs moyennes.
- Modèles 3D des objets (ressources 800-886 de RESTNOBJ.RES, format à décoder).
- Forêts générées sur les types de sol « Forest ».
- Ciel de la planète (SKYn.RES).
