class_name HitstopComponent
extends Node
## Local hit lag of the basic attack (docs/specs/bdo-combat-feel.md): when a
## combo strike lands on at least one enemy, the player's clip pauses for the
## strike's `hitlag` seconds, the enemies hit freeze and shake
## (Enemy.apply_hitlag) and the camera shakes with the strike's
## shake_strength. Engine.time_scale is never touched. A strike that ends or is
## cut (dash, cast, hold, death) ends the hit lag at once.
## Ability strikes (AbilityComponent.struck, docs/specs/warrior-abilities-rework.md
## §4.4) do the same with their StrikeFeel; the clip resumes at the speed it
## had, also when the cast ends or is cut during the hit lag.

@export var attack: AttackComponent
@export var health: HealthComponent
@export var camera: ThirdPersonCamera
## Its clip is the one paused. Optional: without it only enemies and camera react.
@export var humanoid: LowPolyHumanoid
@export var config: HitstopConfig
## Ability slots whose strikes pause the clip (channelled ones never emit `struck`).
@export var abilities: Array[AbilityComponent]

## Seconds left of the player's hit lag; 0 when none runs.
var _left: float = 0.0
## The running hit lag comes from an ability: it resumes the clip at _resume_speed.
var _from_ability: bool = false
var _resume_speed: float = 1.0


func _ready() -> void:
	attack.attacked.connect(_on_attacked)
	attack.enemy_hit.connect(_on_enemy_hit)
	attack.step_ended.connect(stop)
	health.died.connect(stop)
	for ability: AbilityComponent in abilities:
		ability.struck.connect(_on_struck)
		ability.cast_released.connect(_on_cast_released)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	advance(delta)


## Pauses the player's clip for `duration` seconds (restarts, never adds up).
func start(duration: float) -> void:
	if humanoid == null or duration <= 0.0:
		return
	_left = duration
	_from_ability = false
	humanoid.anim.speed_scale = 0.0
	set_physics_process(true)


## Counts down the hit lag and resumes the clip at its speed when it is over.
func advance(delta: float) -> void:
	if not is_active():
		return
	_left -= delta
	if _left <= 0.0:
		_resume()


## Ends the hit lag without touching the clip (the strike is over and the
## animator already picked the next clip).
func stop() -> void:
	_left = 0.0
	set_physics_process(false)


func is_active() -> bool:
	return _left > 0.0


func _resume() -> void:
	stop()
	humanoid.anim.speed_scale = _resume_speed if _from_ability else attack.get_clip_speed()


func _on_attacked(hit_count: int, _total_damage: float, _was_crit: bool) -> void:
	var step: AttackComboStep = attack.get_current_step()
	if hit_count <= 0 or step == null:
		return
	start(step.hitlag)
	camera.shake(step.shake_strength)


func _on_enemy_hit(enemy: Enemy, _applied: float, _is_crit: bool) -> void:
	var step: AttackComboStep = attack.get_current_step()
	if step == null:
		return
	enemy.apply_hitlag(step.hitlag, config)


func _on_struck(feel: StrikeFeel, enemies: Array[Enemy]) -> void:
	if feel.shake_strength > 0.0:
		camera.shake(feel.shake_strength)
	if feel.hitlag <= 0.0:
		return
	for enemy: Enemy in enemies:
		enemy.apply_hitlag(feel.hitlag, config)
	if humanoid == null:
		return
	if not is_active():
		_resume_speed = humanoid.anim.speed_scale
	start(feel.hitlag)
	_from_ability = true


func _on_cast_released() -> void:
	if is_active() and _from_ability:
		_resume()
