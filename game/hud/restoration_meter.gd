extends CanvasLayer
## Restoration meters (Terra Nil-style) — a quiet top-left readout of how healed the cove
## is. Main water gauge = reach health (falls back to cleanliness % if no reach_state is
## present), with milestone notches at 25/50/75/100 that pulse as you cross them. Two
## mini-gauges track the sim's actual recovery stages using the same envelopes cove_life.gd
## animates with (kelp: 0→35% of the heal, fish: 15→55%), so the meters can never disagree
## with what the player sees — they read cleanliness directly, never health. Four small pips
## under the bar show the restoration engine's variables (purity/oxygen/clarity/vegetation),
## dimmed when a variable isn't in the reach's in-play set. Code-drawn, self-wired to the
## oil_manager + reach_state groups; hides while any menu is up. Purely visual.

const MILESTONES := [0.25, 0.5, 0.75, 1.0]
const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne.ttf")   # matches the Shine score font

var _clean := 0.0
var _shown := 0.0              # smoothed display value, so the bar glides
var _pulse := 0.0              # milestone flash 1 -> 0
var _pulse_at := 0.0           # x-fraction of the notch that pulsed
var _milestone := 0
var _health := 0.0             # latest reach_state health, drives the MAIN bar when present
var _reach: Node               # the reach_state group node, once deferred-wired (else null)
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
	_wire_reach.call_deferred()    # reach_state is a sibling: connect after the tree settles
	Settings.ui_lock_changed.connect(func(locked: bool) -> void: visible = not locked)
	visible = not Settings.ui_locked()

## Same idiom as restoration_banner.gd's _wire_reach: the reach_state group node is a sibling
## in the cove scene, so it's wired deferred rather than assumed present at _ready().
func _wire_reach() -> void:
	var rs = get_tree().get_first_node_in_group("reach_state")
	if rs and rs.has_signal("state_changed"):
		_reach = rs
		rs.state_changed.connect(_on_reach_state)
		if rs.has_method("get_state"):
			_on_reach_state(rs.get_state())    # seed immediately — don't wait for the first poll

func _on_clean(v: float) -> void:
	_clean = v
	if _milestone < MILESTONES.size() and v >= float(MILESTONES[_milestone]):
		_pulse_at = float(MILESTONES[_milestone])
		_milestone += 1
		_pulse = 1.0

## The restoration engine's state arrived (2Hz-polled + 0.002-delta rate-limited upstream).
## Stores health for the main bar and pushes the pip values/alpha to the gauge — the ONLY
## place pips redraw, per the no-per-frame-redraw rule.
func _on_reach_state(state: Dictionary) -> void:
	_health = float(state.get("health", 0.0))
	var in_play: Array = _reach.in_play() if _reach and _reach.has_method("in_play") else []
	_gauge.set_pips(state, in_play)

func _process(delta: float) -> void:
	var target := _health if _reach else _clean   # reach health when present, else legacy cleanliness
	_shown = move_toward(_shown, target, delta * 0.5)   # glide at the world's heal rate
	_pulse = maxf(0.0, _pulse - delta * 0.8)
	_gauge.set_state(_shown, _pulse, _pulse_at)
	_label.text = "%d%% restored" % int(round(_shown * 100.0))

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
	_label.text = "0% restored"
	_label.add_theme_font_override("font", DISPLAY_FONT)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(Palette.FOAM, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.8))
	row.add_child(_label)

## The drawn meters: main water bar + kelp/fish stage minis + the four variable pips beneath it.
class Gauge extends Control:
	const W := 170.0
	const H := 9.0
	const MINI_H := 3.5
	const PIP_R := 5.0                         # ~10px pip diameter
	const PIP_GAP := 7.0
	const PIP_ROW_GAP := 6.0                   # space between the fish mini and the pip row
	const INK := Palette.FOAM
	const WATER_A := Palette.CYAN              # bright water -> pale surface aqua as it heals
	const WATER_B := Palette.AQUA
	const KELP_COL := Palette.FERN             # kelp/grass green
	const FISH_COL := Palette.CORAL            # the fish shader's own coral
	## The restoration engine's four readable variables (purity/oxygen/clarity/vegetation —
	## "invasive" has no pip, it only caps clarity) in the order they're drawn.
	const PIP_DEFS := [
		{"key": "purity", "col": Palette.CYAN},
		{"key": "oxygen", "col": Palette.LEAF},
		{"key": "clarity", "col": Palette.MIST},
		{"key": "vegetation", "col": Palette.GREEN},
	]
	const PIPS_BOTTOM := H + 4.0 + MINI_H * 2.0 + 3.0 + PIP_ROW_GAP + PIP_R * 2.0

	var _v := 0.0
	var _pulse := 0.0
	var _pulse_at := 0.0
	var _pip_vals := {"purity": 0.0, "oxygen": 0.0, "clarity": 0.0, "vegetation": 0.0}
	var _pip_in_play := {"purity": false, "oxygen": false, "clarity": false, "vegetation": false}

	func _init() -> void:
		custom_minimum_size = Vector2(W, PIPS_BOTTOM)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(v: float, pulse: float, pulse_at: float) -> void:
		if not (is_equal_approx(_v, v) and is_equal_approx(_pulse, pulse)):
			_v = v
			_pulse = pulse
			_pulse_at = pulse_at
			queue_redraw()

	## Called only when reach_state's state_changed fires (never per-frame — the WebGL churn
	## rule): stores the pip fill values + which are in the reach's in_play set, redrawing
	## just once if anything actually moved.
	func set_pips(state: Dictionary, in_play: Array) -> void:
		var changed := false
		for def in PIP_DEFS:
			var key: String = def["key"]
			var val := float(state.get(key, 0.0))
			var in_p: bool = StringName(key) in in_play
			if not is_equal_approx(_pip_vals[key], val) or _pip_in_play[key] != in_p:
				changed = true
			_pip_vals[key] = val
			_pip_in_play[key] = in_p
		if changed:
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
		# variable pips: purity/oxygen/clarity/vegetation, dimmed when not in the reach's in_play
		var pip_y := PIPS_BOTTOM - PIP_R
		var pip_x := PIP_R
		for def in PIP_DEFS:
			var key: String = def["key"]
			var col: Color = def["col"]
			var val: float = _pip_vals[key]
			var alpha := 1.0 if _pip_in_play[key] else 0.4    # tease reads dimmed, not absent
			var c := Vector2(pip_x, pip_y)
			draw_circle(c, PIP_R, Color(Palette.INK, 0.55 * alpha))
			if val > 0.0:
				draw_arc(c, PIP_R - 1.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(val, 0.0, 1.0), 16,
					Color(col, alpha), 2.0, true)
			pip_x += PIP_R * 2.0 + PIP_GAP

	func _bar(pos: Vector2, size_px: Vector2, fill: float, col: Color) -> void:
		draw_rect(Rect2(pos, size_px), Color(Palette.INK, 0.55))
		if fill > 0.0:
			draw_rect(Rect2(pos + Vector2(1.0, 1.0),
				Vector2(maxf((size_px.x - 2.0) * fill, 1.0), size_px.y - 2.0)), col)
