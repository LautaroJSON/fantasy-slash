class_name EnemyStats
extends Resource
## Stats of one enemy type. The shared .tres is read-only at runtime; each
## enemy writes its level-scaled values into its own duplicate.

enum Stat { DAMAGE, DEFENSE, MAX_HEALTH, ATTACK_INTERVAL, ATTACK_RANGE, MOVE_SPEED, KNOCKBACK_FRICTION }

@export var damage: float
@export var defense: float
@export var max_health: float
## Seconds after an attack's recovery before the next attack may start.
@export var attack_interval: float
## Distance at which the enemy stops chasing, in meters.
@export var attack_range: float
## Meters per second.
@export var move_speed: float
## Deceleration of a knockback push, in m/s².
@export var knockback_friction: float
## Per-level growth of this enemy type; stats not listed do not grow.
@export var level_growth: Array[EnemyStatGrowth]
## Uniform scale of the body and its collision (bosses are bigger). Not level-scaled.
@export var body_scale: float
## Uniform scale of the floating health bar. Not level-scaled.
@export var health_bar_scale: float
## Name shown in the HUD boss bar (empty for regular enemies).
@export var display_name: String
## Bosses: health shown in the HUD instead of the floating 3D bar.
@export var hud_health_bar: bool
## EnemyBehavior scene instantiated once per enemy (docs/specs/enemy-attack-telegraph.md).
@export var behavior: PackedScene
## Attacks the behavior uses, in order (it cycles through them).
@export var attacks: Array[EnemyAttackData]
## Hands of this type (rest pose, bob, size); enemy.tscn's default when empty.
@export var hands_config: EnemyHandsConfig
## Extra settings of the behavior (e.g. HarasserConfig, GuardConfig); empty when unused.
@export var behavior_config: Resource
## Bosses: attacks without asking the AttackCoordinator for a token.
@export var ignores_attack_tokens: bool
## Hit lag (docs/specs/bdo-combat-feel.md): true = a player hit only shakes
## its body; its behavior keeps running (bosses).
@export var resists_hitlag: bool
## Bosses: control effects (e.g. the freeze of Frost) reach it in their weaker
## "resisted" version (AfflictionData.resisted_debuff; docs/specs/frost-freeze.md).
@export var resists_control: bool
## Fraction of every Affliction build-up it resists, in [0, AfflictionConfig.max_resistance]
## (docs/specs/affliction.md). 0 = none.
@export var affliction_resistance: float


func get_stat(stat: Stat) -> float:
	match stat:
		Stat.DAMAGE:
			return damage
		Stat.DEFENSE:
			return defense
		Stat.MAX_HEALTH:
			return max_health
		Stat.ATTACK_INTERVAL:
			return attack_interval
		Stat.ATTACK_RANGE:
			return attack_range
		Stat.MOVE_SPEED:
			return move_speed
		Stat.KNOCKBACK_FRICTION:
			return knockback_friction
	return 0.0


## Only used on an enemy's own duplicate, never on the shared .tres.
func set_stat(stat: Stat, value: float) -> void:
	match stat:
		Stat.DAMAGE:
			damage = value
		Stat.DEFENSE:
			defense = value
		Stat.MAX_HEALTH:
			max_health = value
		Stat.ATTACK_INTERVAL:
			attack_interval = value
		Stat.ATTACK_RANGE:
			attack_range = value
		Stat.MOVE_SPEED:
			move_speed = value
		Stat.KNOCKBACK_FRICTION:
			knockback_friction = value


## Pure on this resource: writes into `out` this type's stats scaled to `level`.
func write_scaled(level: int, out: EnemyStats) -> void:
	for i: int in Stat.size():
		var stat: Stat = i as Stat
		out.set_stat(stat, get_stat(stat))
	for growth: EnemyStatGrowth in level_growth:
		out.set_stat(growth.stat, growth.scale(get_stat(growth.stat), level))
