class_name PointerMode
extends RefCounted
## The only place that writes Input.mouse_mode. Gameplay captures the mouse for
## the camera and menus release it; on phones and tablets there is no mouse to
## capture, so the capture is skipped (docs/specs/mobile-touch-controls.md).


static func capture_for_gameplay() -> void:
	if is_capture_allowed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func release_for_ui() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func is_capture_allowed() -> bool:
	return not OS.has_feature(InputDeviceMonitor.MOBILE_FEATURE)
