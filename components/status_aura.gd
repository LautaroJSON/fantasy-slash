class_name StatusAura
extends MeshInstance3D
## Aura shown while its entity has `status` (e.g. the red Rage aura). Updated
## only when the status list changes, never per frame.

@export var debuffs: DebuffComponent
@export var status: DebuffData


func _ready() -> void:
	debuffs.changed.connect(refresh)
	refresh()


func refresh() -> void:
	visible = debuffs.has_debuff(status.id)
