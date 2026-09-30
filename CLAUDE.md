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
"$G" --headless --path . --quit-after 300                    # lancer le jeu sans fenêtre : aucune erreur attendue
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

## Workflow par jalon

1. Implémenter le jalon. 2. Lancer en headless + tests (zéro erreur/avertissement). 3. Capture d'écran.
4. Mettre à jour ce fichier. 5. Commit `Jalon X : …` + push (jamais de `--force`).
6. Résumé à l'utilisateur, puis **attendre « continue »**. Ne jamais supprimer de travail sans le dire.

## Arborescence

```
assets/models/        .glb exportés depuis Blender
assets/blender/       .blend sources
assets/textures/ (icons/ : icônes SVG)  assets/audio/
scene/player/  scene/enemies/  scene/world/  scene/ui/  scene/components/
scene/items/ (weapons/ : modèles d'armes)  scene/projectiles/
scripts/player/ (+ states/)  scripts/enemies/  scripts/components/  scripts/items/
scripts/ui/  scripts/autoload/
resources/weapons/  resources/spells/  resources/items/  resources/loot_tables/  resources/stats/
tests/                scènes de test automatiques (à exclure de l'export, jalon 9)
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
| `EventBus` | `scripts/autoload/event_bus.gd` | Signaux globaux : `damage_dealt(target, info)`, `enemy_died(enemy)`, `item_picked_up(item, quantity)`, `level_up(new_level)`, `player_died`, `lock_on_target_changed(target)` |
| `GameState` | `scripts/autoload/game_state.gd` | `player_stats` (PlayerStats), `add_xp()`, `new_game()` ; catalogue `weapons` (tous les `.tres` de `resources/weapons/`), `equipped_weapon`, `equip_weapon()` / `equip_weapon_by_id()` ; données persistantes `data` (par sections) ; `save_game()` / `load_game()` / `has_save()` en JSON dans `user://savegame.json`. Signaux `stats_changed`, `equipment_changed`, `saving`, `loaded` |

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
| Corps d'un ennemi / mannequin | 3 | 1 |
| Hurtbox d'un ennemi / mannequin | 3 | — |
| Hitbox d'un ennemi (jalon 4) | 5 | 2 |
| Projectile du joueur (Area3D) | 8 | 1 (explose sur le décor) |
| Hitbox du projectile du joueur | 8 | 3 |
| SpringArm de la caméra, ligne de vue du lock-on | — | 1 |

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
| inventory | I |
| pause | Échap (pour l'instant : libère la souris ; un clic la recapture) |
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

## Joueur (`scene/player/player.tscn`)

```
Player (CharacterBody3D, player.gd, groupe "player")
├─ CollisionShape3D (capsule)
├─ Model (Node3D, tourne vers la direction)
│  ├─ Visual (Node3D au centre du corps : roulade, chute, recul)
│  │  ├─ Body, Nose (repère de l'avant)
│  │  ├─ WeaponSocket (arme en main ; BoneAttachment3D au jalon 5)
│  │  └─ MagicOrb (orbe du sort, animée par « cast »)
│  └─ WeaponHitbox (Hitbox, profondeur = portée de l'arme)
├─ Hurtbox (défense = stat Défense)
├─ HealthComponent, StaminaComponent, ManaComponent
├─ AnimationPlayer (RESET, attack_1, attack_2, attack_3, cast ; mode physique)
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
- Couleurs des chiffres de dégâts : blanc physique, orange feu, bleu glace, jaune pâle foudre, violet
  magie ; critique = plus gros, jaune doré, suivi de « ! ».

## Éléments provisoires (à remplacer)

- Capsule bleue = joueur ; roulade/recul/mort = rotations du nœud `Visual` → vrais modèles et
  animations au **jalon 5**.
- Animations d'attaque et de sort : rotations du nœud `WeaponSocket` → à refaire sur le squelette au
  **jalon 5** en gardant les pistes `WeaponHitbox:active` et les pistes de méthode.
- Modèles d'armes en primitives (`scene/items/weapons/*.tscn`) → `.glb` Blender au **jalon 5**.
- `WeaponSocket` (Node3D) → `BoneAttachment3D` sur l'os de la main au **jalon 5**.
- Mannequins d'entraînement (`scene/enemies/training_dummy.tscn`) : vie infinie, pour tester les armes
  → de vrais ennemis arrivent au **jalon 4**.
- Pas encore de particules d'impact ni d'explosion de la boule d'énergie → **jalon 8**.
- Niveau de test `scene/world/main.tscn` (sol, murs, plateformes) → île au **jalon 6**.

## Jalons

| # | Jalon | État |
|---|---|---|
| 0 | Préparation : arborescence, CLAUDE.md, calques, actions, autoloads | fait |
| 1 | Caméra orbitale, déplacements, machine à états, lock-on, coyote time / buffer | fait |
| 2 | Statistiques, niveaux et XP | fait |
| 3 | Armes, combos et magie | fait |
| 4 | Ennemis et IA | à faire |
| 5 | Pipeline Blender → Godot | à faire |
| 6 | Monde, objets et interactions | à faire |
| 7 | HUD et interface | à faire |
| 8 | Finitions | à faire |
| 9 | Export en exécutable + Release GitHub | à faire |
