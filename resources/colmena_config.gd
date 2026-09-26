class_name ColmenaConfig
extends BossConfig
## La Colmena (docs/specs/boss-colmena.md): shielded while its minions live,
## exposed for a while once they are all dead, then it calls another batch.

## Windup (hands up) and recovery of a call, and its hand poses.
@export var summon_attack: EnemyAttackData
@export var summon_phase_one: SummonData
@export var summon_phase_two: SummonData
## Seconds without shield after the last minion dies.
@export var exposed_time_phase_one: float
@export var exposed_time_phase_two: float
## It keeps the target between these distances, in meters.
@export var keep_min_distance: float
@export var keep_max_distance: float
## Status listed (HUD icon, aura) while the shield is up.
@export var shield_status: DebuffData


## Pure: batch called in boss phase `phase`.
func summon_for(phase: int) -> SummonData:
	return summon_phase_two if phase == 2 else summon_phase_one


## Pure: exposed window in boss phase `phase`.
func exposed_time_for(phase: int) -> float:
	return exposed_time_phase_two if phase == 2 else exposed_time_phase_one
