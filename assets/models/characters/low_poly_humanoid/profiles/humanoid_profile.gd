@tool
class_name HumanoidProfile
extends RefCounted
## Perfil de animación de LowPolyHumanoid (docs/specs/class-combat-identity.md):
## arma la librería completa de una clase (guardia, locomoción y combo) con el
## kit de poses del humanoide. Las poses y los tiempos son datos del asset
## (Principio II); los eventos de cada golpe (hit_on, hit_off, combo, end) van
## en los mismos tiempos que el AttackComboStep de la clase, y un test los compara.


## Devuelve la librería con idle, run, run_stop, jump_start, jump_air,
## jump_land, hit y attack_1 … attack_N.
func build(_humanoid: LowPolyHumanoid) -> AnimationLibrary:
	return AnimationLibrary.new()


## Procedural motion layer of the profile (poc/samurai-motion), or null.
## Called after build().
func build_motion() -> HumanoidMotionSetup:
	return null
