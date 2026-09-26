class_name EnemyAttackData
extends Resource
## One enemy attack in three phases: windup (the hands pull back, the enemy
## barely turns), active (the hitbox is live, one hit per attack) and recovery
## (the enemy stands still and exposed). See docs/specs/enemy-attack-telegraph.md.

## Which hands deliver the blow. ALTERNATE switches hand on every attack.
enum Hands { BOTH, LEFT, RIGHT, ALTERNATE }

## Multiplies the enemy's level-scaled damage.
@export var damage_multiplier: float
@export var windup_time: float
## Seconds the hitbox stays live.
@export var active_time: float
@export var recovery_time: float
## Flat distance to the target at which the windup starts, in meters.
@export var trigger_range: float
## Reach of the hitbox from the enemy's centre, in meters.
@export var hit_range: float
## Full width of the hitbox arc, centred on the enemy's facing.
@export var hit_arc_degrees: float
## Degrees per second the enemy may still turn towards the target while winding up.
@export var windup_turn_speed: float
## A knockback during the windup cancels the attack.
@export var interruptible: bool
@export var hands: Hands
## Hand offset (enemy local space, relative to the rest pose) at the end of the windup.
@export var hand_windup_offset: Vector3
## Hand offset (enemy local space, relative to the rest pose) at the peak of the strike.
@export var hand_strike_offset: Vector3


## Pure: whether a target at `point` with radius `padding` is inside the arc
## of an enemy at `origin` facing `facing`. Heights are ignored.
func is_hit(origin: Vector3, facing: Vector3, point: Vector3, padding: float) -> bool:
	var to_point := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	var distance: float = to_point.length()
	if distance - padding > hit_range:
		return false
	if distance <= padding:
		return true
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if flat_facing.is_zero_approx():
		return false
	var angle: float = flat_facing.angle_to(to_point)
	return angle <= deg_to_rad(hit_arc_degrees) * 0.5


## Seconds from the start of the windup to the end of the recovery.
func get_total_time() -> float:
	return windup_time + active_time + recovery_time
