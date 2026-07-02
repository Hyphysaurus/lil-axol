extends CanvasLayer
## Shine HUD — top-right arcade readout: rolling score ticker, combo badge (×2/×3/×4),
## and the Bubble Bomb charge orb that fills as you scrub and pulses when ready.
## Sits below the banner's corner-sun spot; hides while any menu is up. Pure view over
## the "shine" group's signals.

var _score := 0
var _shown := 0.0              # rolling display value
var _mult := 1
var _label: Label
var _combo: Label
var _orb: ChargeOrb

func _ready() -> void:
	layer = 92
	_build()
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper:
		keeper.score_changed.connect(_on_score)
		keeper.charge_changed.connect(func(f: float) -> void: _orb.charge = f)
		keeper.bubble_ready.connect(func() -> void: _orb.pulse = 1.0)
	Settings.ui_lock_changed.connect(func(locked: bool) -> void: visible = not locked)
	visible = not Settings.ui_locked()

func _on_score(score: int, mult: int) -> void:
	_score = score
	if mult != _mult:
		_mult = mult
		_combo.text = "×%d" % mult
		_combo.visible = mult > 1
		var warm := clampf(float(mult - 1) / 3.0, 0.0, 1.0)
		_combo.add_theme_color_override("font_color",
			Color(0.95, 0.98, 1.0).lerp(Color(1.0, 0.78, 0.35), warm))

func _process(delta: float) -> void:
	if _shown < float(_score):
		_shown = minf(_shown + maxf(300.0, (float(_score) - _shown) * 6.0) * delta, float(_score))
		_label.text = "%d" % int(_shown)
	_orb.tick(delta)

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_right = -16.0
	row.offset_left = -260.0
	row.offset_top = 52.0            # clear of the banner's corner sun (top 16)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)

	_combo = Label.new()
	_combo.visible = false
	_combo.add_theme_font_size_override("font_size", 24)
	row.add_child(_combo)

	_label = Label.new()
	_label.text = "0"
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0.03, 0.08, 0.12, 0.8))
	row.add_child(_label)

	_orb = ChargeOrb.new()
	row.add_child(_orb)

## The Bubble Bomb charge: a small orb that fills bottom-up and shimmers when full.
class ChargeOrb extends Control:
	var charge := 0.0:
		set(v):
			charge = v
			queue_redraw()
	var pulse := 0.0
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(22.0, 22.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func tick(delta: float) -> void:
		_t += delta
		pulse = maxf(0.0, pulse - delta * 0.6)
		if charge >= 1.0 or pulse > 0.0:
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := 9.0
		draw_arc(c, r, 0.0, TAU, 28, Color(0.9, 0.97, 1.0, 0.35), 1.5, true)
		if charge > 0.0:
			# fill rises bottom-up inside the ring
			var full := charge >= 1.0
			var col := Color(0.55, 0.9, 1.0, 0.75) if not full \
				else Color(0.75, 0.97, 1.0, 0.85 + 0.15 * sin(_t * 6.0))
			var h := (r * 2.0 - 3.0) * clampf(charge, 0.0, 1.0)
			draw_rect(Rect2(c.x - r + 1.5, c.y + r - 1.5 - h, r * 2.0 - 3.0, h), col)
		if pulse > 0.0:   # ready! ring swells off the orb
			draw_arc(c, r + 8.0 * (1.0 - pulse), 0.0, TAU, 28,
				Color(0.95, 0.99, 1.0, 0.8 * pulse), 2.0, true)
