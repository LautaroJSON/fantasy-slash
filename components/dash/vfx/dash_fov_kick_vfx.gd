class_name DashFovKickVfx
extends DashVfxModule
## Module F (docs/specs/dash-feel.md): the camera widens its field of view when
## a dash starts and eases back.

@export var config: DashFovKickConfig

var _camera: ThirdPersonCamera = null


func setup(player: Player) -> void:
	_camera = player.get_node("CameraRig") as ThirdPersonCamera


func dash_started(_dash: DashComponent) -> void:
	_camera.kick_fov(config.fov_add, config.return_time)
