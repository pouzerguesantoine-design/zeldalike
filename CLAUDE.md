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
"$G" --headless --path . res://tests/test_jalon1.tscn        # tests auto (code de sortie 0 = OK)
"$G" --path . res://tests/test_jalon1.tscn -- capture.png    # idem + capture d'écran du rendu
```

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
assets/textures/  assets/audio/
scene/player/  scene/enemies/  scene/world/  scene/ui/  scene/items/  scene/components/
scripts/player/ (+ states/)  scripts/enemies/  scripts/components/  scripts/items/
scripts/ui/  scripts/autoload/
resources/weapons/  resources/items/  resources/loot_tables/  resources/stats/
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
- Composants sans sous-nœuds (Health, Stamina…) : simple `Node` + script, pas de `.tscn`.
  Composants avec sous-nœuds (Hitbox, Hurtbox…) : une scène dans `scene/components/`.
- Nœuds qui lisent les `@onready` de leur parent dans `_ready()` : `await parent.ready` si besoin
  (les enfants sont prêts **avant** le parent).
- Interpolation physique activée (`physics/common/physics_interpolation`) : bouger les corps et la
  caméra dans `_physics_process` ; après une téléportation, appeler `reset_physics_interpolation()`.

## Autoloads

| Nom | Script | Rôle |
|---|---|---|
| `EventBus` | `scripts/autoload/event_bus.gd` | Signaux globaux : `damage_dealt(target, info)`, `enemy_died(enemy)`, `item_picked_up(item, quantity)`, `level_up(new_level)`, `player_died`, `lock_on_target_changed(target)` |
| `GameState` | `scripts/autoload/game_state.gd` | Données persistantes (`data`, par sections) ; `save_game()` / `load_game()` / `has_save()` en JSON dans `user://savegame.json` |

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

Joueur : `collision_layer = 2`, `collision_mask = 5` (world + enemies). SpringArm de la caméra : masque 1.

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

## Composants génériques

| Composant | Fichier | État |
|---|---|---|
| StateMachine + State | `scripts/components/state_machine.gd`, `state.gd` | fait |
| HealthComponent | `scripts/components/health_component.gd` | fait |
| StaminaComponent | `scripts/components/stamina_component.gd` | fait |
| DamageInfo | `scripts/components/damage_info.gd` | fait (types : PHYSIQUE, FEU, GLACE, FOUDRE, MAGIE) |
| Hitbox / Hurtbox | `scene/components/` | à faire (jalon 3) |

- **StateMachine** : les états sont ses enfants ; le **nom du nœud** est l'identifiant
  (`transition_to(&"Run", {msg})`). `actor` = parent par défaut. `auto_process_physics = false` quand
  le propriétaire appelle lui-même `physics_update()` (cas du joueur : minuteries → état → `move_and_slide`).
- **HealthComponent** : `take_damage(amount, source) -> bool` (false si mort/invincible),
  `heal()`, `set_invincible(durée)`, i-frames automatiques après un coup. Signaux `damaged`, `healed`,
  `died`, `health_changed`.
- **StaminaComponent** : `try_consume(cost) -> bool`, `can_use()`, régénération après `regen_delay`,
  épuisement (voir décisions de design).

## Formule de dégâts

```
dégâts = (dégâts_base_arme × multiplicateur_arme + Force)
         × multiplicateur_combo × (critique ? 1.5 : 1)
         − Défense_cible × 0.5
minimum 1
```

Puis application des faiblesses / résistances : dictionnaire `{DamageType: multiplicateur}` dans les
stats de l'ennemi (ex. `{FEU: 2.0}` = faible au feu, `{GLACE: 0.5}` = résistant). Implémentée au jalon 3.

## Joueur (`scene/player/player.tscn`)

```
Player (CharacterBody3D, player.gd, groupe "player")
├─ CollisionShape3D (capsule)
├─ Model (Node3D, tourne vers la direction)
│  └─ Visual (Node3D au centre du corps : roulade, chute, recul)
│     ├─ Body, Nose (repère de l'avant)
│     └─ Sword, MagicOrb (visuels provisoires, masqués)
├─ HealthComponent, StaminaComponent
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

## Éléments provisoires (à remplacer)

- Capsule bleue = joueur ; roulade/recul/mort = rotations du nœud `Visual` → vrais modèles et
  animations au **jalon 5**.
- État `Attack` : l'épée apparaît 0,3 s sans dégâts ; état `Magic` : une orbe apparaît → **jalon 3**.
  (La détection de dégâts de la phase 1 a été retirée en attendant les Hitbox/Hurtbox.)
- Mannequins d'entraînement (`scene/world/training_dummy.tscn`) : cibles de lock-on fixes → ennemis
  au **jalon 4**.
- Niveau de test `scene/world/main.tscn` (sol, murs, plateformes) → île au **jalon 6**.

## Jalons

| # | Jalon | État |
|---|---|---|
| 0 | Préparation : arborescence, CLAUDE.md, calques, actions, autoloads | fait |
| 1 | Caméra orbitale, déplacements, machine à états, lock-on, coyote time / buffer | fait |
| 2 | Statistiques, niveaux et XP | à faire |
| 3 | Armes, combos et magie | à faire |
| 4 | Ennemis et IA | à faire |
| 5 | Pipeline Blender → Godot | à faire |
| 6 | Monde, objets et interactions | à faire |
| 7 | HUD et interface | à faire |
| 8 | Finitions | à faire |
| 9 | Export en exécutable + Release GitHub | à faire |
