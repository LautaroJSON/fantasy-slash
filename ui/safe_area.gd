class_name SafeArea
extends RefCounted
## The part of the canvas not covered by notches or rounded corners, from
## DisplayServer's safe area (docs/specs/mobile-touch-controls.md). On PC the
## safe area covers the window, so the whole canvas is returned.


## Current safe rect in canvas coordinates of a canvas of `canvas_size`.
static func get_canvas_rect(canvas_size: Vector2) -> Rect2:
	var window := Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size()))
	return to_canvas(Rect2(DisplayServer.get_display_safe_area()), window, canvas_size)


## Pure: converts a screen-space safe area to the canvas of a window, clipped
## to the canvas. Without a usable safe area, the whole canvas.
static func to_canvas(screen_safe: Rect2, window: Rect2, canvas_size: Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, canvas_size)
	if not screen_safe.has_area() or not window.has_area():
		return full
	var scale: Vector2 = canvas_size / window.size
	var local := Rect2((screen_safe.position - window.position) * scale, screen_safe.size * scale)
	if not full.intersects(local):
		return full
	return full.intersection(local)


## Insets a full-rect `control` (anchors 0..1) to `safe` inside `canvas_size`.
static func inset(control: Control, safe: Rect2, canvas_size: Vector2) -> void:
	control.offset_left = safe.position.x
	control.offset_top = safe.position.y
	control.offset_right = safe.end.x - canvas_size.x
	control.offset_bottom = safe.end.y - canvas_size.y
