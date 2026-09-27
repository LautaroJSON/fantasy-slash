class_name EnemyBehavior
extends Node
## Base of the logic of one enemy type. Instantiated once per enemy from
## EnemyStats.behavior and driven by Enemy: physics_update() every physics
## frame the enemy is not being pushed, knocked_back() when a push starts and
## reset() on every activate() (pooled enemies are reused).

var enemy: Enemy


func setup(owner_enemy: Enemy) -> void:
	enemy = owner_enemy


## Back to the state of a freshly spawned enemy.
func reset() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## A knockback push just started; the behavior is not updated while it lasts.
func knocked_back() -> void:
	pass


## Whether a push along `direction` (flat, normalized; away from the pusher)
## is ignored, e.g. blocked by a shield.
func resists_knockback(_direction: Vector3) -> bool:
	return false


## activate() or enrage() just reset the health and the status list: put back
## any state the behavior keeps there (e.g. a boss shield).
func state_restored() -> void:
	pass


## The enemy was deactivated (killed or returned to its pool).
func deactivated() -> void:
	pass


## Arcs (degrees) of the sector warnings this behavior shows; their meshes
## are built once when the enemy is created. By default, those of stats.attacks.
func get_telegraph_arcs() -> Array[float]:
	var arcs: Array[float] = []
	for attack: EnemyAttackData in enemy.stats.attacks:
		arcs.append(attack.hit_arc_degrees)
	return arcs


## True from the start of a windup to the end of its recovery.
func is_attacking() -> bool:
	return false


## The enemy was stunned (Enemy.stun; only enemies that do not resist control):
## cancel the attack in progress so a stun always stops the hit it was preparing.
func stunned() -> void:
	pass
