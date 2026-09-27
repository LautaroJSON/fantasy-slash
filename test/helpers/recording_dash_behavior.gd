extends DashBehavior
## Test double of a class dash behavior: records every hook and can refuse the
## dash or swap the clip. Not a test suite (no `_test` suffix).

var allow: bool = true
var clip_override: StringName = &""
var calls: Array[String] = []
var step_count: int = 0
var ended_cancelled: bool = false


func can_start(_dash: DashComponent) -> bool:
	calls.append("can_start")
	return allow


func started(_dash: DashComponent) -> void:
	calls.append("started")


func step(_dash: DashComponent, _delta: float) -> void:
	step_count += 1


func ended(_dash: DashComponent, cancelled: bool) -> void:
	calls.append("ended")
	ended_cancelled = cancelled


func get_clip(_dash: DashComponent, default_clip: StringName) -> StringName:
	return clip_override if clip_override != &"" else default_clip
