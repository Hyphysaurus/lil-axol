extends CanvasLayer
## Feat callouts + the Flow meter — the SSX-Tricky celebration layer's VIEW. Listens to the "shine"
## group: `feat_called` slides a named banner (Lilita One) in with its +Shine; `flow_changed` drives a
## Flow bar at top-centre that fills, then glows and pulses through TIDAL FLOW. Pure presentation —
## it reads Shine's signals and never touches the economy; hides while any menu is up.

const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne.ttf")

var _root: Control
var _flowbar: FlowBar
var _stack := 0   # concurrent callouts, so a burst of feats fans out vertically instead of overlapping

func _ready() -> void:
	layer = 93                     # above the score HUD (92), below the win banner (95)
	_build()
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper:
		if keeper.has_signal("feat_called"):
			keeper.feat_called.connect(_on_feat)
		if keeper.has_signal("flow_changed"):
			keeper.flow_changed.connect(_on_flow)
	Settings.ui_lock_changed.connect(func(locked: bool) -> void: visible = not locked)
	visible = not Settings.ui_locked()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# Flow bar, centred at the top (top-left is the restoration meter, top-right is the score)
	_flowbar = FlowBar.new()
	_flowbar.anchor_left = 0.5
	_flowbar.anchor_right = 0.5
	_flowbar.offset_left = -FlowBar.W * 0.5
	_flowbar.offset_right = FlowBar.W * 0.5
	_flowbar.offset_top = 14.0
	_flowbar.offset_bottom = 14.0 + FlowBar.H
	_root.add_child(_flowbar)

func _on_flow(frac: float, active: bool) -> void:
	_flowbar.set_state(frac, active)

## Slide a named feat callout in: pop + fade in, hold, then drift up + fade. TIDAL FLOW (points<=0)
## renders big and gold as the mode announcement.
func _on_feat(title: String, points: int) -> void:
	var big := points <= 0
	var slot := _stack
	_stack += 1
	var vp := _root.size
	var lbl := Label.new()
	lbl.text = title if big else "%s   +%d" % [title, points]
	lbl.add_theme_font_override("font", DISPLAY_FONT)
	lbl.add_theme_font_size_override("font_size", 52 if big else 30)
	lbl.add_theme_color_override("font_color", Palette.GOLD if big else Palette.FOAM)
	lbl.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(vp.x, 0.0)                 # full width -> centre alignment centres on screen
	lbl.position = Vector2(0.0, vp.y * 0.36 - float(slot) * 46.0)
	lbl.pivot_offset = Vector2(vp.x * 0.5, 18.0)  # scale-pop from the screen centre
	lbl.scale = Vector2(0.4, 0.4)
	lbl.modulate.a = 0.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	var hold := 1.4 if big else 1.0
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(lbl, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - 34.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		lbl.queue_free()
		_stack = maxi(0, _stack - 1))

## Slim Flow gauge: fills cyan→aqua as feats charge it, then glows + pulses gold through TIDAL FLOW.
## Hidden at empty so it only appears once the player starts landing feats.
class FlowBar extends Control:
	const W := 210.0
	const H := 8.0

	var _frac := 0.0
	var _active := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func set_state(frac: float, active: bool) -> void:
		_frac = frac
		_active = active
		set_process(active)          # only needs per-frame work for the live pulse
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if _frac <= 0.001 and not _active:
			return
		var track := Rect2(Vector2.ZERO, Vector2(W, H))
		draw_rect(track, Color(Palette.INK, 0.45))                       # dark backing
		var fill_col: Color = Palette.GOLD if _active else Palette.CYAN.lerp(Palette.AQUA, _frac)
		draw_rect(Rect2(Vector2(1.0, 1.0), Vector2((W - 2.0) * clampf(_frac, 0.0, 1.0), H - 2.0)), fill_col)
		var glow := 0.5 + 0.5 * sin(_t * 5.0)
		var edge: Color = Color(Palette.GOLD, 0.4 + 0.6 * glow) if _active else Color(Palette.FOAM, 0.5)
		draw_rect(track, edge, false, 1.5)
		var font := get_theme_default_font()
		if font:
			var txt := "TIDAL FLOW" if _active else "FLOW"
			var col: Color = Color(Palette.GOLD, 0.7 + 0.3 * glow) if _active else Color(Palette.MIST, 0.7)
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
			draw_string(font, Vector2((W - tw) * 0.5, -3.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, col)
