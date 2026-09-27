class_name AttackComboConfig
extends Resource
## The basic attack combo: strikes in order, chained by tapping inside each
## strike's combo window. Control feel, not upgradeable (like PlayerTuning).

## Where a strike faces (docs/specs/bdo-combat-feel.md).
enum AimMode {
	## Nearest enemy at the start; the windup follows it (and the movement
	## input, with windup_input_steering).
	NEAREST_ENEMY,
	## Camera forward at the start and during the windup.
	CAMERA,
	## Camera forward, pulled to the enemy closest in angle inside the assist
	## cone; the windup follows that enemy, or the camera without one.
	CAMERA_ASSIST,
}

## What the movement input does in a strike's recovery (after the cancel point).
enum RecoveryMove {
	## Cuts the strike and moves normally.
	CANCEL,
	## Slides at recovery_strafe_factor × MOVE_SPEED without turning; the strike goes on.
	STRAFE,
}

## Strikes in order; after the last one the combo starts over.
@export var steps: Array[AttackComboStep]
## ATTACK_SPEED at which the clips play at normal speed; the clip speed is
## ATTACK_SPEED / reference_attack_speed.
@export var reference_attack_speed: float
## Seconds an attack tap is remembered before it can start a strike.
@export var input_buffer: float
@export var aim_mode: AimMode
## NEAREST_ENEMY: true = the movement input steers the windup; false = only
## the aim target does (docs/specs/bdo-combat-feel.md §7).
@export var windup_input_steering: bool
## Degrees per second the facing may turn during the windup (until the hit).
@export var windup_turn_speed: float
## CAMERA_ASSIST: half angle, in degrees, of the cone around the camera
## forward where an enemy pulls the strike.
@export var assist_half_angle: float
## CAMERA_ASSIST: farthest enemy (center to center) that pulls the strike, in meters.
@export var assist_range: float
@export var recovery_move: RecoveryMove
## STRAFE: fraction of MOVE_SPEED while sliding in the recovery.
@export var recovery_strafe_factor: float
## Movement input magnitude, in [0, 1], that cuts a strike's recovery (CANCEL).
@export var move_cancel_threshold: float
## The lunge stops with an enemy ahead this close (center to center, minus
## the enemy's hit padding), in meters.
@export var lunge_stop_distance: float
## Half angle, in degrees, of the cone ahead where an enemy stops the lunge.
@export var lunge_stop_half_arc: float
## Scale of the Affliction build-up of every strike of this combo, so classes
## with fewer, heavier hits fill the bars as fast as quick ones (docs/specs/affliction.md).
@export var affliction_scale: float
