extends Node
## Bus d'événements globaux (autoload « EventBus »).
## Les systèmes indépendants (HUD, sons, quêtes…) s'abonnent ici au lieu de
## se connaître directement.

# Les signaux sont émis depuis d'autres scripts : on coupe l'avertissement
# « signal jamais utilisé » propre à ce fichier.
@warning_ignore_start("unused_signal")

## Un coup a été encaissé par `target`.
signal damage_dealt(target: Node, info: DamageInfo)
## Un ennemi vient de mourir.
signal enemy_died(enemy: Node)
## Le joueur a ramassé `quantity` exemplaires de `item` (ItemData, jalon 6).
signal item_picked_up(item: Resource, quantity: int)
## Le joueur passe au niveau `new_level`.
signal level_up(new_level: int)
## Le joueur est mort.
signal player_died
## La cible du lock-on a changé (null = lock-on relâché).
signal lock_on_target_changed(target: Node3D)

@warning_ignore_restore("unused_signal")
