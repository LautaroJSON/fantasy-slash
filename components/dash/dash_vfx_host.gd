class_name DashVfxHost
extends Node
## Shows the class dash VFX (docs/specs/dash-feel.md §2.4): instantiates one
## module per entry of the DashVfxSet (once, when the class is applied) and
## forwards the DashComponent events to them.

@export var player: Player
@export var dash: DashComponent

var _set: DashVfxSet = null
var _modules: Array[DashVfxModule] = []


func _ready() -> void:
	dash.dash_started.connect(_on_dash_started)
	dash.dash_step.connect(_on_dash_step)
	dash.dash_ended.connect(_on_dash_ended)


## Builds the modules of `vfx_set`; the same set again keeps them.
func setup(vfx_set: DashVfxSet) -> void:
	if vfx_set == _set:
		return
	_set = vfx_set
	for module: DashVfxModule in _modules:
		module.queue_free()
	_modules.clear()
	if vfx_set == null:
		return
	for scene: PackedScene in vfx_set.modules:
		var module: DashVfxModule = scene.instantiate() as DashVfxModule
		add_child(module)
		module.setup(player)
		_modules.append(module)


func get_modules() -> Array[DashVfxModule]:
	return _modules


func _on_dash_started() -> void:
	for module: DashVfxModule in _modules:
		module.dash_started(dash)


func _on_dash_step(_delta: float) -> void:
	for module: DashVfxModule in _modules:
		module.dash_step(dash)


func _on_dash_ended(cancelled: bool) -> void:
	for module: DashVfxModule in _modules:
		module.dash_ended(dash, cancelled)
