extends CanvasLayer
## Restoration meters (Terra Nil-style) — a quiet top-left readout of how healed the cove
## is. Main water gauge = cleanliness %, with milestone notches at 25/50/75/100 that pulse
## as you cross them. Two mini-gauges track the sim's actual recovery stages using the same
## envelopes cove_life.gd animates with (kelp: 0→35% of the heal, fish: 15→55%), so the
## meters can never disagree with what the player sees. Code-drawn, self-wired to the
## oil_manager group; hides while any menu is up. Purely visual.

const MILESTONES := [0.25, 0.5, 0.75, 1.0]

var _clean := 0.0
var _shown := 0.0              # smoothed display value, so the bar glides
var _pulse := 0.0              # milestone flash 1 -> 0
var _pulse_at := 0.0           # x-fraction of the notch that pulsed
var _milestone := 0
var _gauge: Gauge
var _label: Label

func _ready() -> void:
	layer = 92                 # over the world, under banner (95) / menus (97+)
	_build()
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_signal("cleanliness"):
		mgr.cleanliness.connect(_on_clean)
	if mgr and "current_clean" in mgr:
		_clean = mgr.current_clean
	Settings.ui_lock_changed.connect(func(locked: bool) -> void: visible = not locked)
	visible = not Settings.ui_locked()

func _on_clean(v: float) -> void:
	_clean = v
	if _milestone < MILESTONES.size() and v >= float(MILESTONES[_milestone]):
		_pulse_at = float(MILESTONES[_milestone])
		_milestone += 1
		_pulse = 1.0

func _process(delta: float) -> void:
	_shown = move_toward(_shown, _clean, delta * 0.5)   # glide at the world's heal rate
	_pulse = maxf(0.0, _pulse - delta * 0.8)
	_gauge.set_state(_shown, _pulse, _pulse_at)
	_label.text = "%d%%" % int(round(_shown * 100.0))

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	row.offset_left = 16.0
	row.offset_top = 14.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)

	_gauge = Gauge.new()
	row.add_child(_gauge)

	_label = Label.new()
	_label.text = "0%"
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 0.85))
	_label.add_theme_color_override("font_shadow_color", Color(0.03, 0.08, 0.12, 0.8))
	row.add_child(_label)

## The drawn meters: main water bar + kelp/fish stage minis beneath it.
class Gauge extends Control:
	const W := 170.0
	const H := 9.0
	const MINI_H := 3.5
	const INK := Color(0.92, 0.97, 1.0)
	const WATER_A := Color(0.25, 0.75, 0.78)   # murk-teal -> vivid
	const WATER_B := Color(0.45, 0.95, 0.85)
	const KELP_COL := Color(0.38, 0.78, 0.48)
	const FISH_COL := Color(0.95, 0.62, 0.45)

	var _v := 0.0
	var _pulse := 0.0
	var _pulse_at := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(W, H + 4.0 + MINI_H * 2.0 + 3.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(v: float, pulse: float, pulse_at: float) -> void:
		if not (is_equal_approx(_v, v) and is_equal_approx(_pulse, pulse)):
			_v = v
			_pulse = pulse
			_pulse_at = pulse_at
			queue_redraw()

	func _draw() -> void:
		# main water gauge
		_bar(Vector2(0.0, 0.0), Vector2(W, H), _v, WATER_A.lerp(WATER_B, _v))
		for m in [0.25, 0.5, 0.75]:
			var x := W * float(m)
			draw_line(Vector2(x, 1.0), Vector2(x, H - 1.0), Color(INK, 0.35), 1.0)
		if _pulse > 0.0:   # milestone flash: a soft ring swelling off its notch
			var c := Vector2(W * _pulse_at, H * 0.5)
			draw_arc(c, 4.0 + 10.0 * (1.0 - _pulse), 0.0, TAU, 24,
				Color(INK, 0.7 * _pulse), 2.0, true)
		# stage minis, driven by cove_life's envelopes so meter == world
		var kelp := smoothstep(0.0, 0.35, _v)
		var fish := smoothstep(0.15, 0.55, _v)
		_bar(Vector2(0.0, H + 4.0), Vector2(W * 0.62, MINI_H), kelp, KELP_COL)
		_bar(Vector2(0.0, H + 4.0 + MINI_H + 3.0), Vector2(W * 0.62, MINI_H), fish, FISH_COL)

	func _bar(pos: Vector2, size_px: Vector2, fill: float, col: Color) -> void:
		draw_rect(Rect2(pos, size_px), Color(0.04, 0.09, 0.12, 0.55))
		if fill > 0.0:
			draw_rect(Rect2(pos + Vector2(1.0, 1.0),
				Vector2(maxf((size_px.x - 2.0) * fill, 1.0), size_px.y - 2.0)), col)
