extends CanvasLayer
## THE WATERSHED — the map overlay (Batch D). M / pad Select (the "map" action) pauses the tree
## over the cove and draws the chart of everywhere you have been: a disc per visited reach in its
## door colour with its name, a gold ring on where you stand, a pearl on the restored, and a dark
## nameless "?" one door beyond the known — the same tease grammar as the doors themselves. All
## data is derived live on open (registry + WorldState); the rules live in map_chart.gd where the
## headless suite holds them, so this file only draws. Also reachable from the rest menu's "map"
## button, which is the touch path until a dedicated chip earns its place.
## Code-added by cove.gd after the pixel shell (root-side, never wrapped) — no scene edits.

const Chart := preload("res://game/hud/map_chart.gd")
const Registry := preload("res://game/world/reach_registry.gd")

const COL_W := 110.0
const ROW_H := 64.0
const PAD := 34.0
const NODE_R := 13.0
const TEASE_FILL := Color(0.16, 0.22, 0.27)

var _open := false
var _root: Control
var _canvas: Control
var _close_btn: Button

func _ready() -> void:
	layer = 96                 # under the rest card (97), over the restoration banner (95)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("map_overlay")
	_build()
	_root.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _open:
		if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel") \
				or event.is_action_pressed("menu"):
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and not Settings.ui_locked():
		open()
		get_viewport().set_input_as_handled()

func open() -> void:
	if _open:
		return
	_open = true
	_rebuild()
	_root.visible = true
	get_tree().paused = true
	Settings.push_ui_lock()
	Sfx.play("ui_open", -6.0)
	_close_btn.grab_focus()

func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	Settings.pop_ui_lock()

## Pull the live world into a fresh chart. Cheap (a handful of reaches), so every open re-derives —
## no cache to go stale when a door is crossed or a reach turns gold.
func _rebuild() -> void:
	var visited: Array = []
	var restored: Array = []
	for id in Registry.ids():
		if WorldState.has_visited(id):
			visited.append(id)
		if WorldState.is_restored(id):
			restored.append(id)
	var chart := Chart.build(Registry, visited, WorldState.current_id, restored)
	_canvas.set("chart", chart)
	for c in _canvas.get_children():
		c.queue_free()
	var cols := 0
	var max_rows := 0
	var rows_in := {}
	for n in chart["nodes"]:
		cols = maxi(cols, int(n["depth"]))
		rows_in[n["depth"]] = maxi(int(rows_in.get(n["depth"], 0)), int(n["row"]) + 1)
	for c in rows_in:
		max_rows = maxi(max_rows, int(rows_in[c]))
	_canvas.custom_minimum_size = Vector2(PAD * 2.0 + cols * COL_W, PAD * 2.0 + (max_rows - 1) * ROW_H + 26.0)
	var pos := {}
	for n in chart["nodes"]:
		var col_rows: int = int(rows_in[n["depth"]])
		var y: float = PAD + (max_rows - col_rows) * ROW_H * 0.5 + int(n["row"]) * ROW_H
		pos[n["id"]] = Vector2(PAD + int(n["depth"]) * COL_W, y)
	_canvas.set("pos", pos)
	for n in chart["nodes"]:
		var l := Label.new()
		l.text = "?" if n["tease"] else String(n["name"])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 18 if n["tease"] else 16)
		l.add_theme_color_override("font_color", Color(Palette.FOAM, 0.7) if n["tease"] else Color(Palette.FOAM))
		l.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.9))
		l.add_theme_constant_override("shadow_offset_y", 1)
		_canvas.add_child(l)
		var p: Vector2 = pos[n["id"]]
		if n["tease"]:
			l.size = Vector2(30.0, 24.0)
			l.position = p - l.size * 0.5   # the "?" sits ON the dark disc
		else:
			l.size = Vector2(COL_W, 18.0)
			l.position = Vector2(p.x - COL_W * 0.5, p.y + NODE_R + 5.0)
	_canvas.queue_redraw()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.55)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UiTheme.panel())
	_root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var head := Label.new()
	head.text = "the watershed"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color(0.95, 0.99, 1.0))
	vb.add_child(head)
	_canvas = ChartCanvas.new()
	vb.add_child(_canvas)
	var legend := Label.new()
	legend.text = "gold ring — you are here · pearl — restored"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 15)
	legend.add_theme_color_override("font_color", Color(Palette.FOAM, 0.8))
	vb.add_child(legend)
	_close_btn = Button.new()
	_close_btn.text = "close"
	_close_btn.custom_minimum_size = Vector2(200.0, 36.0)
	_close_btn.add_theme_font_size_override("font_size", 24)
	UiTheme.style_button(_close_btn)
	_close_btn.pressed.connect(close)
	var center := CenterContainer.new()
	center.add_child(_close_btn)
	vb.add_child(center)

class ChartCanvas extends Control:
	var chart := {}
	var pos := {}
	const R := 13.0
	func _draw() -> void:
		if chart.is_empty():
			return
		for e in chart["edges"]:
			draw_line(pos[e[0]], pos[e[1]], Color(Palette.FOAM, 0.35), 2.0)
		for n in chart["nodes"]:
			var p: Vector2 = pos[n["id"]]
			if n["tease"]:
				draw_circle(p, R, Color(0.16, 0.22, 0.27))
				continue
			var t: Color = n["tint"]
			draw_circle(p, R, Color(t.r, t.g, t.b))
			if n["restored"]:
				draw_circle(p, R * 0.38, Color(Palette.FOAM))
			if n["current"]:
				draw_arc(p, R + 4.0, 0.0, TAU, 40, Color(Palette.GOLD), 2.5)
