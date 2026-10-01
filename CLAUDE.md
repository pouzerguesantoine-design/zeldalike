# CLAUDE.md — zeldalike

Action-RPG 3D façon Zelda (BotW / Link's Awakening), style low-poly coloré, clavier + souris
(AZERTY et QWERTY). Godot **4.7.2** (Forward+), GDScript typé. Dépôt :
`pouzerguesantoine-design/zeldalike`, branche `main`.

Ce fichier est la référence pour toutes les sessions : le mettre à jour à la fin de chaque jalon.

## Outils et commandes

Godot (installé par winget, raccourcis Bureau + menu Démarrer) :
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
(ci-dessous `$G`).

```bash
"$G" --headless --path . --import                            # (ré)importer après ajout de fichiers
"$G" --headless --path . --quit-after 300                    # lancer le jeu (l'île) sans fenêtre : aucune erreur attendue
"$G" --headless --path . res://tools/godot/bake_navmesh.tscn # recuire la navigation de l'île après un changement de décor
"$G" --path . --resolution 1280x720 res://tools/godot/capture_screenshots.tscn -- docs/screenshots/ prefixe_ [qualité 0-2]  # captures (même cadrage, Haut par défaut)
"$G" --headless --path . -s res://tools/godot/compare_screenshots.gd  # avant_* + apres_* → comparaison_*.png
python tools/audio/generate_sounds.py                        # régénérer les sons (assets/audio/)
"$G" --headless --path . res://tests/test_jalon2.tscn        # tests auto d'un jalon (code de sortie 0 = OK)
"$G" --path . res://tests/test_jalon2.tscn -- capture.png    # idem + capture d'écran du rendu
```

- **Relancer les tests de TOUS les jalons** à chaque jalon (non-régression).
- Chaque test hérite de `tests/test_case.gd` (`extends "res://tests/test_case.gd"`, redéfinir `run()`) :
  `check()`, `frames()`, `load_main()`, `teleport()`, `send_action()`, `save_screenshot_if_requested()`,
  garde-fou de 90 s. Scène `.tscn` d'une ligne à côté du script.

- **Fermer l'éditeur Godot** avant de modifier des fichiers de l'extérieur (sinon il peut les réécraser).
- Les tests sont des **scènes** (`tests/*.tscn`) et non des scripts `-s` : en mode `-s`, les autoloads
  (`EventBus`, `GameState`) ne sont pas déclarés et les scripts qui les utilisent ne compilent pas.
- `--check-only` signale à tort `EventBus` introuvable pour la même raison : s'y fier seulement pour la syntaxe.
- `load_main()` retire les ennemis du niveau (tests déterministes) ; `load_main(true)` les garde.
- Les tests n'écrivent **jamais** dans la vraie sauvegarde : chemins `user://test_save_jX.json`
  (et `GameState.save_path` remplacé puis rétabli dans le test du jalon 7).
- `save_screenshot_if_requested("suffixe")` : plusieurs captures dans un même test.
- Écrire les gros fichiers générés (scènes, .tres) avec un script Python dans le dossier scratchpad :
  les heredocs Bash contenant des apostrophes échouent dans cet environnement.

## Workflow par jalon

1. Implémenter le jalon. 2. Lancer en headless + tests (zéro erreur/avertissement). 3. Capture d'écran.
4. Mettre à jour ce fichier. 5. Commit `Jalon X : …` + push (jamais de `--force`).
6. Résumé à l'utilisateur, puis **attendre « continue »**. Ne jamais supprimer de travail sans le dire.

## Arborescence

```
assets/models/        .glb exportés depuis Blender (réglages d'import dans les .glb.import)
assets/blender/       .blend sources (dossier ignoré par Godot : .gdignore)
assets/textures/ (icons/ : icônes SVG)  assets/audio/
scene/player/  scene/enemies/  scene/world/  scene/ui/  scene/components/
scene/items/ (weapons/ : modèles d'armes)  scene/projectiles/
scripts/player/ (+ states/)  scripts/enemies/ (+ states/)  scripts/components/  scripts/items/
scripts/ui/  scripts/autoload/  scripts/world/ (scripts de niveau)
resources/weapons/  resources/spells/  resources/items/  resources/loot_tables/  resources/stats/
resources/animation/  AnimationTree du joueur (généré par tools/godot/)
tests/                scènes de test automatiques (exclues de l'export)
build/                exports (ignoré par git) ; export_presets.cfg : preset « Windows Desktop »
tools/blender/        scripts Python qui construisent les modèles dans Blender (ignoré par Godot)
tools/godot/          scripts Godot de génération (AnimationTree, cuisson de la navigation)
tools/level/          générateur initial de l'île (écrase island.tscn : à ne plus relancer)
tools/audio/          générateur des sons (synthèse, CC0)
assets/audio/         sons .wav générés ; resources/audio/ : bibliothèque de sons
resources/balance/    réglages de jeu (PlayerTuning)
scene/fx/             effets de particules (FxBurst)
assets/shaders/       shaders : toon, toon_foliage, outline_post, water, grass (jalon 8.5)
docs/screenshots/     captures du README (ignoré par Godot)
```

Les dossiers encore vides contiennent un `.gitkeep`.

## Conventions

- GDScript **typé statiquement** (`var hp: int`, `func f() -> void`), `@export` pour tout réglage.
- Code, commentaires et texte d'interface **en français** ; noms d'identifiants en anglais.
- **Composition** : comportements = nœuds enfants réutilisables (composants), pas d'héritage profond.
  Seule exception : les états héritent de `State` (et `PlayerState` pour le joueur).
- **Données dans des Resources `.tres`** : stats, armes, objets, tables de loot jamais codés en dur.
- **Signaux** pour communiquer ; événements globaux via l'autoload `EventBus`.
- Composants : un script `class_name` dans `scripts/components/`, posé sur un nœud de la scène
  propriétaire (Health, Stamina, Mana : `Node` ; Hitbox, Hurtbox : `Area3D` avec sa propre
  CollisionShape3D, dont la forme dépend du propriétaire). Une scène dans `scene/components/` seulement
  si le composant a des sous-nœuds fixes.
- Nœuds qui lisent les `@onready` de leur parent dans `_ready()` : `await parent.ready` si besoin
  (les enfants sont prêts **avant** le parent).
- Interpolation physique activée (`physics/common/physics_interpolation`) : bouger les corps et la
  caméra dans `_physics_process` ; après une téléportation, appeler `reset_physics_interpolation()`.

## Autoloads

| Nom | Script | Rôle |
|---|---|---|
| `EventBus` | `scripts/autoload/event_bus.gd` | Signaux globaux : `game_menu_toggled(is_open)`, `damage_dealt(target, info)`, `enemy_died(enemy)`, `item_picked_up(item, quantity)`, `level_up(new_level)`, `player_died`, `lock_on_target_changed(target)`, `interaction_target_changed(target)` |
| `GameState` | `scripts/autoload/game_state.gd` | navigation entre écrans (`start_new_game()`, `continue_game()`, `prepare_respawn()`, `go_to_title()`, `change_scene()`), `save_path`, `restore_player_on_spawn` ; drapeaux du monde `world_flags` (`set_flag()`, `has_flag()` : « chest:<id> », « door:<id> »), `remove_item()` ; `player_stats` (PlayerStats), `add_xp()`, `new_game()` ; catalogue `weapons` (tous les `.tres` de `resources/weapons/`), `equipped_weapon`, `equip_weapon()` / `equip_weapon_by_id()` ; catalogue `items` (`resources/items/`), `inventory` (id → quantité), `rupees`, `add_item()`, `get_item_count()` ; données persistantes `data` (par sections) ; `save_game()` / `load_game()` / `has_save()` en JSON dans `user://savegame.json`. Signaux `stats_changed`, `equipment_changed`, `inventory_changed`, `saving`, `loaded` |

**Sauvegarde :** `GameState.save_game()` émet `saving` → chaque système écrit sa section dans
`GameState.data` (ex. le joueur : `data["player"] = {"hp": …}`), puis `player_stats` est ajouté et le
tout écrit. `load_game()` relit, reconstruit `player_stats`, émet `stats_changed` puis `loaded` →
chaque système relit sa section. Tout nouveau système persistant (coffres, portes…) suit ce schéma.

## Calques de collision (nommés dans Paramètres du projet)

| # | Nom | Valeur de masque | Qui |
|---|---|---|---|
| 1 | world | 1 | décor, sol, murs |
| 2 | player | 2 | corps du joueur |
| 3 | enemies | 4 | corps des ennemis (et mannequins d'entraînement) |
| 4 | player_hitbox | 8 | zones de coups du joueur |
| 5 | enemy_hitbox | 16 | zones de coups des ennemis |
| 6 | pickups | 32 | objets ramassables |
| 7 | interactables | 64 | coffres, portes, PNJ |
| 8 | projectiles | 128 | projectiles |

| Objet | Calque | Masque |
|---|---|---|
| Corps du joueur (CharacterBody3D) | 2 | 1 + 3 (= 5) |
| Hurtbox du joueur | 2 | — |
| Hitbox d'arme du joueur | 4 | 3 |
| Corps d'un ennemi | 3 | 1 + 2 (= 3) |
| Corps d'un mannequin | 3 | 1 |
| Hurtbox d'un ennemi / mannequin | 3 | — |
| Hitbox d'attaque d'un ennemi | 5 | 2 |
| Zone de détection d'un ennemi | — | 2 |
| Objet ramassable (Pickup) | 6 | 2 |
| Interactable (coffre, porte…) | 7 | — |
| InteractionDetector du joueur | — | 7 |
| Murs invisibles (rivière, rivage de l'île) | 1 | — |
| Projectile du joueur (Area3D) | 8 | 1 (explose sur le décor) |
| Hitbox du projectile du joueur | 8 | 3 |
| SpringArm de la caméra, ligne de vue du lock-on, SightRay des ennemis | — | 1 |

## Actions d'entrée

Touches **physiques** (même position sur AZERTY et QWERTY).

| Action | Touches |
|---|---|
| move_forward / back / left / right | Z Q S D (AZERTY) = W A S D (QWERTY) + flèches |
| sprint | Maj gauche |
| jump | Espace |
| dodge | Ctrl ou C |
| attack | clic gauche |
| magic | clic droit |
| lock_on | Tab ou clic molette |
| target_next / target_prev | molette bas / haut (changer de cible en lock-on) |
| interact | E |
| inventory | I (ouvre / ferme l'inventaire ; dans l'inventaire, Tab change d'onglet) |
| pause | Échap (menu pause ; ferme l'inventaire s'il est ouvert) |
| ui_* (par défaut) | flèches + Entrée : navigation clavier dans tous les menus |
| debug_add_xp / debug_save / debug_load | F1 (+50 XP) / F2 (sauvegarder) / F3 (charger) — **builds de debug uniquement** (`OS.is_debug_build()`), gérés par GameState |
| debug_weapon_1 / 2 / 3 | touches 1 / 2 / 3 de la rangée du haut (& é " en AZERTY) : Épée en bois / Épée de chevalier / Lame de feu — debug uniquement |

## Composants génériques

| Composant | Fichier | État |
|---|---|---|
| StateMachine + State | `scripts/components/state_machine.gd`, `state.gd` | fait |
| HealthComponent | `scripts/components/health_component.gd` | fait |
| StaminaComponent | `scripts/components/stamina_component.gd` | fait |
| DamageInfo | `scripts/components/damage_info.gd` | fait (types : PHYSIQUE, FEU, GLACE, FOUDRE, MAGIE) |
| DamageCalculator | `scripts/components/damage_calculator.gd` | fait (formule ci-dessous, fonctions statiques) |
| ManaComponent | `scripts/components/mana_component.gd` | fait |
| Hitbox / Hurtbox | `scripts/components/hitbox.gd`, `hurtbox.gd` | fait |
| HitFlash | `scripts/components/hit_flash.gd` | fait (flash blanc via `material_overlay`) |
| HitStop | `scripts/components/hit_stop.gd` | fait (`HitStop.freeze(tree, durée)`, statique) |
| Projectile | `scripts/components/projectile.gd` | fait (Area3D + Hitbox enfant, tête chercheuse) |
| DamageNumber | `scripts/ui/damage_number.gd`, `scene/ui/damage_number.tscn` | fait (couleur par type, critiques) |
| EnemyHealthBar | `scripts/ui/enemy_health_bar.gd`, `scene/ui/enemy_health_bar.tscn` | fait (SubViewport + Sprite3D billboard, barre fantôme) |
| Pickup | `scripts/items/pickup.gd`, `scene/items/pickup.tscn` | fait (flotte, tourne, aspiré à 2,5 m, texte « +1 … ») |
| Interactable | `scripts/components/interactable.gd` | fait (Area3D calque 7, signal `interacted`, `prompt` / `prompt_provider`) |
| FloatingText | `scripts/ui/floating_text.gd`, `scene/ui/floating_text.tscn` | fait (`FloatingText.spawn(tree, texte, position, couleur)`) |

- **StateMachine** : les états sont ses enfants ; le **nom du nœud** est l'identifiant
  (`transition_to(&"Run", {msg})`). `actor` = parent par défaut. `auto_process_physics = false` quand
  le propriétaire appelle lui-même `physics_update()` (cas du joueur : minuteries → état → `move_and_slide`).
- **HealthComponent** : `take_damage(amount, source) -> bool` (false si mort/invincible),
  `heal()`, `set_invincible(durée)`, i-frames automatiques après un coup. Signaux `damaged`, `healed`,
  `died`, `health_changed`.
- **StaminaComponent** : `try_consume(cost) -> bool`, `can_use()`, régénération après `regen_delay`,
  épuisement (voir décisions de design).
- **ManaComponent** : `can_afford(cost)`, `try_consume(cost)` (exige le coût complet), régénération
  lente et continue (4/s).
- **Hitbox** (Area3D) : `damage_info` (préparé par le propriétaire) + `active` (piloté par l'animation).
  Détection toujours allumée ; ne frappe que si `active`, chaque Hurtbox **une fois par activation**,
  jamais la Hurtbox de `damage_info.source`. Signal `hit_landed(hurtbox, info)`.
- **Hurtbox** (Area3D) : `health`, `defense`, `resistances`. `receive_hit(info) -> bool` calcule
  `info.amount`, appelle `health.take_damage()`, émet `hit_received(info)` (le propriétaire gère le recul)
  et `EventBus.damage_dealt(cible, info)`, fait apparaître un DamageNumber.

## Formule de dégâts

```
dégâts = (dégâts_base_arme × multiplicateur_arme + Force)
         × multiplicateur_combo × (critique ? 1.5 : 1)
         − Défense_cible × 0.5
minimum 1
```

Puis × multiplicateur de type (faiblesse / résistance) : dictionnaire `{DamageType: multiplicateur}` dans
les stats de l'ennemi (ex. `{FEU: 2.0}` = faible au feu, `{GLACE: 0.5}` = résistant), et arrondi.
Code : l'attaquant calcule la partie offensive `DamageCalculator.compute_offense(base, mult_arme, force,
mult_combo, critique)` → `DamageInfo.raw_amount` ; la Hurtbox finit avec
`compute_final(raw, défense, type_multiplier(résistances, type))` → `DamageInfo.amount`.
`compute()` fait tout d'un coup (tests, équilibrage). Les sorts utilisent la même formule
(base du sort + Force, combo ×1, pas de critique).

## Statistiques et niveaux (jalon 2)

- `PlayerStats` (`scripts/player/player_stats.gd`) : `level`, `xp` (dans le niveau courant),
  `max_hp`, `max_stamina`, `max_mana`, `force`, `defense`, `speed`, gains par niveau, `max_level` (50).
  Valeurs de départ et gains : **`resources/stats/player_base_stats.tres`** (réglable dans l'inspecteur).
- XP pour passer au niveau suivant : `round(100 × niveau^1,5)` → 100, 283, 520, 800… Le surplus est conservé.
- Montée de niveau : +5 PV max, +10 endurance max, +5 mana max, +2 Force, +1 Défense, +1 Vitesse ;
  vie, endurance et mana remis au maximum ; `EventBus.level_up(niveau)` émis **une fois par niveau** ; effet
  `scene/player/level_up_effect.tscn` (un seul à la fois).
- Vitesse : multiplicateur de déplacement `1 + (Vitesse − 10) × 0,02` (min ×0,5), appliqué à la marche,
  la course et la marche épuisée (`player.get_walk_speed()`…), pas à la roulade.
- Sauvegardé : stats (`to_dict()` / `from_dict()`) + vie et mana actuels du joueur.
- Pour donner de l'XP : `GameState.add_xp(quantité)` (ennemis au jalon 4).

## Pipeline Blender → Godot (jalon 5)

Tous les modèles sont **générés par des scripts** (reproductibles, modifiables) :

| Script (`tools/blender/`) | Produit (`assets/blender/*.blend` + `assets/models/*.glb`) |
|---|---|
| `lowpoly.py` | bibliothèque commune (MeshBuilder, squelette, animations NLA, export) |
| `build_player.py` | `player` : héros façon Link, 15 os, WeaponSocket, 12 animations |
| `build_enemies.py` | `slime` (1 os) et `goblin` (15 os, massue), 5 animations chacun |
| `build_weapons.py` | `wooden_sword`, `knight_sword`, `fire_blade` (un .glb chacun, `weapons.blend`) |
| `build_props.py` | `tree_round`, `tree_pine`, `rock_a`, `rock_b`, `grass`, `house`, `chest`, `door`, `fence`, `bridge` (`props.blend`) |

Relancer un script depuis le MCP Blender (`execute_blender_code`) :
```python
path = r"C:\Users\psamf\Documents\zeldalike\tools\blender\build_player.py"
exec(compile(open(path, encoding="utf-8").read(), path, "exec"), {"__name__": "__main__", "__file__": path})
```
puis `godot --headless --path . --import`. Le script vide la scène Blender courante.

**Règles** : 1 unité = 1 m ; origine aux pieds ; le personnage regarde **+Y dans Blender = -Z dans
Godot** ; pièces rigides pondérées à 100 % sur un os ; maillages construits directement à l'origine
(transformations nulles, équivalent Ctrl+A) ; une action par animation rangée dans **sa propre piste
NLA** au nom exact ; export `.glb` en mode `NLA_TRACKS` ; couleurs unies par matériau, ombrage plat.
Rotations dans les scripts : axes monde (X : un membre pendant part vers l'avant pour un angle positif).

- **Arme en main** : Empty `WeaponSocket` parenté à l'os `hand.R` (axe +Y de l'Empty = lame) →
  Godot l'importe sous un `BoneAttachment3D` (`hand_R`). Armes : poignée à l'origine, lame vers +Y.
- **Collisions** : objets simplifiés suffixés `-convcolonly` (convexe) ou `-colonly` (concave) →
  StaticBody3D invisibles à l'import. Leurs noms doivent **se terminer** par le suffixe : les objets
  sont préfixés par le nom du décor pour éviter les « .001 » de Blender.
- **Boucles** : `idle`, `walk`, `run`, `fall` (et `idle`/`walk` des ennemis) réglées en boucle dans
  `_subresources` des `.glb.import` ; `animation/import_rest_as_RESET=true`.
- **Joueur** : l'`AnimationTree` (`resources/animation/player_animation_tree.tres`, généré par
  `tools/godot/build_player_animation_tree.gd`) anime le corps : `locomotion` (BlendSpace1D idle 0 /
  walk 5 / run 9 m/s), `jump`, `fall`, `roll`, `roll_back` (roll à l'envers), `attack_1..3`
  (BlendTree + TimeScale `parameters/attack_N/time_scale/scale` = vitesse de l'arme), `cast`, `hurt`,
  `death`. Les états appellent `player.play_body_animation(état, relancer)` / `animate_locomotion()`.
  L'`AnimationPlayer` du joueur (gameplay) ne garde que les événements : `WeaponHitbox:active`,
  `_anim_open_combo_window`, `_anim_release_spell`, orbe. Les deux démarrent ensemble à la même vitesse ;
  **les durées Blender et gameplay doivent rester égales** (attack_1/2 0,43 s, attack_3 0,63 s, cast 0,53 s).
- **Ennemis** : `EnemyModel` (glb) sous `Model/Visual` ; `Enemy.play_animation()` (boucles, fondu)
  et `Enemy.play_action()` (attack/hurt/death sur le modèle + l'AnimationPlayer gameplay s'il a l'animation).
  L'AnimationPlayer gameplay ne garde que `attack` (télégraphie, Hitbox, `_anim_commit_attack`).
- **Décors** : `.glb` instanciés directement (pas encore de script) sous `NavigationRegion3D/Props` du
  niveau de test ; le coffre et la porte deviendront interactifs au jalon 6 (scènes héritées + script).

## Monde (jalon 6)

- **Scène principale : `scene/world/island.tscn`** (l'île). `scene/world/main.tscn` = terrain
  d'entraînement utilisé par les tests des jalons 1 à 5 (mannequins, obstacles).
- Île (Godot : -Z = nord) : plage d'arrivée et **village** au sud (3 maisons, coffre), **forêt** à
  l'ouest (coffre caché : épée de chevalier), **rivière** est-ouest (z ≈ -2) franchissable
  uniquement par le **pont**, **zone d'ennemis** au nord (coffre gardé : petite clé), **donjon** au
  nord-est fermé par une porte à clé (coffre : Lame de feu). Terrain et donjon générés dans Blender
  (`tools/blender/build_island.py`).
- Murs invisibles (StaticBody3D, calque world) : berges de la rivière (trou au pont) et anneau
  au bord de l'eau. Mer = PlaneMesh à y = -0,55.
- Navigation **précuite** : `resources/navigation/island_navmesh.tres` (812 polygones), régénérée
  par `tools/godot/bake_navmesh.tscn` ; `level.gd` a `bake_navigation_on_ready = false` sur l'île.
- Éclairage : ciel procédural, soleil chaud avec ombres, brouillard léger, SSAO, léger glow,
  tonemap ACES, saturation ×1,15.

## Interactions (jalon 6)

- **Interactable** (Area3D, calque 7) posé sur l'objet ; **InteractionDetector** (Area3D devant
  le joueur, masque 7) choisit le plus proche **devant** (angle ≤ 75°), émet
  `EventBus.interaction_target_changed`. E (`interact`) dans un état au sol →
  `player.interaction.try_interact()` → signal `interacted(player)`.
- **InteractionPrompt** (`scene/ui/interaction_prompt.tscn`, CanvasLayer) affiche « Ouvrir  [E] » ;
  sera fusionné dans le HUD au jalon 7.
- **Coffre** (`scene/world/chest.tscn`, scène héritée de `chest.glb` + `scripts/world/chest.gd`) :
  `chest_id`, `loot_table` ; ouverture → animation « open », drapeau `chest:<id>`, le butin jaillit
  devant le coffre. Au chargement : couvercle ouvert si le drapeau existe.
- **Porte** (`scene/world/door.tscn` + `scripts/world/door.gd`) : `door_id`, `required_key` (ItemData,
  vide = libre), `consume_key`. Message : « Ouvrir » / « Déverrouiller » / « Verrouillée » ; sans clé :
  texte flottant « Il faut une petite clé ! ». Drapeau `door:<id>`.

## Objets, butin (jalon 4, complété au jalon 6)

- `ItemData` (`scripts/items/item_data.gd`, fichiers `resources/items/*.tres`) : `id`, `display_name`,
  `description`, `icon`, `type` (CONSOMMABLE, ARME, CLE, MATERIAU, MONNAIE), `stackable`, `max_quantity`,
  `heal_amount`, `use_on_pickup` (cœur : consommé au ramassage), `value` (rubis), `weapon`.
- Objets existants : `rupee` (« Rubis », 1 rubis), `heart` (+10 PV au ramassage), `potion` (rend 30 PV,
  à utiliser depuis l'inventaire au jalon 7), `small_key` (« Petite clé »), `knight_sword_item` et
  `fire_blade_item` (type ARME, champ `weapon`), `slime_jelly`, `goblin_fang`.
- Tables des coffres : `chest_village` (rubis + potion), `chest_forest` (épée de chevalier + rubis),
  `chest_key` (clé + cœur), `chest_dungeon` (Lame de feu + 20 rubis + potion).
- `LootTable` + `LootEntry` (`resources/loot_tables/*.tres`) : entrée = {item, weight, min/max_quantity,
  chance}. `roll(rng)` : chaque entrée de `guaranteed` est testée avec sa chance ; puis `rolls` tirages
  pondérés dans `entries`, chacun validé par sa chance. Les quantités d'un même objet sont cumulées.
- `Pickup` : flotte, tourne, se ramasse au contact après 0,4 s. `pop_to(point)` le fait jaillir en arc.

## Ennemis (jalon 4)

```
Enemy (CharacterBody3D, enemy.gd, groupes "enemies" + "lockable")   scene/enemies/enemy.tscn
├─ CollisionShape3D
├─ Model (tourne vers la direction)
│  ├─ Visual → EnemyModel (glb Blender), Telegraph (Label3D « ! » rouge)
│  └─ AttackHitbox (Hitbox, calque 5)
├─ Hurtbox, LockOnPoint, HealthBar (EnemyHealthBar)
├─ HealthComponent (invincibility_after_hit = 0 : chaque coup du combo compte), HitFlash
├─ NavigationAgent3D (path/target_desired_distance = 1,0 m — voir pièges)
├─ DetectionArea (sphère, rayon = detection_range), SightRay (RayCast3D, calque world)
├─ AnimationPlayer (gameplay : RESET, attack ; mode physique) — le corps est animé par le glb
└─ StateMachine → Patrol, Chase, Attack, Return, Hurt, Dead
```

- `slime.tscn` et `goblin.tscn` sont des **scènes héritées** de `enemy.tscn` : elles ajoutent le
  modèle Blender, les formes de collision, l'animation gameplay et règlent les `@export` d'IA.
- Stats : `EnemyStats` (`resources/stats/slime_stats.tres`, `goblin_stats.tres`) : `max_hp`, `force`,
  `defense`, `speed`, `xp_reward`, `attack_damage`, `attack_knockback`, `resistances`.
- Réglages d'IA sur la scène : `detection_range`, `view_half_angle`, `close_detection_range`,
  `lose_sight_time`, `leash_distance`, `attack_range`, `attack_cooldown`, `wander_radius`,
  `patrol_speed_factor`, `patrol_wait_time`, `hop_movement` (bonds), `lunge_speed` (bond d'attaque)…
- **Repérage** (`can_see_player()`) : joueur dans la DetectionArea, vivant, dans le champ de vision
  (sauf à moins de `close_detection_range`) et ligne de vue dégagée (SightRay).
- **Patrol** : points `patrol_points` (Marker3D, en boucle, pause à chacun) ou errance aléatoire sur le
  maillage autour du point d'apparition. **Chase** : navigation vers la dernière position connue ;
  abandon → **Return** si hors de vue depuis `lose_sight_time` s ou trop loin de chez lui.
  **Return** : retour au point d'apparition puis Patrol (reprend la poursuite s'il revoit le joueur
  à mi-chemin). **Attack** : animation `attack` = télégraphie (« ! » + préparation, l'ennemi suit le
  joueur du regard) → piste de méthode `_anim_commit_attack()` (bond éventuel) → piste
  `AttackHitbox:active` pendant les frames actives → récupération → recharge. **Hurt** : annule
  l'attaque, recul, puis Chase. **Dead** : collisions coupées, sorti des groupes, `GameState.add_xp()`,
  `EventBus.enemy_died`, butin, disparition après `despawn_delay`.
- Niveau : `scripts/world/level.gd` cuit la `NavigationRegion3D` au chargement (collisions statiques
  enfants). Le décor à contourner doit donc être **sous NavigationRegion3D**.

## Joueur (`scene/player/player.tscn`)

```
Player (CharacterBody3D, player.gd, groupe "player")
├─ CollisionShape3D (capsule)
├─ Model (Node3D, tourne vers la direction)
│  ├─ Visual
│  │  ├─ PlayerModel (player.glb : PlayerRig/Skeleton3D/hand_R/WeaponSocket, AnimationPlayer)
│  │  └─ MagicOrb (orbe du sort dans la main gauche, animée par « cast »)
│  └─ WeaponHitbox (Hitbox, profondeur = portée de l'arme)
├─ Hurtbox (défense = stat Défense)
├─ HealthComponent, StaminaComponent, ManaComponent
├─ AnimationPlayer (gameplay : RESET, attack_1..3, cast ; mode physique)
├─ AnimationTree (corps : player_animation_tree.tres sur PlayerModel/AnimationPlayer ; mode physique)
├─ StateMachine → Idle, Walk, Run, Jump, Fall, Dodge, Attack, Magic, Hurt, Dead
├─ LockOnComponent (marqueur : scene/player/lock_on_marker.tscn)
└─ CameraPivot (top_level, player_camera.gd) → SpringArm3D → Camera3D
```

- `player.gd` ne décide rien : il fournit des briques (`apply_gravity`, `move_horizontally`,
  `update_facing`, `try_consume_jump`, `get_move_direction`…). Les **états** décident.
- `PlayerState.try_ground_actions()` regroupe les transitions communes aux états au sol
  (saut, chute, roulade, attaque, magie).
- Déplacements relatifs au **lacet de la caméra**. Tous les réglages sont des `@export` groupés.
- Dégâts reçus : `HealthComponent.damaged` → état `Hurt` (recul) ; `died` → état `Dead`.
- Stats : `player.apply_stats(refill)` reporte `GameState.player_stats` sur Health/Stamina
  (au démarrage, à chaque `stats_changed`, et avec `refill = true` à la montée de niveau).
- **Combat** : `Attack` joue `attack_N` ; dans chaque animation, une piste de propriété met
  `Model/WeaponHitbox:active` à vrai **uniquement pendant les frames actives**, puis une piste de
  méthode appelle `_anim_open_combo_window()`. Un clic pendant le coup est mémorisé et lance le coup
  suivant dès l'ouverture de la fenêtre ; la roulade peut aussi annuler la fin du coup.
  `prepare_weapon_hit(index)` construit le DamageInfo (critique tiré au sort à chaque coup).
  L'animation `cast` appelle `_anim_release_spell()` (mana payé à cet instant).
- Retour d'impact : quand `EventBus.damage_dealt` concerne un coup du joueur → `HitStop.freeze()` +
  `camera_pivot.shake()` ; la cible gère son flash (HitFlash) et son recul (`hit_received`).
- Lock-on : une cible = `Node3D` du groupe **`lockable`**, avec un `Marker3D` enfant **`LockOnPoint`**
  (position du marqueur et point visé). Pour le relâcher (ex. ennemi mort), retirer la cible du groupe.

## Décisions de design (au plus proche de BotW / Link's Awakening)

- **Épuisement façon BotW** : la jauge vide → plus de sprint ni de roulade, marche lente
  (`exhausted_speed`), jusqu'à ce qu'elle remonte à `exhaustion_recovery_ratio` (1.0 = pleine).
- `try_consume()` accepte l'action tant que la jauge n'est pas vide (le coût peut dépasser le reste).
- Sprint en lock-on : le personnage regarde où il court ; en marche, il fait face à la cible (strafe).
- Tab sans cible valide : la caméra se replace derrière le joueur (comme le Z-targeting).
- Roulade sans direction : bond en arrière. En lock-on, la roulade garde le regard vers la cible.
- Le lock-on exige une ligne de vue (raycast sur le calque world) ; le marqueur reste visible à
  travers les murs. Changement de cible trié de gauche à droite vu depuis la caméra.
- Saut : gravité renforcée à la descente (×1.6), saut court si on relâche Espace tôt,
  coyote time 0,12 s, buffer 0,15 s.
- Le clic qui recapture la souris ne déclenche pas d'attaque.
- Montée de niveau : vie et endurance entièrement restaurées (récompense lisible, comme un
  réceptacle de cœur). Pas de montée de niveau si le joueur est mort.
- La vie de départ (30 PV) équivaut à 3 cœurs de 10 PV, pour un HUD en cœurs au jalon 7.
- **Magie = jauge de mana séparée** (choix validé) : 50 au départ, +5 par niveau, 4/s de régénération ;
  la boule d'énergie coûte 10. L'endurance reste réservée au sprint, à la roulade et aux attaques.
- Chaque coup d'arme coûte de l'endurance (`stamina_cost`) : pas d'attaque pendant l'épuisement.
- Chance de critique portée par l'arme (`critical_chance`) ; le coup final du combo a un recul ×1,5.
- Sort sans lock-on : le personnage se tourne dans l'axe de la caméra et tire droit devant ;
  avec lock-on, la boule vise la cible et la suit (tête chercheuse douce).
- Ennemis : télégraphie lisible avant chaque attaque (« ! » rouge au-dessus de la tête + mouvement
  de préparation : 0,6 s pour le Slime, 0,45 s pour le Gobelin), comme les ennemis de BotW.
- Le Slime (lent, 20 PV, faible au feu ×1,5) se déplace par petits bonds et attaque en bondissant ;
  le Gobelin (rapide, 35 PV, Défense 2) repère de plus loin, attaque plus souvent (massue).
- Un ennemi touché riposte (Hurt → Chase) même s'il n'avait pas vu le joueur.
- La barre de vie d'un ennemi n'apparaît qu'après le premier coup reçu ou pendant le lock-on.
- Les rubis sont toujours lâchés (1-2 Slime, 2-4 Gobelin) ; cœur et matériau au hasard.
- Style visuel : héros façon Link (tunique et bonnet verts, oreilles pointues), proportions
  légèrement « chibi » (grosse tête), low-poly à facettes, couleurs saturées.
- Roulade arrière (sans direction) = animation `roll` jouée à l'envers (état `roll_back`).
- L'épée est tenue pointe vers l'avant au repos ; pendant les tailles, la main pivote pour
  prolonger la lame dans l'axe du bras.
- Une arme trouvée va dans l'inventaire (comme dans BotW, pas d'équipement automatique) : on
  l'équipera depuis le menu au jalon 7 (en attendant : touches de test 1/2/3).
- La petite clé est consommée par la porte ; interagir n'est possible qu'au sol, hors attaque.
- Coffre à la Zelda : le couvercle s'ouvre, puis le butin jaillit et est aspiré vers le joueur.
- HUD en **cœurs** (plus lisible et plus « Zelda » qu'une barre) remplis par quarts comme BotW ;
  la jauge d'endurance disparaît quand elle est pleine, comme la roue de BotW.
- Lock-on : bandes noires en haut et en bas de l'écran, comme le Z-targeting d'Ocarina of Time.
- Nouvelle partie : l'épée en bois est dans l'inventaire (`STARTING_ITEMS`) et équipée.
- Une potion n'est pas bue si la vie est pleine ; une clé ne peut pas être jetée, ni l'arme équipée.
  Un objet jeté tombe devant le joueur et n'est pas aspiré (il faut marcher dessus).
- La statue de sauvegarde soigne complètement (comme les statues de déesse).
- Couleurs des chiffres de dégâts : blanc physique, orange feu, bleu glace, jaune pâle foudre, violet
  magie ; critique = plus gros, jaune doré, suivi de « ! ».

## Éléments provisoires (à remplacer)

- Animations faites à la main dans les scripts (poses clés) : correctes mais simples ; on peut les
  retoucher dans les .blend (les scripts écrasent les .blend : retoucher le script, ou ne plus le relancer).
- Les boucles importées durent une image de plus que prévu (ex. idle 1,03 s) : léger temps mort
  en fin de boucle, à corriger si gênant (exporter sans la dernière image dupliquée).
- Mannequins d'entraînement (`scene/enemies/training_dummy.tscn`) : vie infinie, pour tester les armes.
- Le terrain d'entraînement (`main.tscn`) cuit encore sa navigation au lancement (niveau de test).
- La porte du donjon ne recalcule pas la navigation en s'ouvrant : un ennemi enfermé dedans ne sait
  pas en sortir par le chemin (repli en ligne droite).
- Pas encore de particules d'impact ni d'explosion de la boule d'énergie → **jalon 8**.
- Niveau de test `scene/world/main.tscn` (sol, murs, plateformes) → île au **jalon 6**.

## Interface (jalon 7)

- **Scène de démarrage : `scene/ui/title_screen.tscn`** (l'île tourne en fond dans un SubViewport,
  sans joueur ni interface) : Nouvelle partie / Continuer (si sauvegarde) / Quitter.
- `scene/ui/game_ui.tscn` (Node `GameUI`, process ALWAYS) est instancié dans chaque niveau et
  regroupe : `HUD`, `InteractionPrompt`, `InventoryMenu`, `PauseMenu`, `DeathScreen`. Il gère
  Échap et I. Thème commun : `resources/ui/theme.tres` (panneaux sombres, bordures dorées, focus doré).
- **HUD** (`scripts/ui/hud.gd`) : cœurs `TextureProgressBar` (10 PV par cœur, remplissage horaire →
  quarts de cœur, clignotement rouge aux dégâts, dernier cœur qui bat sous 10 PV) ; endurance avec
  barre fantôme retardée (rouge à l'épuisement, s'efface quand pleine) ; mana ; « Niv. N » + barre
  d'XP ; rubis qui défilent ; emplacements arme / sort ; lock-on = bandes noires + « ◆ Nom ».
- **MenuScreen** (`scripts/ui/menu_screen.gd`) : base des menus → `open()` / `close()` mettent le
  jeu en pause (`get_tree().paused`), émettent `EventBus.game_menu_toggled` (la caméra libère ou
  recapture la souris ; le clic de fermeture n'attaque pas) et donnent le focus clavier.
- **Inventaire** : onglet Objets (grille triée arme > consommable > clé > matériau, fiche, boutons
  Utiliser / Équiper / Jeter) ; onglet Équipement (arme équipée, armes possédées, comparaison
  ▲ vert / ▼ rouge : dégâts = base × mult, vitesse, portée, critique, endurance/coup, type ; stats).
- **Pause** : Reprendre / Sauvegarder / Charger / Quitter vers le titre.
- **Point de sauvegarde** (`scene/world/save_point.tscn`, statue de cristal, place du village) :
  E sauvegarde et rend vie, endurance et mana.
- **Mort** : écran après 1,6 s → « Réapparaître » = `GameState.continue_game()` : recharge la
  sauvegarde, recharge la scène, le joueur reprend position / vie / mana sauvegardées
  (`restore_player_on_spawn`) ; sans sauvegarde → nouvelle partie. Les ennemis réapparaissent.
- Sauvegarde du joueur : `data["player"] = {hp, mana, position, yaw}`.

## Sons, particules, équilibrage (jalon 8)

- **Sons** : générés par `tools/audio/generate_sounds.py` (synthèse pure Python, CC0, aucun
  fichier externe) → `assets/audio/*.wav`. Catalogue `resources/audio/sound_library.tres`
  (`SoundLibrary` → `SoundEffect` : `id`, `stream`, `volume_db`, `pitch_variation`, `positional`, `bus`).
  Jouer : `Sfx.play(nœud, &"id", position_optionnelle)` (lecteur créé à la volée, libéré à la fin,
  joue pendant la pause). Bus `SFX` et `UI` (`default_bus_layout.tres`).
- **Avant de quitter** : `GameState.quit_game()` (coupe les sons puis attend 0,25 s ; la fermeture
  de la fenêtre y passe aussi : `auto_accept_quit = false`). Sinon Godot signale des fuites.
- Sons branchés : pas (tous les 1,7 m au sol), épée, impact / critique, douleur du joueur, cris des
  ennemis (`Enemy.hurt_sound`), alerte quand un ennemi repère le joueur, mort, ramassages, coffre,
  porte, porte verrouillée, niveau, sauvegarde, sort, impact magique, saut, roulade, menus.
- **Particules** : `scene/fx/*.tscn` (CPUParticles3D one-shot + `FxBurst`) :
  `FxBurst.spawn(nœud, SCENE, position, teinte)` → étincelles d'impact (couleur du type de dégâts),
  poussière de roulade, fumée de mort, scintillement de ramassage, éclat magique.
- **Équilibrage** : `resources/balance/player_tuning.tres` (`PlayerTuning`) regroupe tous les
  réglages du joueur ; `player.gd` n'a plus que des raccourcis de lecture (`player.walk_speed` →
  `tuning.walk_speed`). Tableau complet « où régler quoi » dans le README.

## Rendu et effets visuels (jalon 8.5)

- **Cel-shading** : `assets/shaders/toon.gdshader` (3 tons nets, ombres teintées de bleu, liseré
  côté lumière). `ToonMaterials.apply(racine)` convertit à l'exécution les StandardMaterial3D des
  modèles importés en ShaderMaterial toon (cache partagé ; matériaux transparents = copie en
  `DIFFUSE_TOON`) ; surfaces nommées `Foliage` / `Needles` → `toon_foliage.gdshader` (ondulent au
  vent au-dessus de 1,2 m). Appelé par `player.gd` (corps + arme équipée), `enemy.gd`, `level.gd`.
- **Contours encrés** : `OutlinePost` = quad plein écran sous la caméra du joueur (et de l'écran
  titre), shader `outline_post.gdshader` (bords de profondeur + normales, estompés de 25 à 70 m).
  Masqué en qualité Bas.
- **Environnement** (île, généré par `tools/level/generate_island.py`) : ACES, glow, SSAO, SDFGI,
  brouillard + brouillard volumétrique léger, étalonnage chaud (GradientTexture1D). Soleil aux ombres
  douces (`angular_distance`), lune. `WorldVisuals` (script du WorldEnvironment) active / coupe les
  effets selon la qualité.
- **Cycle jour / nuit** : `DayNightCycle` (nœud `DayNight`) : une journée = 10 min, début à 9 h 30 ;
  fait tourner soleil et lune, couleurs du ciel, brouillard et ambiance (nuit / aube / jour).
  `set_hour(h)`, `is_night()`, `running = false` pour figer (captures, tests).
- **Herbe** : `GrassField` (nœud `Grass`) : brins en MultiMesh par blocs de 10 m, posés par rayons
  sur le sol plat (`|y| ≤ 0,05`), hors `excluded_areas` (rivière, donjon) ; reconstruite au changement
  de qualité. Shader `grass.gdshader` : vent + rafales, écrasement autour du joueur.
- **Eau** : `water.gdshader` : mer (écume au rivage via la profondeur, vagues, fresnel) et rivière
  (`river_mode` : courant le long des UV + écume sur les berges).
- **Effets** : `SwordTrail` (traînée d'épée en ImmediateMesh, couleur du type de dégâts, seulement
  dans l'état Attack) ; impacts = étincelles + éclair + débris ; fumée de mort + scintillements ;
  bords de l'écran rouges quand le héros est touché (`HUD.flash_damage()`).
- **Modèles enrichis** (`tools/blender/`, palette commune `lowpoly.PALETTE`) : héros (bouclier dans
  le dos, col, sacoche, sourcils, nez, revers), Gobelin (arcade, anneau, mèches, pagne, épaulière),
  Slime (bulles, bouche, pousse), arbres (racines, branches, 7 touffes), sapins à 4 étages.
- **Réglages graphiques** Bas / Moyen / Haut (menu pause et écran titre) :
  `GameState.set_graphics_quality(q, persist = true)` → signal `graphics_quality_changed`, enregistré
  dans `user://settings.cfg` (**Moyen** par défaut). Bas : pas de GI / SSAO / brouillard volumétrique /
  contours, résolution 3D 80 %, herbe 0,6 brin/m². Moyen : SSAO, glow, contours, herbe 2,5/m².
  Haut : + SDFGI, brouillard volumétrique, MSAA 2×, ombres plus douces et lointaines, herbe 5/m².
- Mesures (1280×720, RTX 5080 portable, sans vsync) : Bas ≈ 900 i/s, Moyen ≈ 650, Haut ≈ 310.
- Captures : `docs/screenshots/avant_*` (fin du jalon 8), `apres_*`, `comparaison_*` (côte à côte) ;
  les images du README (`village.png`…) sont celles d'après.

## Export Windows (jalon 9)

- **Modèles d'export** 4.7.2 installés dans `%APPDATA%\Godot\export_templates\4.7.2.stable\`
  (fichier `.tpz` officiel de la page GitHub de Godot, somme SHA-512 vérifiée).
- **Preset** `export_presets.cfg` : « Windows Desktop », x86_64, **PCK intégré** → un seul
  `build/ZeldaLike.exe` (dossier `build/` ignoré par git). Exclus : `tests/*`, `tools/*`, `docs/*`,
  `assets/blender/*`, `*.md`, `*.blend`, `*.py`.
- **Nom / version** : `application/config/name = "ZeldaLike"`, `config/version = "1.0.0"` ; version
  de fichier et de produit `1.0.0.0` dans le preset (à augmenter aux deux endroits).
- **Icône** : logo `assets/textures/logo.svg` → `tools/godot/make_icon.gd` génère `icon.ico`
  (7 tailles) et `logo.png` (écran de démarrage, PNG obligatoire). Godot 4.7 n'utilise **plus
  rcedit** : l'icône et les infos de version sont écrites par l'export (`application/modify_resources`).
- **Exporter** :
  `"$G" --headless --path . --export-release "Windows Desktop" build/ZeldaLike.exe`
  (ou dans l'éditeur : Projet → Exporter… → Windows Desktop → Exporter le projet).
  Version en deux fichiers : `--export-pack "Windows Desktop" dossier/ZeldaLike.pck` + copie du
  modèle `windows_release_x86_64.exe` renommé `ZeldaLike.exe` à côté.
- **Tester le contenu exporté** : exporter un pack qui garde `tests/` (preset provisoire sans
  `tests/*` dans les exclusions), poser à côté le modèle release renommé et un `override.cfg`
  (`[application]` `run/main_scene="res://tests/test_jalonX.tscn"`), lancer avec `--headless`.
- **Release GitHub** : `gh release create vX.Y.Z build/ZeldaLike.exe build/*.zip --notes-file …`
  (`gh` installé par winget : `C:\Program Files\GitHub CLI\gh.exe`).

## Pièges connus

- **NavigationAgent3D** : le maillage est cuit environ 0,5 m au-dessus du sol ; avec
  `path_desired_distance` ≤ 0,5 l'agent ne passe jamais au point suivant et reste immobile.
  Garder 1,0 m (et `Enemy.navigate_to()` vise la cible en direct si le point suivant est à la verticale).
- NavigationMesh : `cell_size`/`cell_height` = 0,25 (comme la carte) et `agent_height`, `agent_radius`,
  `agent_max_climb` multiples de 0,25, sinon avertissement à la cuisson.
- Dictionnaires typés (`Dictionary[StringName, X]`) : remplir avec `.assign()` depuis un dictionnaire
  non typé.
- Changer `monitoring`/`monitorable` pendant un rappel physique : utiliser `set_deferred()`.
- Tests : `test_case` coupe les sons et attend 0,25 s avant de quitter (sinon fuites signalées).
- Vérifier les avertissements GDScript hors éditeur : passer temporairement les
  `debug/gdscript/warnings/*` à 2 (erreur) dans project.godot, lancer jeu + tests, puis revenir.
- `ProgressBar` arrondit à `step` (1 par défaut) : mettre `step = 0.0` pour les jauges du HUD.
- Focus clavier des menus : `grab_focus()` immédiat après reconstruction d'une liste (un
  `grab_focus.call_deferred()` peut écraser une sélection faite entre-temps).
- Changer de scène : toujours via `GameState.change_scene()` (dépause, remet `Engine.time_scale`).
- **Couleurs Blender** : les couleurs des scripts sont en sRGB et `lowpoly.material()` les convertit
  en linéaire (Blender/glTF stockent du linéaire) ; sinon tout sort délavé dans Godot.
- **Sol en triangles (-colonly)** : `is_on_floor()` peut clignoter une image. Les états au sol
  utilisent `player.is_grounded()` (tolérance `ground_grace_time` = 0,1 s) avant de passer en chute.
- Tests : après une téléportation, attendre l'atterrissage (état Idle) avant de simuler E ou une
  attaque (les actions ne sont acceptées qu'au sol).
- Blender 5.2 : un enfant d'os est placé relativement à la **queue** de l'os ; `lowpoly.attach_to_bone()`
  le gère. Lire `matrix_world` d'un objet juste créé renvoie l'identité (pas encore évalué).
- Scripts Godot lancés avec `-s` depuis `tools/` : fonctionnent malgré le `.gdignore`, mais sans
  autoloads (ne pas y utiliser GameState/EventBus).
- **Shader toon et lumières ponctuelles** : dans `light()`, `ATTENUATION` = ombre portée pour une
  lumière directionnelle mais baisse avec la distance pour une omni / spot. Séparer les deux avec
  `LIGHT_IS_DIRECTIONAL`, sinon chaque lampe éclaire toute sa zone d'un ton minimum (rectangles
  clairs la nuit).
- **Herbe et contours** : l'herbe est dans la passe transparente (`ALPHA = 1.0`,
  `depth_draw_never`) pour ne pas écrire la profondeur ; sinon le contour encré cerne chaque brin.
- **Smart App Control** (Windows 11, actif sur ce PC) bloque tout exe neuf non signé : le
  `ZeldaLike.exe` à PCK intégré (et icône modifiée) ne se lance pas ici ; le modèle officiel non
  modifié + `.pck` à côté, lui, passe. Ne pas toucher à ce réglage de sécurité ; une vraie
  solution = certificat de signature de code.
- Modèles d'export : les exe refusent une scène en argument (« compiled without support for path
  overrides ») → utiliser `override.cfg` à côté de l'exe.
- Le Python du Microsoft Store redirige les écritures dans `%APPDATA%` vers son dossier privé
  (`AppData\Local\Packages\PythonSoftwareFoundation…\LocalCache\Roaming`) : y écrire avec Bash / PowerShell.
- Écran de démarrage (`boot_splash/image`) : PNG uniquement (pas de SVG).
- Ne pas nommer une fonction `convert` (fonction intégrée de GDScript) → `convert_material`.
- Valeurs lues dans un `Array` non typé : caster (`float(…)`) pour éviter l'inférence Variant.

## Jalons

| # | Jalon | État |
|---|---|---|
| 0 | Préparation : arborescence, CLAUDE.md, calques, actions, autoloads | fait |
| 1 | Caméra orbitale, déplacements, machine à états, lock-on, coyote time / buffer | fait |
| 2 | Statistiques, niveaux et XP | fait |
| 3 | Armes, combos et magie | fait |
| 4 | Ennemis et IA | fait |
| 5 | Pipeline Blender → Godot | fait |
| 6 | Monde, objets et interactions | fait |
| 7 | HUD et interface | fait |
| 8 | Finitions (sons, particules, équilibrage, nettoyage, README) | fait |
| 8.5 | Amélioration visuelle : cel-shading + contours, SDFGI/VoxelGI, cycle jour/nuit, environnement (ACES, glow, SSAO, brouillard volumétrique, étalonnage chaud), herbe au vent (MultiMesh), feuillage qui ondule, eau stylisée avec écume, modèles Blender enrichis, traînées d'épée, particules plus riches, réglages graphiques bas / moyen / haut ; captures avant / après (`docs/screenshots/comparaison_*.png`) | fait |
| 9 | Export en exécutable + Release GitHub v1.0.0 | fait |
