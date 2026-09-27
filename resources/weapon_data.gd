class_name WeaponData
extends Resource
## The weapon of one class (fixed forever: a class never changes weapon).
## Its model is placed under the player's SwordPivot, at the rest pose.

## Adapter scene of the weapon model (with TrailBase/TrailTip markers for the
## weapon trail); its root is placed on the pivot.
@export var model: PackedScene
## Pivot position at rest, relative to the player's Visual.
@export var rest_position: Vector3
## Pivot rotation at rest, in radians.
@export var rest_rotation: Vector3
## Pose and timing of the weapon sweep (the Spin's dash slash) and of the
## blend back to rest after an ability.
@export var swing: SwordSwingConfig
## Optional scabbard (e.g. the katana's sheath). It hangs from a socket on a
## humanoid joint, so it follows that joint (docs/specs/sheath-in-left-hand.md:
## the katana's is held in the left hand). Null when the weapon has none.
@export var sheath: PackedScene
## Humanoid joint the scabbard socket hangs from (e.g. &"wrist_l").
@export var sheath_joint: StringName
## Socket position relative to `sheath_joint`, in meters.
@export var sheath_position: Vector3
## Socket rotation relative to `sheath_joint`, in radians.
@export var sheath_rotation: Vector3
## Pivot position relative to the humanoid's right hand while the hand holds
## the weapon (docs/specs/humanoid-player-model.md), in the hand's local units.
@export var grip_position: Vector3
## Pivot rotation relative to the right hand, in radians.
@export var grip_rotation: Vector3
