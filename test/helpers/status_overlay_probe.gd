extends Node
## Test helper (docs/specs/status-icons.md): shows one enemy's status icons the
## way the HUD does, with its own camera, registry and EnemyStatusOverlay, so
## tests can read the icons of an enemy that is not in the arena.
## Add it to the tree with auto_free, then call watch(enemy) and row().

const CONFIG: EnemyStatusOverlayConfig = preload("res://data/ui/enemy_status_overlay_config.tres")
## Camera distance from the health bar.
const CAMERA_DISTANCE: float = 6.0

var overlay: EnemyStatusOverlay
var _camera: Camera3D
var _registry: EnemyRegistry


func _init() -> void:
	_camera = Camera3D.new()
	add_child(_camera)
	_registry = EnemyRegistry.new()
	add_child(_registry)
	overlay = EnemyStatusOverlay.new()
	overlay.config = CONFIG
	add_child(overlay)
	overlay.registry = _registry


func watch(enemy: Enemy) -> void:
	_registry.register(enemy)
	var bar: Vector3 = enemy.health_bar.global_position
	_camera.global_position = bar + Vector3(0.0, 0.0, CAMERA_DISTANCE)
	_camera.look_at(bar)
	_camera.current = true


## The enemy's row after an update, or null when it has none.
func row() -> StatusIconRow:
	overlay.update_rows()
	return overlay.get_row(0) if overlay.get_visible_row_count() > 0 else null


func visible_icon_count() -> int:
	var shown: StatusIconRow = row()
	return 0 if shown == null else shown.get_visible_icon_count()
