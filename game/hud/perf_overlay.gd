extends CanvasLayer
## F3 diagnostic overlay: FPS, the GPU the renderer ACTUALLY got, draw calls, canvas size.
## Exists because "sluggish in browser" usually means the browser handed WebGL the integrated
## GPU (while native Godot gets the discrete one) — this makes that visible in one keypress.
## Also prints the adapter to the console once at boot, so a report can be read post-hoc.

var _label: Label
var _acc := 0.0

func _ready() -> void:
	layer = 99
	print("[gpu] adapter: %s" % RenderingServer.get_video_adapter_name())
	_label = Label.new()
	_label.position = Vector2(8.0, 8.0)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.visible = false
	add_child(_label)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_label.visible = not _label.visible

func _process(delta: float) -> void:
	if not _label.visible:
		return
	_acc += delta
	if _acc < 0.5:
		return
	_acc = 0.0
	var vp := get_viewport()
	# player position in map CELLS (painted reaches) — turns "terrain is impassable here"
	# into an exact grid coordinate on the authored PNG
	var cell := "-"
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	var root := get_tree().get_first_node_in_group("cove_root")
	if axo and root and "config" in root and root.config.has_map:
		var local: Vector2 = (root as Node2D).to_local(axo.global_position)
		var c: Vector2 = ((local - root.config.map_origin) / 8.0).floor()
		cell = "cell (%d,%d)" % [c.x, c.y]
	_label.text = "FPS %d | %s\ndraws %d | objs %d | canvas %dx%d | %s" % [
		int(Performance.get_monitor(Performance.TIME_FPS)),
		RenderingServer.get_video_adapter_name(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		vp.size.x, vp.size.y, cell,
	]
