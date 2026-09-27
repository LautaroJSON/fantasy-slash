extends RefCounted
## Drives the player's basic attack combo in tests
## (docs/specs/humanoid-player-model.md). Strikes land when the humanoid's clip
## opens its hit window, so these helpers advance the humanoid's
## AnimationPlayer by hand. Not a test suite (no `_test` suffix).

## Clip time advanced per step while waiting for an event, in seconds.
const STEP: float = 1.0 / 60.0
## Longest wait for an event, in clip seconds (longer than any strike clip).
const MAX_WAIT: float = 3.0


## Combo whose strikes deal and push like a single old swing (multipliers 1),
## no lunge and no hit lag, so tests that check damage math and positions
## keep their numbers (docs/specs/bdo-combat-feel.md).
static func unit_combo(source: AttackComboConfig) -> AttackComboConfig:
	var combo: AttackComboConfig = source.duplicate(true) as AttackComboConfig
	for step: AttackComboStep in combo.steps:
		step.damage_multiplier = 1.0
		step.knockback_multiplier = 1.0
		step.lunge_distance = 0.0
		step.hitlag = 0.0
	return combo


## Uses unit_combo() on the player's attack.
static func use_unit_combo(player: Player) -> void:
	player.attack.combo = unit_combo(player.attack.combo)


## Lets the test drive the clips by hand: manual processing, and method-track
## events (hit window, combo window, end) called at once instead of deferred.
static func drive_by_hand(player: Player) -> void:
	var anim: AnimationPlayer = humanoid_of(player).anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	(player.get_node("PlayerAnimator") as PlayerAnimator).set_physics_process(false)
	player.attack.set_physics_process(false)


static func humanoid_of(player: Player) -> LowPolyHumanoid:
	return player.get_node("Visual/Humanoid") as LowPolyHumanoid


## Starts a strike and advances its clip until the damage lands. Returns false
## if no strike could start.
static func strike(player: Player, crit_roll: float) -> bool:
	if not player.attack.try_attack_with_roll(crit_roll):
		return false
	var landed: Array[bool] = [false]
	var on_attacked: Callable = func(_h: int, _t: float, _c: bool) -> void: landed[0] = true
	player.attack.attacked.connect(on_attacked)
	advance_until(player, func() -> bool: return landed[0])
	player.attack.attacked.disconnect(on_attacked)
	return true


## Strikes and lets the strike finish, so the next one starts the combo over.
static func strike_and_finish(player: Player, crit_roll: float) -> bool:
	var started: bool = strike(player, crit_roll)
	finish(player)
	return started


## Advances the clip until the strike in course ends.
static func finish(player: Player) -> void:
	advance_until(player, func() -> bool: return not player.attack.is_attacking())


## Advances the humanoid clip (and the attack's own bookkeeping) until `done`.
static func advance_until(player: Player, done: Callable) -> void:
	var anim: AnimationPlayer = humanoid_of(player).anim
	var hitstop: HitstopComponent = player.get_node("Hitstop") as HitstopComponent
	var waited: float = 0.0
	while not done.call() and waited < MAX_WAIT:
		anim.advance(STEP)
		player.attack.advance(STEP)
		hitstop.advance(STEP)
		waited += STEP
