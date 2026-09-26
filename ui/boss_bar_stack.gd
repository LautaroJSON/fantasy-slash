class_name BossBarStack
extends VBoxContainer
## Top-centre stack of boss health bars. The bars are created once in _ready
## (max_bars of them) and bound to the bosses of each boss wave.

@export var config: BossBarConfig
@export var bar_scene: PackedScene

var _bars: Array[BossHealthBar] = []


func _ready() -> void:
	add_theme_constant_override(&"separation", config.spacing)
	_create_bars()


## Binds one bar per boss (extra bosses beyond max_bars get no bar).
func show_bosses(bosses: Array[Enemy]) -> void:
	clear()
	for i: int in mini(bosses.size(), _bars.size()):
		_bars[i].track(bosses[i])


func clear() -> void:
	for bar: BossHealthBar in _bars:
		bar.release()


func get_bar(index: int) -> BossHealthBar:
	return _bars[index]


func visible_bar_count() -> int:
	var count: int = 0
	for bar: BossHealthBar in _bars:
		if bar.visible:
			count += 1
	return count


func _create_bars() -> void:
	for i: int in config.max_bars:
		var bar: BossHealthBar = bar_scene.instantiate() as BossHealthBar
		add_child(bar)
		bar.setup(config)
		_bars.append(bar)
