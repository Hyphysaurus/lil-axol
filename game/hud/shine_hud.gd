extends CanvasLayer
## Shine HUD — top-right arcade readout: rolling score ticker, combo badge (×2/×3/×4),
## and the Bubble Bomb charge orb that fills as you scrub and pulses when ready.
## Sits below the banner's corner-sun spot; hides while any menu is up. Pure view over
## the "shine" group's signals.

const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne.ttf")   # chunky rounded score/combo font

var _score := 0
var _shown := 0.0              # rolling display value
var _mult := 1
var _material := 0
var _label: Label
var _combo: Label
var _orb: ChargeOrb
var _material_glyph: MaterialGlyph

func _ready() -> void:
	layer = 92
	add_to_group("shine_hud")
	_build()
	_material = int(WorldState.get_cove(WorldState.current_id, "material", 0))
	_refresh_material()
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper:
		keeper.score_changed.connect(_on_score)
		keeper.charge_changed.connect(func(f: float) -> void: _orb.charge = f)
		keeper.bubble_ready.connect(func() -> void: _orb.pulse = 1.0)
	Settings.ui_lock_changed.connect(func(locked: bool) -> void: visible = not locked)
	visible = not Settings.ui_locked()

## Called by a collected reclaim_token: n is the new material total for this reach.
func flash_material(n: int) -> void:
	_material = n
	_refresh_material()
	_pop_material()

func _refresh_material() -> void:
	_material_glyph.count = _material
	_material_glyph.visible = _material > 0

## The same scale-pop idiom as the combo badge, so a bank tick reads consistently.
func _pop_material() -> void:
	_material_glyph.scale = Vector2(1.5, 1.5)
	_material_glyph.create_tween().tween_property(_material_glyph, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_score(score: int, mult: int) -> void:
	_score = score
	if mult != _mult:
		var climbed := mult > _mult
		_mult = mult
		_combo.text = "x%d" % mult
		_combo.visible = mult > 1
		var warm := clampf(float(mult - 1) / 3.0, 0.0, 1.0)
		_combo.add_theme_color_override("font_color", Palette.FOAM.lerp(Palette.GOLD, warm))
		if climbed and mult > 1:
			_pop_combo()

## A satisfying scale-pop on the combo badge each time the multiplier climbs a tier.
func _pop_combo() -> void:
	_combo.scale = Vector2(1.7, 1.7)
	_combo.create_tween().tween_property(_combo, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	# On touch, the MENU/DAY buttons live in this exact corner (y~48, captions to ~105), so drop the
	# score readout below them; on desktop it clears only the banner's corner sun (top 16).
	row.offset_top = 112.0 if Settings.touch_active() else 52.0
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)

	_combo = Label.new()
	_combo.visible = false
	_combo.add_theme_font_override("font", DISPLAY_FONT)
	_combo.add_theme_font_size_override("font_size", 28)
	_combo.pivot_offset = Vector2(15.0, 15.0)   # scale-pop from ~centre
	row.add_child(_combo)

	_label = Label.new()
	_label.text = "0"
	_label.add_theme_font_override("font", DISPLAY_FONT)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(Palette.FOAM, 0.95))
	_label.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(_label)

	_orb = ChargeOrb.new()
	row.add_child(_orb)

	_material_glyph = MaterialGlyph.new()
	_material_glyph.visible = false
	_material_glyph.pivot_offset = Vector2(22.0, 13.0)   # scale-pop from ~centre
	row.add_child(_material_glyph)

## The Bubble Bomb charge, drawn as Mario's bubble sprite: it fades + swells in as it fills, shimmers
## when full, and a ring swells off it when it's ready to pop.
class ChargeOrb extends Control:
	const BUB := preload("res://assets/fx/bubble.png")
	var charge := 0.0:
		set(v):
			charge = v
			queue_redraw()
	var pulse := 0.0
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(26.0, 26.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func tick(delta: float) -> void:
		_t += delta
		pulse = maxf(0.0, pulse - delta * 0.6)
		if charge > 0.0 or pulse > 0.0:
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var f := clampf(charge, 0.0, 1.0)
		var full := charge >= 1.0
		# the bubble grows + brightens as it charges; a faint one always marks the empty orb
		var a := 0.22 + 0.78 * f
		var sc := (0.55 + 0.45 * f) * (1.0 + 0.12 * pulse)
		var tint := Color(1.0, 1.0, 1.0, 0.85 + 0.15 * sin(_t * 6.0)) if full else Color(1.0, 1.0, 1.0, a)
		var sz := Vector2(24.0, 24.0) * sc
		draw_texture_rect(BUB, Rect2(c - sz * 0.5, sz), false, tint)
		if pulse > 0.0:   # ready! ring swells off the orb
			draw_arc(c, 13.0 + 8.0 * (1.0 - pulse), 0.0, TAU, 28,
				Color(Palette.FOAM, 0.8 * pulse), 2.0, true)

## The banked RECLAIM material tally — a cleaned-barrel ring glyph + count, beside the Shine
## orb. Only shown once material > 0; redraws on change only (no idle per-frame churn).
class MaterialGlyph extends Control:
	const FONT := preload("res://assets/fonts/LilitaOne.ttf")
	var count := 0:
		set(v):
			count = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(44.0, 26.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(11.0, size.y * 0.5)
		draw_arc(c, 7.0, 0.0, TAU, 16, Palette.STEEL, 2.0, true)      # a cleaned barrel ring
		draw_arc(c, 7.0, -0.9, 0.6, 8, Palette.FOAM, 1.2, true)       # glint
		draw_string(FONT, Vector2(23.0, size.y * 0.5 + 8.0), "%d" % count,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Palette.FOAM, 0.95))
