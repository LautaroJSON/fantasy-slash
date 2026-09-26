class_name InputPromptConfig
extends Resource
## Key and button names the UI shows for each action, per input device
## (Principle VI: prompts come from data).

## Action -> prompt while playing with keyboard and mouse.
@export var keyboard_prompts: Dictionary[StringName, String] = {}
## Action -> prompt while playing with a gamepad.
@export var gamepad_prompts: Dictionary[StringName, String] = {}
## Smallest absolute axis value that counts as using the gamepad (ignores stick drift).
@export var gamepad_motion_threshold: float


func get_prompt(action: StringName, device: InputDeviceMonitor.Device) -> String:
	var prompts: Dictionary[StringName, String] = gamepad_prompts if device == InputDeviceMonitor.Device.GAMEPAD else keyboard_prompts
	return prompts.get(action, "")
