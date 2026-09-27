extends RefCounted
## Test helper: gives a humanoid a copy of one of its profile libraries without
## some clips, to check the fallbacks of optional clips (sprint, dash…) now
## that every profile has them (class-combat-identity.md removed `legacy`).


## Plays `profile`'s library minus `clips` as the humanoid's default library.
static func use(humanoid: LowPolyHumanoid, profile: StringName, clips: Array[StringName]) -> void:
	var library: AnimationLibrary = humanoid.get_profile_library(profile).duplicate() as AnimationLibrary
	for clip: StringName in clips:
		if library.has_animation(clip):
			library.remove_animation(clip)
	humanoid.anim.stop()
	humanoid.anim.remove_animation_library(&"")
	humanoid.anim.add_animation_library(&"", library)
	humanoid.play(&"idle", 0.0)
