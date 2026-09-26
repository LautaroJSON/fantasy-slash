class_name EnemyHitFeedback
extends Node
## Forwards the player's hits (basic attack and abilities) to the health bar of
## the enemy hit, which shakes on critical or heavy hits. Debuff ticks are not
## player hits, so they never shake the bar.

@export var player: Player


func _ready() -> void:
	player.attack.enemy_hit.connect(_on_enemy_hit)
	player.basic_ability.enemy_hit.connect(_on_enemy_hit)
	player.ultimate_ability.enemy_hit.connect(_on_enemy_hit)
	player.air_slash.enemy_hit.connect(_on_enemy_hit)


func _on_enemy_hit(enemy: Enemy, applied: float, is_crit: bool) -> void:
	enemy.notify_hit(applied, is_crit)
